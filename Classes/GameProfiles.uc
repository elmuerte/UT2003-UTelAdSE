///////////////////////////////////////////////////////////////////////////////
// filename:    GameProfiles.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     manage game profiles (via Evolution's Ladder)
//              http://www.organized-evolution.com/Ladder/
///////////////////////////////////////////////////////////////////////////////

class GameProfiles extends UTelAdSEHelper;

const VERSION = "100";

var private LadderGameRules LadderRules;

var localized string msg_norules;
var localized string msg_list;
var localized string msg_nosuchprofile;

function bool Init()
{
  local LadderProfiles A;

  foreach Level.AllActors( class'LadderProfiles', A )
  {
    log("[~] Found ladder profiles version:"@A.VER, 'UTelAdSE');
    break;
	}
  if (A == none)
  {
    log("[E] Ladder Profiles not correctly installed", 'UTelAdSE');
    return false;
  }
  else log("[~] Loaded Game Profiles support"@VERSION, 'UTelAdSE');
  return true;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEConnection connection)
{
  local GameRules GR;
  if (LadderRules == none)
  {
    for (GR=Level.Game.GameRulesModifiers;GR!=None;GR=GR.NextGameRules)
      if (LadderGameRules(GR) != None)
      {
        LadderRules = LadderGameRules(GR);
        log("[~] Found ladder game rules", 'UTelAdSE');
      }
  }
  if (LadderRules == none)
  {
    connection.SendLine(msg_norules);
    return true;
  }

  switch (command)
  {
    case "profiles" : execProfiles(args, connection); return true;
    case "pe" : execProfileEdit(args, connection); return true;
    case "pm" : execProfileEdit(args, connection); return true;
  }
}

function bool viewProfile(int index, UTelAdSEConnection connection)
{
  local ProfileConfigSet TempPCS;
  local PlayInfo TempPI;
  local class<GameInfo> GIClass;
	local class<AccessControl> ACClass;
  local array< class<Mutator> > MClass;
  local array<ProfileConfigSet.ProfileMutator> AllPCSMutators;
  local array<ProfileConfigSet.ProfileMap> AllPCSMaps;
  local class<Mutator> MutClass;
  local int i, n;

  TempPCS = LadderRules.LadderProfiles[Index];
  if (TempPCS != none)
  {
    TempPCS.StartEdit();
    TempPCS.EndEdit(false);

    GIClass = TempPCS.GetGameClass();
    if (GIClass == None)
    {
      // TODO: show error message
      connection.SendLine("no GameInfo class");
      return true;
    }
    ACClass = TempPCS.GetAccessClass();
    if (ACClass == None)
    {
      // TODO: show error message
      connection.SendLine("no AccessControl class");
      return true;
    }
    AllPCSMutators = TempPCS.GetProfileMutators();
    for (i=0; i < AllPCSMutators.Length; i++)
		{
			MutClass = class<Mutator>(DynamicLoadObject(AllPCSMutators[i].MutatorName, class'Class'));
			if (MutClass != None)
			{
				MClass[MClass.Length] = MutClass;
			}
      // TODO: show error message
			else log("ErrorRemoteMutator@TempStr");
		}

    // TODO: localize
    connection.SendLine("Profile:"@connection.Bold(LadderRules.Profiles[index].ProfileName));
    connection.SendLine("Gametype:"@string(GIClass));
    // game info
    // TODO: localize
    connection.SendLine(connection.Reverse(Chr(9)$"Settings"));
    TempPI = new(None) class'PlayInfo';
  	GIClass.static.FillPlayInfo(TempPI);
	  ACClass.static.FillPlayInfo(TempPI);
    for (i=0;i<MClass.Length;i++) 
    {
      MClass[i].static.FillPlayInfo(TempPI);
    }
    
    for (i=0;i < TempPI.Settings.Length;i++)
    {
      n = TempPCS.GetParamIndex(TempPI.Settings[i].SettingName);
      if (n > -1)
      {
        connection.SendLine(TempPI.Settings[n].SettingName@"="@TempPCS.GetParam(n));
      }
    }

    // mutators
    // TODO: localize
    connection.SendLine(connection.Reverse(Chr(9)$"Mutators"));
    connection.SendLine("Required"$Chr(9)$"Name");
    for (i=0; i<AllPCSMutators.Length; i++)
		{
      connection.SendLine(AllPCSMutators[i].bRequired$Chr(9)$Chr(9)$AllPCSMutators[i].MutatorName);
    }

    // maps
    AllPCSMaps = TempPCS.GetProfileMaps();
    // TODO: localize
    connection.SendLine(connection.Reverse(Chr(9)$"Maps"));
    connection.SendLine("Order"$Chr(9)$"Required"$Chr(9)$"Name");
    for (i=0;i<AllPCSMaps.Length;i++)
    {
	   connection.SendLine(AllPCSMaps[i].MapListOrder$Chr(9)$AllPCSMaps[i].bRequired$Chr(9)$Chr(9)$AllPCSMaps[i].MapName);
    }


    return true;
  }
  return false;
}

function execProfiles(array< string > args, UTelAdSEConnection connection)
{
  local string cmd;
  local int i, j, index;
  local bool bDelay;

  if (CanPerform(connection.Spectator, "Tg"))
	{
    cmd = ShiftArray(args);
    if (cmd == "list")
    {
      connection.SendLine(msg_list);
      for (i = 0; i < LadderRules.AllLadderProfiles.Count(); i++)
      {
        index = int(LadderRules.AllLadderProfiles.GetItem(i));
        connection.SendLine(index$chr(9)$LadderRules.Profiles[index].bActive$chr(9)$LadderRules.Profiles[index].ProfileName);
      }
    }
    else if (cmd == "view")
    {
      index = -1;
      if (args.length > 0)
      {
        if (CanPerform(connection.Spectator, "Ls"))
    		{
          if (IsNumeric(args[0]))
          {
            index = int(args[0]);
            cmd = args[0];
          }
          else {
            cmd = class'wString'.static.trim(class'wArray'.static.join(args, " "));
            if (cmd != "")
            {
              index = LadderRules.AllLadderProfiles.FindTagId(cmd);
              if (index > -1) index = int(LadderRules.AllLadderProfiles.GetItem(index));
            }
          }
        }
        else {
          connection.SendLine(msg_noprivileges);
          return;
        }
      }
      else {
        index = LadderRules.FindActiveProfile();
        // TODO: localize
        cmd = "Active profile";
      }
      if (Index > -1 && Index < LadderRules.LadderProfiles.Length)
      {
        if (!viewProfile(index, connection))
          connection.SendLine(StrReplace(msg_nosuchprofile, "%s", cmd));
      }
      else {
        connection.SendLine(StrReplace(msg_nosuchprofile, "%s", cmd));
      }
    }
    else if (cmd == "switch")
    {
      if (CanPerform(connection.Spectator, "Ls"))
    	{
        index = -1;
        j = 0;
        for (i = 0; i < args.length; i++)
        {
          if (args[i] ~= "-matches")
          {
            ShiftArray(args);
            j = int(ShiftArray(args));
            i = 0;
          }
          if (args[i] ~= "-delay")
          {
            bDelay = true;
            ShiftArray(args);
            i = 0;
          }
        }
        if (args.length > 0)
        {
          if (IsNumeric(args[0]))
          {
            index = int(args[0]);
          }
          else {
            cmd = class'wString'.static.trim(class'wArray'.static.join(args, " "));
            if (cmd != "")
            {
              index = LadderRules.AllLadderProfiles.FindTagId(cmd);
              if (index > -1) index = int(LadderRules.AllLadderProfiles.GetItem(index));
            }
          }
          if (Index > -1 && Index < LadderRules.LadderProfiles.Length)
          {
            if (bDelay)
            {
              LadderRules.WaitApplyProfile(index, j);
              // TODO: connection.SendLine(msg_switch_delay);
            }
            else {
              LadderRules.ApplyProfile(index, j);
              // TODO: connection.SendLine(msg_switch);
            }
          }
          else {
            connection.SendLine(StrReplace(msg_nosuchprofile, "%s", cmd));
          }
        }
        else {
          connection.SendLine(msg_usage@PREFIX_BUILTIN$"profiles <switch> [-matches #] [-delay] name|id");
        }
      }
      else {
        connection.SendLine(msg_noprivileges);
      }
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"profiles <list> | <view> [name|id] | <switch> [-matches #] [-delay] name|id");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

function execProfileEdit(array< string > args, UTelAdSEConnection connection)
{
  local string cmd;
  if (CanPerform(connection.Spectator, ".."))
	{
    cmd = ShiftArray(args);
    if (cmd == "Tg")
    {
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"pe <maps> maps ... | <mutators> | <settings> ... | <save> | <cancel>");
    }
  }
  else {
    connection.SendLine(msg_noprivileges);
  }
}

function bool TabComplete(array<string> commandline, out SortedStringArray options)
{
  if (commandline.length == 1)
  {
    if (InStr("profiles", commandline[0]) == 0) AddArray(options, "profiles");
    if (InStr("pe", commandline[0]) == 0) AddArray(options, "pe");
  }
  else if (commandline.length == 2)
  {
    if (commandline[0] == "profiles")
    {
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("view", commandline[1]) == 0) AddArray(options, commandline[0]@"view");
      if (InStr("switch", commandline[1]) == 0) AddArray(options, commandline[0]@"switch");
    }
  }
  return true;
}

defaultproperties
{
  msg_norules="Ladder game rules not found, is ladder installed correctly ?"
  msg_list="id      active  name"
  msg_nosuchprofile="No such profile: %s"
}
