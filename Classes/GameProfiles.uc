///////////////////////////////////////////////////////////////////////////////
// filename:    GameProfiles.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     manage game profiles
///////////////////////////////////////////////////////////////////////////////

class GameProfiles extends UTelAdSEHelper;

const VERSION = "100";

// place holder

function bool Init()
{
  log("[~] Loading Game Profiles support"@VERSION, 'UTelAdSE');
  return true;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEConnection connection)
{
  switch (command)
  {
    case "profiles" : execProfiles(args, connection); return true;
    case "pe" : execProfileEdit(args, connection); return true;
  }
}

function execProfiles(array< string > args, UTelAdSEConnection connection)
{
  local string cmd;
  if (CanPerform(connection.Spectator, "Tg"))
	{
    cmd = ShiftArray(args);
    if (cmd == "list")
    {
      //
    }
    else if (cmd == "edit")
    {
      //
    }
    else if (cmd == "save")
    {
      //
    }
    else if (cmd == "cancel")
    {
      //
    }
    else if (cmd == "remove")
    {
      //
    }
    else if (cmd == "load")
    {
      //
    }
    else if (cmd == "import")
    {
      //
    }
    else if (cmd == "export")
    {
      //
    }
    else {
      connection.SendLine(msg_usage@PREFIX_BUILTIN$"profiles <list> | <edit> profile | <save> | <cancel> | <remove> profile | <load> profile | <import> profile location | <export> profile filename");
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
      if (InStr("edit", commandline[1]) == 0) AddArray(options, commandline[0]@"edit");
      if (InStr("save", commandline[1]) == 0) AddArray(options, commandline[0]@"save");
      if (InStr("cancel", commandline[1]) == 0) AddArray(options, commandline[0]@"cancel");
      if (InStr("remove", commandline[1]) == 0) AddArray(options, commandline[0]@"remove");
      if (InStr("load", commandline[1]) == 0) AddArray(options, commandline[0]@"load");
      if (InStr("import", commandline[1]) == 0) AddArray(options, commandline[0]@"import");
      if (InStr("export", commandline[1]) == 0) AddArray(options, commandline[0]@"export");
    }
  }
  return true;
}

defaultproperties
{
}
