///////////////////////////////////////////////////////////////////////////////
// filename:    DefaultBuiltins.uc
// version:     102
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     default builtins commands for UTelAdSE
///////////////////////////////////////////////////////////////////////////////

class DefaultBuiltins extends UTelAdSEHelper;

const VERSION = "102";

var localized string msg_chat_nospectator;
var localized string msg_chat_mode;
var localized string msg_noplayers;
var localized string msg_pager_status;

var localized string msg_status_gametype;
var localized string msg_status_map;
var localized string msg_status_mutators;
var localized string msg_status_players;
var localized string msg_status_spectators;
var localized string msg_status_of;

var localized string msg_player;

function bool Init()
{
  log("[~] Loading default UTelAdSE builtins"@VERSION, 'UTelAdSE');
  return true;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEAccept connection)
{
  switch (command)
  {
    case "logout" : hideprompt = 1; connection.Logout(); return true;
    case "togglechat" : ToggleChat(connection); return true;
    case "status" : SendStatus(connection); return true;
    case "players" : SendPlayers(connection); return true;
    case "togglepager" : TogglePager(connection); return true;
  }
}

function bool ExecShortkey(int key, out int hideprompt, UTelAdSEAccept connection)
{
  local array< string > null;
  switch (key)
  {
    case 4 : return ExecBuiltin("logout", null, hideprompt, connection); // ^D
    case 3 : return ExecBuiltin("togglechat", null, hideprompt, connection); // ^C
    case 16: return ExecBuiltin("players", null, hideprompt, connection); // ^P
    case 19: return ExecBuiltin("status", null, hideprompt, connection); // ^S
  }
  return false;
}

function ToggleChat(UTelAdSEAccept connection)
{
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ts"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (connection.Spectator != None)
  {
    connection.Spectator.bMsgEnable = !connection.Spectator.bMsgEnable;
    connection.SendLine(msg_chat_mode@connection.Spectator.bMsgEnable);
  }
  else {
    connection.SendLine(msg_chat_nospectator);
  }
}

function TogglePager(UTelAdSEAccept connection)
{
  if (UTelAdSEConnection(connection) == none) return;
  UTelAdSEConnection(connection).bEnablePager = !UTelAdSEConnection(connection).bEnablePager;
  connection.SendLine(msg_pager_status@UTelAdSEConnection(connection).bEnablePager);
}

function SendStatus(UTelAdSEAccept connection)
{
  local string tmp;
  local Mutator M;

  connection.SendLine(AlignLeft("| "$msg_status_gametype$":", 20)@Mid( string(Level.Game.Class), InStr(string(Level.Game.Class), ".")+1));
  connection.SendLine(AlignLeft("| "$msg_status_map$":", 20)@Left(string(Level), InStr(string(Level), ".")));
  for (M = Level.Game.BaseMutator.NextMutator; M != None; M = M.NextMutator) 
  {
    if (tmp != "") tmp = tmp$", ";
    tmp = tmp$(M.GetHumanReadableName());
  }
  connection.SendLine(AlignLeft("| "$msg_status_mutators$":", 20)@tmp);
  connection.SendLine(AlignLeft("| "$msg_status_players$":", 20)@Level.Game.NumPlayers@msg_status_of@Level.Game.MaxPlayers);
  connection.SendLine(AlignLeft("| "$msg_status_spectators$":", 20)@Level.Game.NumSpectators@msg_status_of@Level.Game.MaxSpectators);
}

function SendPlayers(UTelAdSEAccept connection)
{
	local Controller C;
	local PlayerReplicationInfo PRI;
  local string IP;

  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Tp"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }

  if (Level.Game.NumPlayers == 0)
  {
    connection.SendLine(msg_noplayers);
    return;
  }

	for( C=Level.ControllerList;C!=None;C=C.NextController )
  {
	  PRI = C.PlayerReplicationInfo;
		if( (PRI != None) && !PRI.bBot && MessagingSpectator(C) == None )
    {
      IP = PlayerController(C).GetPlayerNetworkAddress();
			IP = Left(IP, InStr(IP, ":"));
			connection.SendLine(AlignLeft("| "$msg_player, 6)@C.PlayerNum$":"@AlignLeft(PRI.PlayerName, 15)@AlignRight(PRI.Score, 4)@AlignRight(PRI.Ping, 5)@IP);
    }
  }
}

function bool TabComplete(array<string> commandline, out SortedStringArray options)
{
  if (commandline.length > 1) return false;
  if (InStr("status", commandline[0]) == 0) AddArray(options, "status");
  if (InStr("logout", commandline[0]) == 0) AddArray(options, "logout");
  if (InStr("players", commandline[0]) == 0) AddArray(options, "players");
  if (InStr("togglechat", commandline[0]) == 0) AddArray(options, "togglechat");
  if (InStr("togglepager", commandline[0]) == 0) AddArray(options, "togglepager");
  return true;
}

defaultproperties
{
  msg_chat_nospectator="Error: No spectator"
  msg_chat_mode="Chat mode is now:"
  msg_noplayers="There are no players on the server"
  msg_pager_status="Pager enabled is:"

  msg_status_gametype="Gametype"
  msg_status_map="Current map"
  msg_status_mutators="Mutators"
  msg_status_players="Current players"
  msg_status_spectators="Spectators"
  msg_status_of="of"

  msg_player="Player"
}