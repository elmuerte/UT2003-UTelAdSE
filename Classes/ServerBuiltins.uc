///////////////////////////////////////////////////////////////////////////////
// filename:    ServerBuiltins.uc.uc
// version:     102
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     functions to admin server settings
///////////////////////////////////////////////////////////////////////////////

class ServerBuiltins extends UTelAdSEHelper;

const VERSION = "102";

// Localization
var localized string msg_onlyaccesscontrolini;

var localized string msg_map_nonext;
var localized string msg_map_changeto;

var localized string msg_mut_list;
var localized string msg_mut_group;
var localized string msg_mut_add;
var localized string msg_mut_remove;
var localized string msg_mut_restart;

var localized string msg_bot_nobotgame;
var localized string msg_bot_statsgame;
var localized string msg_bot_gamefull;
var localized string msg_bot_onlynamedbots;
var localized string msg_bot_nobots;
var localized string msg_bot_nummeric;
var localized string msg_bot_added;
var localized string msg_bot_removed;
var localized string msg_bot_removedname;
var localized string msg_bot_setmin;

var localized string msg_kick_banned;
var localized string msg_kick_session;
var localized string msg_kick_kicked;
var localized string msg_kick_failed;
var localized string msg_kick_nokickself;
var localized string msg_kick_higherlevel;
var localized string msg_kick_isadmin;
var localized string msg_kick_nomsgspec;

var localized string msg_maplist_list;
var localized string msg_maplist_nomaps;
var localized string msg_maplist_added;
var localized string msg_maplist_noneadded;
var localized string msg_maplist_removed;
var localized string msg_maplist_noneremoved;
var localized string msg_maplist_listall;
var localized string msg_maplist_inrotation;
var localized string msg_maplist_notinrotation;
var localized string msg_map_moved;

var localized string msg_gametype_unknown;
var localized string msg_gametype_list;
var localized string msg_gametype_get;
var localized string msg_gametype_seclevel;
var localized string msg_gametype_update;

var localized string msg_ip_policy;
var localized string msg_ip_set;
var localized string msg_ip_remove;
var localized string msg_ip_nopolicy;

var localized string msg_key_policy;
var localized string msg_key_set;
var localized string msg_key_remove;
var localized string msg_key_nopolicy;

var StringArray	AGameType;
var StringArray	AMaplistType;
var array<xUtil.MutatorRecord> AllMutators;
var StringArray AExcMutators;	// All available Mutators (Excluded)
var StringArray AIncMutators;	// All Mutators currently in play

function bool Init()
{
  log("[~] Loading Server Admin builtins"@VERSION, 'UTelAdSE');
  LoadGameTypes();
  LoadMutators();
  return true;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEConnection connection)
{
  switch (command)
  {
    case "map" :  ExecMap(args, connection); return true;
    case "bots" :  ExecBots(args, connection); return true;
    case "kick" :  ExecKick(args, connection); return true;
    case "maplist" :  ExecMaplist(args, connection); return true;
    case "mutator" :  ExecMutator(args, connection); return true;
    case "gametype" : ExecGametype(args, connection); return true;
    case "ippolicy" : ExecIPPolicy(args, connection); return true;
    case "keypolicy" : ExecKeyPolicy(args, connection); return true;
  }
}

// Map routines

function RestartMap(UTelAdSEConnection connection)
{
	if (CanPerform(connection.Spectator, "Mr") || CanPerform(connection.Spectator, "Mc"))	  // Mr = MapRestart, Mc = Map Change
	{
    DoSwitch(Level.GetURLMap(), connection);
	}
  else {
    connection.SendLine(msg_noprivileges);
  }
}

function DoSwitch( string URL, UTelAdSEConnection connection)
{
  local string mutators;
  local int i;
	if (CanPerform(connection.Spectator, "Mc"))
	{
    if (InStr(URL, "?restart") > 0)
    {
      if (!CanPerform(connection.Spectator, "Mr"))
	    {
        connection.SendLine(msg_noprivileges);
        return;
      }
    }
    if (Level.Game.ParseOption(URL, "gametype") != "")
    {
      if (!CanPerform(connection.Spectator, "Mt"))
	    {
        connection.SendLine(msg_noprivileges);
        return;
      }
    }
		
    if (AIncMutators.Count() > 0)
    {
      mutators = AIncMutators.GetTag(0);
      for (i=1; i<AIncMutators.Count(); i++)
      {
        mutators = mutators$","$AIncMutators.GetTag(i);
      }
    }
    if (mutators != "" && Level.Game.ParseOption(URL, "mutator") == "")
				URL=URL$"?mutator="$mutators;

		Level.ServerTravel( URL, false );
    Connection.SendLine(msg_map_changeto@URL);
	}
  else {
    connection.SendLine(msg_noprivileges);
  }
}

function GotoNextMap(UTelAdSEConnection connection)
{
  local string NextMap;
  local MapList MyList;
  local GameInfo G;

	if (CanPerform(connection.Spectator, "Mc"))
	{
		G = Level.Game;
		if ( G.bChangeLevels && !G.bAlreadyChanged && (G.MapListType != "") )
		{
			// open a the nextmap actor for this game type and get the next map
			G.bAlreadyChanged = true;
			MyList = G.GetMapList(G.MapListType);
			if (MyList != None)
			{
				NextMap = MyList.GetNextMap();
				MyList.Destroy();
			}
			if ( NextMap == "" ) NextMap = GetMapName(G.MapPrefix, NextMap,1);
			if ( NextMap != "" )
			{
				DoSwitch(NextMap, connection);
				return;
			}
		}
		Connection.SendLine(msg_map_nonext);
		RestartMap(connection);
	}
  else {
    connection.SendLine(msg_noprivileges);
  }
}


function ExecMap(array< string > args, UTelAdSEConnection connection)
{
  if (args.length == 0)
  {
    Connection.SendLine(msg_usage@PREFIX_BUILTIN$"map <restart|next|url>");
    return;
  }
  if (args[0] == "restart")
  {
    RestartMap(connection);
  }
  else if (args[0] == "next")
  {
    GotoNextMap(connection);
  }
  else {
    DoSwitch(args[0], connection);
  }
}

// Mutator routines

function LoadMutators()
{
  local int NumMutatorClasses;
  local class<Mutator> MClass;
  local Mutator M;
  local int i, id;

	AExcMutators = New(None) class'SortedStringArray';
	AIncMutators = New(None) class'StringArray';

	// Load All mutators
	class'xUtil'.static.GetMutatorList(AllMutators);

	for (i = 0; i<AllMutators.Length; i++)
	{
		MClass = class<Mutator>(DynamicLoadObject(AllMutators[i].ClassName, class'Class'));
		if (MClass != None)
		{
			AExcMutators.Add(string(i), AllMutators[i].ClassName);
			NumMutatorClasses++;
		}
	}
	
	// Check Current Mutators
	for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
	{
		if (M.bUserAdded)
		{
			id = AExcMutators.FindTagId(String(M.Class));
			if (id >= 0)
			{
				AIncMutators.Add(AExcMutators.GetItem(id), AExcMutators.GetTag(id));
			}
			else
				log("Unknown Mutator in use: "@String(M.Class));
		}
	}
}

function string FindMutator(string mut)
{
  local int i;
  i = AExcMutators.FindTagID(mut);
  if (i > -1) return mut;
  for (i = 0; i < AllMutators.Length; i++)
  {
    if (InStr(Caps(AllMutators[i].FriendlyName), Caps(mut)) == 0) return AllMutators[i].ClassName;
    if (Mid(AllMutators[i].ClassName, InStr(AllMutators[i].ClassName, ".")+1) ~= mut) return AllMutators[i].ClassName;
  }
}

function ExecMutator(array< string > args, UTelAdSEConnection connection)
{
  local int i, j, k;
  local string lastgroup, thisgroup;
  local StringArray	GroupedMutators;

  if (CanPerform(connection.Spectator, "Mu"))
	{
    if (args[0] == "list")
    {
      connection.SendLine(msg_mut_list);
      GroupedMutators = new(None) class'SortedStringArray';
      // Make a list sorted by groupname.classname
  		for (i = 0; i<AllMutators.Length; i++)
	  	{
			  GroupedMutators.Add(string(i), AllMutators[i].GroupName$"."$AllMutators[i].ClassName);
  		}
      for (i = 0; i<GroupedMutators.Count(); i++)
      {
        j = int(GroupedMutators.GetItem(i));

        thisgroup = AllMutators[j].GroupName;
        k = AIncMutators.FindTagId(AllMutators[j].ClassName);
        if (lastgroup != thisgroup) connection.SendLine(strReplace(msg_mut_group, "%s", thisgroup));
        if (k == -1) connection.SendLine(chr(9)$AllMutators[j].ClassName);
          else connection.SendLine("!"$chr(9)$AllMutators[j].ClassName);

        lastgroup = thisgroup;
      }
    }
    else if (args[0] == "show")
    {
      for (i = 0; i < AllMutators.Length; i++)
      {
        if (AllMutators[i].ClassName ~= FindMutator(args[0]))
        {
          connection.SendLine("Mutator: "$chr(9)$AllMutators[i].FriendlyName);
          connection.SendLine("Class: "$chr(9)$chr(9)$AllMutators[i].ClassName);
          connection.SendLine("Group: "$chr(9)$chr(9)$AllMutators[i].GroupName);
          connection.SendLine("Description: "$chr(9)$AllMutators[i].Description);
          break;
        }
      }
    }
    else if (args[0] == "add")
    {
      ShiftArray(args);
      while (args.length > 0)
      {
        lastgroup = FindMutator(ShiftArray(args));
        k = AIncMutators.FindTagID(lastgroup);
        if (k > -1) continue;
        k = AExcMutators.FindTagID(lastgroup);
        if (k > -1)
        {
          AIncMutators.Add(AExcMutators.GetItem(k), AExcMutators.GetTag(k));
          connection.SendLine(strReplace(msg_mut_add, "%s", AllMutators[int(AExcMutators.GetItem(k))].ClassName));
        }
      }
      connection.SendLine(msg_mut_restart);
    }
    else if (args[0] == "del")
    {
      ShiftArray(args);
      while (args.length > 0)
      {
        k = AIncMutators.FindTagID(FindMutator(ShiftArray(args)));
        if (k > -1)
        {
          connection.SendLine(strReplace(msg_mut_remove, "%s", AllMutators[int(AIncMutators.GetItem(k))].ClassName));
          AIncMutators.Remove(k);
        }
      }
      connection.SendLine(msg_mut_restart);
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"mutator <list> | <show> mutator | <add|del> mutator ...");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// Kick/ban routines

exec function ExecKick(array< string > args, UTelAdSEConnection connection)
{
  local string cmd;
  local array<PlayerReplicationInfo> AllPRI;
  local Controller	C, NextC;
  local int i;
  local bool force;

	if (CanPerform(connection.Spectator, "Kp") || CanPerform(connection.Spectator, "Kb"))		// Kp = Kick Players, Kb = Kick/Ban
	{
    if (args[0] == "")
    {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"kick <list> | [ban|session] [-force] <names|ids>");
      return;
    }

		if (args[0] == "list")
		{
			// Get the list of players to kick by showing their PlayerID
			// TODO: Display Fixed Playername (no garbage chars in name)?
			// TODO: Display Sorted ?
      Connection.SendLine("ID"$Chr(9)$"Spectator"$Chr(9)$"Name");
			Level.Game.GameReplicationInfo.GetPRIArray(AllPRI);
			for (i = 0; i<AllPRI.Length; i++)
      {
        if (AllPRI[i].bBot == false)
  				Connection.SendLine(Right("   "$AllPRI[i].PlayerID, 2)$Chr(9)$AllPRI[i].bIsSpectator$Chr(9)$Chr(9)$AllPRI[i].PlayerName);
      }
			return;
		}

		if ((args[0] == "ban" || args[0] == "session")) cmd = ShiftArray(args);
  		else cmd = "";

    // force this action -> logout admin
    if (args[0] == "-force")
    {
      force = true;
      ShiftArray(args);
    }
    else {
      force = false;
    }

		// go thru all Players
		for (C = Level.ControllerList; C != None; C = NextC)
		{
			NextC = C.NextController;
			if (C != Owner && PlayerController(C) != None && C.PlayerReplicationInfo != None)
			{
				for (i = 0; i<args.Length; i++)
				{
					if ((IsNumeric(args[i]) && C.PlayerReplicationInfo.PlayerID == int(args[i]))
							|| MaskedCompare(C.PlayerReplicationInfo.PlayerName, args[i]))
					{
            if (PlayerController(C).isA('MessagingSpectator'))
            {
              Connection.SendLine(strReplace(msg_kick_nomsgspec, "%s", C.PlayerReplicationInfo.PlayerName));
              break;
            }
            if (PlayerController(C) == connection.Spectator)
            {
              Connection.SendLine(msg_kick_nokickself);
              break;
            }
            if (force) 
            {
              if (Level.Game.AccessControl.IsAdmin(PlayerController(C)))
              {
                if (Level.Game.AccessControl.GetLoggedAdmin(PlayerController(C)).MaxSecLevel() <
                    Level.Game.AccessControl.GetLoggedAdmin(connection.Spectator).MaxSecLevel())
                {
                  Level.Game.AccessControl.AdminLogout(PlayerController(C));
                }
                else {
                  Connection.SendLine(strReplace(msg_kick_higherlevel, "%s", C.PlayerReplicationInfo.PlayerName));
                  break;
                }
              }
            }
            else {
              if (Level.Game.AccessControl.IsAdmin(PlayerController(C)))
              {
                Connection.SendLine(strReplace(msg_kick_isadmin, "%s", C.PlayerReplicationInfo.PlayerName));
                  break;
              }
            }

						// Kick that player
						if (cmd == "ban")
						{
							if (Level.Game.AccessControl.BanPlayer(PlayerController(C)))
                Connection.SendLine(strReplace(msg_kick_banned, "%s", C.PlayerReplicationInfo.PlayerName));
                else Connection.SendLine(strReplace(msg_kick_failed, "%s", C.PlayerReplicationInfo.PlayerName));
						}
						else if (cmd == "session")
						{
							if (Level.Game.AccessControl.BanPlayer(PlayerController(C), true))
                Connection.SendLine(strReplace(msg_kick_session, "%s", C.PlayerReplicationInfo.PlayerName));
                else Connection.SendLine(strReplace(msg_kick_failed, "%s", C.PlayerReplicationInfo.PlayerName));
						}
						else
						{
							if (Level.Game.AccessControl.KickPlayer(PlayerController(C)))
                Connection.SendLine(strReplace(msg_kick_kicked, "%s", C.PlayerReplicationInfo.PlayerName));
                else Connection.SendLine(strReplace(msg_kick_failed, "%s", C.PlayerReplicationInfo.PlayerName));
						}
						break;
					}
				}
			}
		}
	}
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// Bots 

function MakeBotsList(out array<XUtil.PlayerRecord> BotList)
{
  local xBot Bot;
  local int i;
  local Controller C;

	// Get Full Bot List
	class'XUtil'.static.GetPlayerList(BotList);
	// Filter out Playing Bots
	for (C = Level.ControllerList; C != None; C = C.NextController)
	{
		Bot = xBot(C);
		if (Bot != None && Bot.PlayerReplicationInfo != None)
		{
			for (i = 0; i<BotList.Length; i++)
			{
				if (Bot.PlayerReplicationInfo.CharacterName == BotList[i].DefaultName)
				{
					BotList.Remove(i,1);
					break;
				}
			}
		}
	}
}

function ExecBots( array< string > args, UTelAdSEConnection connection)
{
  local int MinV, i, j;
  local array<string> Params;
  local array<XUtil.PlayerRecord>	BotList, BotsToAdd;
  local DeathMatch	Game;
  local Controller	C, NextC;
  local xBot			Bot;

	if (CanPerform(connection.Spectator, "Mb"))
	{
		Game = DeathMatch(Level.Game);
		if (Game == None)
		{
			connection.SendLine(msg_bot_nobotgame);
			return;
		}

		if (Game.GameStats != None)
		{
			connection.SendLine(msg_bot_statsgame);
			return;
		}

		if (args[0] == "add")
		{
      ShiftArray(args);

			MinV = Game.MinPlayers;
			if (MinV == 32)
			{
				connection.SendLine(msg_bot_gamefull);
				return;
			}

			if (args.Length == 0)
			{
				Game.ForceAddBot();
        connection.SendLine(strReplace(msg_bot_added, "%i", "1"));
			}
			else if (args.Length == 1 && IsNumeric(args[0]))
			{
				MinV = Min(32, MinV + int(args[0]));
				while (Game.MinPlayers < MinV)
        {
          Game.ForceAddBot();
        }
        connection.SendLine(strReplace(msg_bot_added, "%i", string(MinV)));
			}
			else	// Else add named bots
			{
				if (!Game.IsInState('MatchInProgress'))
				{
					connection.SendLine(msg_bot_onlynamedbots);
					return;
				}
				MakeBotsList(BotList);
				for (i = 0; i<BotList.Length; i++)
				{
					for (j = 0; j<Params.Length; j++)
					{
						if (MaskedCompare(BotList[i].DefaultName, args[j]))
						{
							BotsToAdd[BotsToAdd.Length] = BotList[i];
							BotList.Remove(i, 1);
							i--;
						}
					}
				}
				MinV = Min(32, MinV + BotsToAdd.Length);
				while (Game.MinPlayers<MinV)
				{
					if (!Game.AddBot(BotsToAdd[0].DefaultName))
						break;
					BotsToAdd.Remove(0, 1);
				}
        connection.SendLine(strReplace(msg_bot_added, "%i", string(MinV)));
			}
		}
		else if (args[0] == "kill")
		{
			if (Game.MinPlayers == 0 || Game.NumBots == 0)
			{
        connection.SendLine(msg_bot_nobots);
				return;
			}

      ShiftArray(args);

			if (args.Length == 0) // Kill 1 random bot
			{
				Game.KillBots(1);
        connection.SendLine(strReplace(msg_bot_removed, "%i", "1"));
			}
			else if (args.Length == 1 && IsNumeric(args[0])) // Kill a Number of Bots
			{
				Game.KillBots(int(args[0]));
        connection.SendLine(strReplace(msg_bot_removed, "%i", args[0]));
			}
			else	// Kill Named Bots
			{
				// TODO: Rework Loop ?
				for (C = Level.ControllerList; C != None; C = NextC)
				{
					Bot = xBot(C);
					NextC = C.NextController;
					if (Bot != None && Bot.PlayerReplicationInfo != None)
					{
						for (i = 0; i<args.Length; i++)
						{
							if (MaskedCompare(Bot.PlayerReplicationInfo.PlayerName, args[i]))
							{
                connection.SendLine(strReplace(msg_bot_removedname, "%s", Bot.PlayerReplicationInfo.PlayerName));
								Game.KillBot(C);
								break;
							}
						}
					}
				}
			}
		}
		else if (args[0] == "set")	// Minimum number of Players
		{
      ShiftArray(args);
			if (args.Length == 1 && IsNumeric(args[0]) && int(args[0]) < 33)
			{
				Game.MinPlayers=int(args[0]);
        connection.SendLine(strReplace(msg_bot_setmin, "%i", args[0]));
			}
			else
        connection.SendLine(msg_bot_nummeric);
		}
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"bots <add|kill|set>");
    }
	}
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// Maplist routines

function array<string> LoadAllMaps(String GameType)
{
  local class<GameInfo>	GameClass;
  local array<string> Maps;
  
  GameClass = class<GameInfo>(DynamicLoadObject(GameType, class'Class')); 
  GameClass.static.LoadMapList(GameClass.Default.MapPrefix, Maps);
  return Maps;
}

function array<string> AddMaps(array<string> MapMask, out MapList Maps, optional string GameType)
{
  local array<string> AddedMaps, AllMaps;
  local int i, j, k;
  local bool bFound;

  AllMaps = LoadAllMaps(GameType);

	if (MapMask.Length > 0)
	{
		for (i = 0; i<AllMaps.Length; i++)
		{
			for (j = 0; j<MapMask.Length; j++)
			{
				if (MaskedCompare(AllMaps[i], MapMask[j]))
				{
					// Found a matching map, see if its already in the Used Maps list
					bFound = false;
					for (k = 0; k<Maps.Maps.Length; k++)
					{
						if (Maps.Maps[k] == AllMaps[i])
						{
							bFound = true;
							break;
						}
					}

					if (!bFound)
					{
						Maps.Maps[Maps.Maps.Length] = AllMaps[i];
						AddedMaps[AddedMaps.Length] = AllMaps[i];
						break;
					}
				}
			}
		}
	}
	return AddedMaps;
}

function array<string> RemoveMaps(array<string> MapMask, out MapList Maps)
{
  local array<string> DelMaps;
  local int i, j;

	if (MapMask.Length > 0)
	{
		for (i=0; i<Maps.Maps.Length; i++)
		{
			for (j=0; j<MapMask.Length; j++)
			{
				if (MaskedCompare(Maps.Maps[i], MapMask[j]))
				{
					DelMaps[DelMaps.Length] = Maps.Maps[i];
					Maps.Maps.Remove(i, 1);
					i--;
					break;
				}
			}
		}
	}
	return DelMaps;
}

function ExecMaplist( array< string > args, UTelAdSEConnection connection)
{
  local MapList	Maps;
  local array<string> Values;
  local int i,j;
  local string cmd, usegametype, gameaccr;

	if (CanPerform(connection.Spectator, "Ml"))
	{
    cmd = ShiftArray(args);
    UseGametype = GetGameType("");
    if (args.length > 0)
    {
      if (InStr(args[0], "-") == 0) // -gametype
      {
        UseGametype = GetGameType(Mid(args[0],1));
        if (UseGametype == "")
        {
          connection.SendLine(strReplace(msg_gametype_unknown, "%s", Mid(args[0],1)));
          return;
        }
        ShiftArray(args);
      }
    }

    Maps = Level.Game.GetMapList(AMaplistType.GetItem(AMaplistType.FindTagId(UseGametype)));
    gameaccr = AGameType.GetTag(AGameType.FindItemId(UseGametype));

    if (cmd == "used")
    {
      connection.SendLine(strReplace(msg_maplist_list, "%s", gameaccr));
      if (Maps == None || Maps.Maps.Length == 0) connection.SendLine(msg_maplist_nomaps);
			else
			{
				for (i = 0; i<Maps.Maps.Length; i++)
				{
					connection.SendLine(Right("   "$i, 2)$Chr(9)$Maps.Maps[i]);
				}
			}
    }
    else if (cmd == "add")
    {
      Values = AddMaps(args, Maps, UseGametype);
			if (Values.Length == 0)
				connection.SendLine(msg_maplist_noneadded);
			else
				for (i = 0; i<Values.Length; i++)
					connection.SendLine(strReplace(msg_maplist_added, "%s", Values[i]));
      Maps.SaveConfig();
    }
    else if (cmd == "del")
		{
			Values = RemoveMaps(args, Maps);
			if (Values.Length == 0)
				connection.SendLine(msg_maplist_noneremoved);
			else
				for (i = 0; i<Values.Length; i++)
					connection.SendLine(strReplace(msg_maplist_removed ,"%s", Values[i]));
      Maps.SaveConfig();
		}
    else if (cmd == "list")
		{
      connection.SendLine(msg_maplist_listall);
			Values = LoadAllMaps(UseGametype);
      if (Values.Length == 0)
				connection.SendLine(msg_maplist_nomaps);
			else
				for (i = 0; i<Values.Length; i++)
					connection.SendLine(Values[i]);
		}
    else if (cmd == "move")
		{
      if (args.length == 2)
      {
        cmd = ShiftArray(args);
        if (IsNumeric(cmd))
        {
          i = int(cmd);
          cmd = ShiftArray(args);
          if (IsNumeric(cmd))
          {
            j = int(cmd);
            if ((i >= 0) && (i < Maps.Maps.Length) && (j >= 0) && (j < Maps.Maps.Length))
            {
              cmd = Maps.Maps[i];
              Maps.Maps.Remove(i, 1);
              if (j > i) j--;
              Maps.Maps.Insert(j, 1);
              Maps.Maps[j] = cmd;
              Maps.SaveConfig();
              connection.SendLine(strReplace(strReplace(msg_map_moved, "%s", Maps.Maps[j]), "%i", string(j)));
              return;
            }
          }
        }
      }
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"maplist <move> [-gametype] from to");
		}
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"maplist <used|list> [-gametype] | <add|del> [-gametype] mapname ... | <move> [-gametype] from to");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// gametype

function LoadGameTypes()
{
  local class<GameInfo>	TempClass;
  local String NextGame;
  local int i;

	// reinitialize list if needed
	AGameType = New(None) class'SortedStringArray';
  AMaplistType = New(None) class'SortedStringArray';
	
	// Compile a list of all gametypes.
	TempClass = class'Engine.GameInfo';
	NextGame = Level.GetNextInt("Engine.GameInfo", 0); 
	while (NextGame != "")
	{
		TempClass = class<GameInfo>(DynamicLoadObject(NextGame, class'Class'));
		if (TempClass != None)
    {
			AGameType.Add(NextGame, TempClass.Default.Acronym);
      AMaplistType.Add(TempClass.Default.MapListType, NextGame);
    }

		NextGame = Level.GetNextInt("Engine.GameInfo", ++i);
	}
}

function string GetGameType(string gametype)
{
  local int i;
  if (gametype == "")
  {
    return string(Level.Game.Class);
  }
  else {
    i = AGameType.FindTagId(gametype);
    if (i > -1) return AGameType.GetItem(i);
    else {
      i = AGameType.FindItemId(gametype);
      if (i > -1) return AGameType.GetItem(i);
      else {
        return "";
      }
    }
  }
}

function string SetGamePI(out PlayInfo GamePI, string GameType)
{
  local class<GameInfo> GameClass;

	GameClass = class<GameInfo>(DynamicLoadObject(GameType, class'Class'));
	if (GameClass == None)
		GameClass = Level.Game.Class;

	if (GamePI == None)
	{
		GamePI = new(None) class'PlayInfo';
		GameClass.static.FillPlayInfo(GamePI);
		Level.Game.AccessControl.FillPlayInfo(GamePI);
	}
	else if (GamePI.InfoClasses.Length>0 && GameClass != GamePI.InfoClasses[0])
	{
		GamePI.Clear();
		GameClass.static.FillPlayInfo(GamePI);
		Level.Game.AccessControl.FillPlayInfo(GamePI);
	}

	return string(GameClass);
}

function string RenderValue(string value, string type, string data)
{
  //log(value$"->"$type$"->"$data, 'UTelAdSE');
  if (type ~= "select")
  {
    return value;
  }
  else return value;
}

function ExecGametype( array< string > args, UTelAdSEConnection connection)
{
  local int i;
  local string UseGametype, cmd, temp;
  local PlayInfo GamePI;

  if (CanPerform(connection.Spectator, "Ml"))
	{
    cmd = ShiftArray(args);
    UseGametype = GetGameType("");
    if (args.length > 0)
    {
      if (InStr(args[0], "-") == 0) // -gametype
      {
        UseGametype = GetGameType(Mid(args[0],1));
        if (UseGametype == "")
        {
          connection.SendLine(strReplace(msg_gametype_unknown, "%s", Mid(args[0],1)));
          return;
        }
        ShiftArray(args);
      }
    }

    if (cmd == "list")
    {
      connection.SendLine(msg_gametype_list);
      for (i = 0; i < AGameType.Count(); i++)
      {
        connection.SendLine(AGameType.GetTag(i)$Chr(9)$AGameType.GetItem(i));
      }
    }
    else if (cmd == "get")
    {
      cmd = ShiftArray(args);
      SetGamePI(GamePI, UseGametype);
      connection.SendLine(msg_gametype_get);
      for (i = 0; i<GamePI.Settings.Length; i++)
    	{
        if (MaskedCompare(GamePI.Settings[i].SettingName, cmd))
        {                           // sec level                                                                                  // name                       // value (true value or datavalue ?)
          connection.SendLine(Right("   "$GamePI.Settings[i].SecLevel,3)$") ["$Left(GamePI.Settings[i].Grouping$"      ", 6)$"]  "$GamePI.Settings[i].SettingName$" = "$RenderValue(GamePI.Settings[i].Value, GamePI.Settings[i].RenderType, GamePI.Settings[i].Data));
        }
      }
    }
    else if (cmd == "set")
    {
      SetGamePI(GamePI, UseGametype);
      cmd = ShiftArray(args);
      temp = class'wArray'.static.Join(args, " ");
      for (i = 0; i<GamePI.Settings.Length; i++)
    	{
        if (GamePI.Settings[i].SettingName == cmd)
        {
          if (Level.Game.AccessControl.GetLoggedAdmin(connection.Spectator).MaxSecLevel() >= GamePI.Settings[i].SecLevel)
          {
            if (CanPerform(connection.Spectator, GamePI.Settings[i].ExtraPriv))
            {
              GamePI.StoreSetting(GamePI.FindIndex(GamePI.Settings[i].SettingName), temp);
              GamePI.SaveSettings();
              connection.SendLine(StrReplace(StrReplace(msg_gametype_update, "%s", GamePI.Settings[i].SettingName), "%v", temp));
            }
            else {
              connection.SendLine(msg_noprivileges);
            }
          }
          else {
            connection.SendLine(StrReplace(StrReplace(msg_gametype_seclevel, "%i", string(GamePI.Settings[i].SecLevel)), "%j", 
              string(Level.Game.AccessControl.GetLoggedAdmin(connection.Spectator).MaxSecLevel())));
          }
          break;
        }
      }
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"gametype <list> | <get> [-gametype] [mask] | <set> [-gametype] setting value");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// IP Policy settings
function ExecIPPolicy( array< string > args, UTelAdSEConnection connection)
{
  local string cmd, pol_ip, pol_pol;
  local int i;
 
  if (CanPerform(connection.Spectator, "Xb"))
	{
    cmd = ShiftArray(args);
    if (cmd == "list")
    {
      for (i = 0; i < level.game.AccessControl.IPPolicies.length; i++)
      {
        divide(level.game.AccessControl.IPPolicies[i], ",", pol_pol, pol_ip);
        connection.SendLine(StrReplace(StrReplace(msg_ip_policy, "%s", pol_pol), "%i", pol_ip));
      }
    }
    else if (cmd == "set")
    {
      if (args.length == 2)
      {
        if ((caps(args[1]) != "ACCEPT") && (caps(args[1]) != "DENY"))
        {
          connection.SendLine(msg_usage@PREFIX_BUILTIN$"ippolicy <set> IP-mask <accept|deny>");
          return;
        }
        for (i = 0; i < level.game.AccessControl.IPPolicies.length; i++)
        {
          divide(level.game.AccessControl.IPPolicies[i], ",", pol_pol, pol_ip);
          if (pol_ip == args[0])
          {
            level.game.AccessControl.IPPolicies[i] = caps(args[1])$","$pol_ip;
            connection.SendLine(StrReplace(StrReplace(msg_ip_set, "%s", args[1]), "%i", pol_ip));
            return;
          }
        }
        level.game.AccessControl.IPPolicies.length = level.game.AccessControl.IPPolicies.length+1;
        level.game.AccessControl.IPPolicies[i] = caps(args[1])$","$args[0];
        connection.SendLine(StrReplace(StrReplace(msg_ip_set, "%s", args[1]), "%i", args[0]));
      }
      else {
        connection.SendLine(msg_usage@PREFIX_BUILTIN$"ippolicy <set> IP-mask <accept|deny>");
      }
    }
    else if (cmd == "remove")
    {
      if (args.length == 1)
      {
        for (i = 0; i < level.game.AccessControl.IPPolicies.length; i++)
        {
          divide(level.game.AccessControl.IPPolicies[i], ",", pol_pol, pol_ip);
          if (pol_ip == args[0])
          {
            level.game.AccessControl.IPPolicies.Remove(i, 1);
            connection.SendLine(StrReplace(msg_ip_remove, "%i", pol_ip));
            return;
          }
        }
        connection.SendLine(msg_ip_nopolicy);
      }
      else {
        connection.SendLine(msg_usage@PREFIX_BUILTIN$"ippolicy <remove> IP-mask");
      }
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"ippolicy <list> | <set> IP-mask <accept|deny> | <remove> IP-mask");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// IP Policy settings
function ExecKeyPolicy( array< string > args, UTelAdSEConnection connection)
{
  local string cmd, pol_key, pol_name;
  local int i;
 
  if (int(Level.EngineVersion) < 2153)
  {
    connection.SendLine("This feature is only available in UT2003 version 2153 and higher");
    return;
  }

  if (CanPerform(connection.Spectator, "Xb"))
	{
    cmd = ShiftArray(args);
    if (cmd == "list")
    {
      for (i = 0; i < level.game.AccessControl.BannedIDs.length; i++)
      {
        divide(level.game.AccessControl.BannedIDs[i], " ", pol_key, pol_name);
        connection.SendLine(StrReplace(StrReplace(msg_key_policy, "%s", pol_name), "%k", pol_key));
      }
    }
    else if (cmd == "set")
    {
      if (args.length == 2)
      {
        for (i = 0; i < level.game.AccessControl.BannedIDs.length; i++)
        {
          divide(level.game.AccessControl.BannedIDs[i], " ", pol_key, pol_name);
          if (pol_key == args[0])
          {
            level.game.AccessControl.BannedIDs[i] = args[0]$" "$args[1];
            connection.SendLine(StrReplace(StrReplace(msg_key_set, "%s", args[1]), "%k", args[0]));
            return;
          }
        }
        level.game.AccessControl.BannedIDs.length = level.game.AccessControl.BannedIDs.length+1;
        level.game.AccessControl.BannedIDs[i] = args[0]$" "$args[1];
        connection.SendLine(StrReplace(StrReplace(msg_key_set, "%s", args[1]), "%k", args[0]));
      }
      else {
        connection.SendLine(msg_usage@PREFIX_BUILTIN$"keypolicy <set> Key-hash Playername");
      }
    }
    else if (cmd == "remove")
    {
      if (args.length == 1)
      {
        for (i = 0; i < level.game.AccessControl.BannedIDs.length; i++)
        {
          divide(level.game.AccessControl.BannedIDs[i], " ", pol_key, pol_name);
          if ((pol_key == args[0]) || (pol_name ~= args[0]))
          {
            level.game.AccessControl.BannedIDs.Remove(i, 1);
            connection.SendLine(StrReplace(StrReplace(msg_key_remove, "%s", pol_name), "%k", pol_key));
            return;
          }
        }
        connection.SendLine(msg_key_nopolicy);
      }
      else {
        connection.SendLine(msg_usage@PREFIX_BUILTIN$"keypolicy <remove> Key-hash|Playername");
      }
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"keypolicy <list> | <set> Key-hash Playername> | <remove> Key-hash|Playername");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

// Tab Completion
function bool TabComplete(array<string> commandline, out SortedStringArray options)
{
  if (commandline.length == 1)
  {
    if (InStr("map", commandline[0]) == 0) AddArray(options, "map");
    if (InStr("kick", commandline[0]) == 0) AddArray(options, "kick");
    if (InStr("bots", commandline[0]) == 0) AddArray(options, "bots");
    if (InStr("maplist", commandline[0]) == 0) AddArray(options, "maplist");
    if (InStr("mutator", commandline[0]) == 0) AddArray(options, "mutator");
    if (InStr("gametype", commandline[0]) == 0) AddArray(options, "gametype");
    if (InStr("ippolicy", commandline[0]) == 0) AddArray(options, "ippolicy");
    if (InStr("keypolicy", commandline[0]) == 0) AddArray(options, "keypolicy");
  }
  else if (commandline.length == 2)
  {
    if (commandline[0] == "map")
    {
      if (InStr("next", commandline[1]) == 0) AddArray(options, commandline[0]@"next");
      if (InStr("restart", commandline[1]) == 0) AddArray(options, commandline[0]@"restart");
    }
    else if (commandline[0] == "kick")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("ban", commandline[1]) == 0) AddArray(options, commandline[0]@"ban");
      if (InStr("session", commandline[1]) == 0) AddArray(options, commandline[0]@"session");
    }
    else if (commandline[0] == "bots")
    {
      if (InStr("add", commandline[1]) == 0) AddArray(options, commandline[0]@"add");
      if (InStr("kill", commandline[1]) == 0) AddArray(options, commandline[0]@"kill");
      if (InStr("set", commandline[1]) == 0) AddArray(options, commandline[0]@"set");
    }
    else if (commandline[0] == "maplist")
    {
      if (InStr("used", commandline[1]) == 0) AddArray(options, commandline[0]@"used");
      if (InStr("add", commandline[1]) == 0) AddArray(options, commandline[0]@"add");
      if (InStr("del", commandline[1]) == 0) AddArray(options, commandline[0]@"del");
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
    }
    else if (commandline[0] == "mutator")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("add", commandline[1]) == 0) AddArray(options, commandline[0]@"add");
      if (InStr("del", commandline[1]) == 0) AddArray(options, commandline[0]@"del");
      if (InStr("show", commandline[1]) == 0) AddArray(options, commandline[0]@"show");
    }
    else if (commandline[0] == "gametype")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("get", commandline[1]) == 0) AddArray(options, commandline[0]@"get");
      if (InStr("set", commandline[1]) == 0) AddArray(options, commandline[0]@"set");
    }
    else if (commandline[0] == "ippolicy")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("set", commandline[1]) == 0) AddArray(options, commandline[0]@"set");
      if (InStr("remove", commandline[1]) == 0) AddArray(options, commandline[0]@"remove");
    }
    else if (commandline[0] == "keypolicy")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("set", commandline[1]) == 0) AddArray(options, commandline[0]@"set");
      if (InStr("remove", commandline[1]) == 0) AddArray(options, commandline[0]@"remove");
    }
  }
  return true;
}

defaultproperties 
{
  msg_onlyaccesscontrolini="This command is only available with AccessControlIni enabled"

  msg_map_nonext="No next map, restarting this map"
  msg_map_changeto="Changing to map"
  msg_map_moved="Moved map '%s' to possition %i"

  msg_mut_list="Mutators available on this server:"
  msg_mut_group="Group %s"
  msg_mut_add="Added mutator '%s' to the list"
  msg_mut_remove="Removed mutator '%s' from the list"
  msg_mut_restart="You have to restart the server for changes to take effect (/map restart)"

  msg_bot_nobotgame="This is not a bot game"
  msg_bot_statsgame="Can't modify bots, stats is enabled"
  msg_bot_gamefull="Can't add bots, game is full"
  msg_bot_onlynamedbots="Can Only Add Named Bots once the Match has Started"
  msg_bot_nobots="No Bots are currently playing"
  msg_bot_nummeric="This Command Requires a Numeric Value between 0 and 32"
  msg_bot_added="Added %i bots"
  msg_bot_removed="Removed %i bots"
  msg_bot_removedname="Removed bot %s"
  msg_bot_setmin="Set minimum players to %i"

  msg_kick_banned="%s has been Banned from this server"
  msg_kick_session="%s has been Banned from this match"
  msg_kick_kicked="%s has been Kicked from this server"
  msg_kick_failed="Failed to remove user '%s' from this server"
  msg_kick_nokickself="Can't kick youself from the server"
  msg_kick_higherlevel="Can't kick admin '%s', your security level is lower"
  msg_kick_isadmin="User '%s' is logged in as administrator, use -force to kick this user"
  msg_kick_nomsgspec="Player '%s' can't be kicked because it's not a real player"

  msg_maplist_list="List of maps in rotation for %s"
  msg_maplist_nomaps="No Maps in rotation list"
  msg_maplist_added="Added '%s' to the map rotation"
  msg_maplist_noneadded="No new maps added to the map rotation"
  msg_maplist_removed="Removed '%s' from the map rotation"
  msg_maplist_noneremoved="No maps removed from the map rotation"
  msg_maplist_listall="Maps available on the server:"
  msg_maplist_inrotation="Map '%s' is in map rotation list"
  msg_maplist_notinrotation="Map '%s' is Not in map rotation list"

  msg_gametype_unknown="Unknown gametype: %s"
  msg_gametype_list="Gametypes available on this server:"
  msg_gametype_get="Sec.  Group    Setting"
  msg_gametype_seclevel="Required security level is %i, you only have %j"
  msg_gametype_update="Changed %s to %v"

  msg_ip_policy="ip: %i policy: %s"
  msg_ip_set="Set policy of %i to %s"
  msg_ip_remove="Removed IP policy for %i"
  msg_ip_nopolicy="There is no policy for that IP-mask"

  msg_key_policy="CDKey hash: %k Player name: %s"
  msg_key_set="Set CDKey hash ban for %k with name %s"
  msg_key_remove="Removed CDKey Hash ban for %k with name %s"
  msg_key_nopolicy="There is no ban for that CDKey hash"
}