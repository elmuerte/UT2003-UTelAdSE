///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEConnection.uc
// version:     103
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual Telnet Admin client
//              command prefixes:
//              none      execute console command
//              /         execute build-in
//              .         shortcut for `say`
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEConnection extends TcpLink config;

const DEBUG = false;
const MAXHISTSIZE = 10; // size of the history
const PREFIX_BUILTIN = "/";
const PREFIX_SAY = ".";

var globalconfig bool bIssueMsg;
var globalconfig bool bStartChat;

var UTelAdSESpectator Spectator; // message spectator
var UTelAdSE parent; // parent, used to reuse the TelnetHelpers
var bool bLoggedin;
var string sUsername;
var string sPassword;
var int iLoginTries;
var string sIP; // server IP
var bool bIgnoreInput;

var array<string> history; // array with command history
var int iHistOffset; // current offset in the history
var string inputBuffer; 
var bool bEcho; // echo the input characters
var bool bEscapeCode; // working on an escape code
var xAdminUser CurAdmin;

var localized string msg_login_incorrect;
var localized string msg_login_toomanyretries;
var localized string msg_login_error;
var localized string msg_login_noprivileges;
var localized string msg_login_welcome;
var localized string msg_login_serverstatus;
var localized string msg_unknowncommand;

event Accepted()
{
  local IpAddr addr;
  if (DEBUG) log("[?] Creating UTelAdSE Spectator");
	Spectator = Spawn(class'UTelAdSESpectator');
	if (Spectator != None) 
  {
    Spectator.Server = self;
  }

  // init vars
  GetLocalIP(addr);
  sIP = IpAddrToString(addr);
  sIP = Left(sIP, InStr(sIP, ":"));
  bLoggedin = false;
  bIgnoreInput = false;
  bEcho = true;
  iHistOffset = 0;
  bEscapeCode = false;

  // don't echo - server: WILL ECHO
  SendText(Chr(255)$Chr(251)$Chr(1));
  // will supress go ahead
  SendText(Chr(255)$Chr(251)$Chr(3));

  if (bIssueMsg) 
  {
    SendLine(",------------------------------------------------------------");
    SendLine("| "$Bold("Welcome to UTelAdSE version "$parent.VERSION));
    SendLine("| Running on "$Bold(Level.Game.GameReplicationInfo.ServerName));
    SendLine("| by Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>");
    SendLine("| The Drunk Snipers               http://www.drunksnipers.com");
    SendLine("`------------------------------------------------------------");
  }
  iLoginTries = 0;
  // start login
  SendLine("Username: ");
}

event Closed()
{
  log("close event");
  Destroy();
}

event Destroyed()
{
  log("destroyed event");
  if (IsConnected()) Close();
}

event ReceivedText( string Text )
{
  local int c;
  if (bIgnoreInput) return;
  if (Left(Text, 1) == Chr(255)) return; // telnet commands ignore 
  // if controll char don't buffer
  if (bLoggedin)
  {
    // ESC+key
    if (bEscapeCode)
    {
      if (inputBuffer == "")
      {
        if (inShortkey(Asc(Left(Text,1)))) SendPrompt();
        bEscapeCode = false;
        return;
      }
      else {
        SendText(Chr(7)); // bell
        return;
      }
    }
    c = Asc(Left(Text,1));
    if ((c < 32) && (c != 13) && (c != 8) && (c != 27) && (c != 9))
    {
      if (inputBuffer == "")
      {
        if (inShortkey(c)) SendPrompt();
        return;
      }
      else {
        SendText(Chr(7)); // bell
        return;
      }
    }
    // change BS to backspace char
    else if (c == 8) Text = Chr(127);
    // tab char, try to complete
    else if (c == 9)
    {
      if (inputBuffer != "")
      {
        DoTabComplete();
        return;
      }
      else {
        SendText(Chr(7)); // bell
        return;
      }
    }
    // escape codes
    else if (c == 27) 
    {
      // arrow up
      if (Mid(Text, 2, 1) == "A")
      {
        if ((History.length > 0) && (iHistOffset < History.length))
        {
          if (Len(inputBuffer) > 0) SendText(Chr(27)$"["$Len(inputBuffer)$"D"$Chr(27)$"[K"); // erase line
          if (iHistOffset < History.length) iHistOffset++;
          inputBuffer = History[ History.length - iHistOffset ];
          SendText(inputBuffer);
        }
      }
      // arrow down
      else if (Mid(Text, 2, 1) == "B")
      {
        if (History.length > 0) 
        {
          if (Len(inputBuffer) > 0) SendText(Chr(27)$"["$Len(inputBuffer)$"D"$Chr(27)$"[K"); // erase line
          if (iHistOffset > 1) 
          {
            iHistOffset--;
            inputBuffer = History[ History.length - iHistOffset ];
            SendText(inputBuffer);
          }
          else {
            inputBuffer = "";
          }
        }
      }
      else {
        if (Len(Text) > 1)
        {
          // got escape sequence
          if (inputBuffer == "")
          {
            if (inShortkey(Asc(Left(Text,1)))) SendPrompt();
            bEscapeCode = false;
            return;
          }
          else {
            SendText(Chr(7)); // bell
            return;
          }
        }
        else {
          // get escape code next time
          bEscapeCode = true;
        }
      }
      return;
    }
  }
  // fill buffer, while no go ahead (return)
  if (InStr(Text, Chr(13)) == -1)
  {
    // perform backspace
    if (Asc(Left(Text,1)) == 127)
    {
      if (inputBuffer != "") 
      {
        Text = Chr(8)$Chr(27)$"[K";
        inputBuffer = Left(inputBuffer, Len(inputBuffer)-1);
      }
      else return;
    }
    else {
      inputBuffer = inputBuffer$Text;
    }
    if (bEcho) SendText(Text);
    return;
  }
  else {
    if (bEcho) SendText(Text);
    procInput(inputBuffer);
    inputBuffer = "";
  }
}

// don't let QAPete catch you while reading this code he might think you are a nerd
function procInput(string Text)
{
  local bool result;
  local string tmp;
  // try to login
  if (!bLoggedin)
  {
    if (sUsername == "") 
    {
      sUsername = Text;
      SendLine("Password: ");
      bEcho = false;
      if (DEBUG) Log("[D] UTelAdSE got username: "$sUsername);
      if (sUsername == "") sUsername = Chr(127);
    }
    else {
      sPassword = Text;
      bEcho = true;
      if (DEBUG) Log("[D] UTelAdSE got password: *hidden*");
      if (!Level.Game.AccessControl.AdminLogin(Spectator, sUsername, sPassword))
    	{
        Log("[~] UTelAdSE login failed from: "$IpAddrToString(RemoteAddr));
        SendLine("");
        SendLine(msg_login_incorrect);
        iLoginTries++;
        if (iLoginTries >= 3)
        {
          SendLine(msg_login_toomanyretries);
          Close();
          return;
        }
    		sUsername = "";
        sPassword = "";
        SendLine("");
        bIgnoreInput = true;
        SetTimer(5.0,false);
    		return;
    	}
      else {
        CurAdmin = Level.Game.AccessControl.GetLoggedAdmin(Spectator);
        if (CurAdmin == none)
        {
          SendLine(msg_login_error);
          Close();
          return;
        }
        if (!Level.Game.AccessControl.CanPerform(Spectator, "Tl"))
        {
          SendLine(msg_login_noprivileges);
          Close();
          return;
        }
        if (spectator != none) {
          spectator.PlayerReplicationInfo.PlayerName = sUsername;
        }
        Level.Game.AccessControl.AdminEntered(Spectator, sUsername);
        Log("[~] UTelAdSE login succesfull from: "$IpAddrToString(RemoteAddr));
        bLoggedin = true;
        if (parent.VersionNotification != "")
        {
          SendLine("");
          SendLine(bold(parent.VersionNotification));
        }
        SendLine("");
        tmp = msg_login_welcome;
        ReplaceText(tmp, "%i", Bold(string(Parent.ConnectionCount)));
        SendLine(tmp);
        SendLine(msg_login_serverstatus);
        inBuiltin("status");
        SendLine("");
        if (bStartChat) inBuiltin("togglechat");
        SendPrompt();
        return;
      }
    }
  }
  else {   // start working
    addHistory(Text);
    switch (Left(Text, 1))
    {
      case PREFIX_SAY     : result = inConsole("say "$Mid(Text, 1)); break;
      case PREFIX_BUILTIN : result = inBuiltin(Mid(Text, 1)); break;
      default : result = inConsole(Text); 
    }
    if (result) SendPrompt();
  }
}

function addHistory(string item)
{
  if (item == "") return;
  History.length = History.length+1;
  History[History.length - 1] = item;
  iHistOffset = 0;
  if (History.length > MAXHISTSIZE)
  {
    History.Remove(0,1);
  }
}

// used to delay incorrect login
event Timer()
{
  SendLine("Username: ");
  bIgnoreInput = false;
}

// send a line of text, will add a CR+LN to the beginning of the line
function SendLine(string text)
{
  SendText(Chr(13)$Chr(10)$text);
}

// send the command prompt
function SendPrompt()
{
  SendLine(sUsername$"@"$sIP$"# ");
}

// make text show up bold
function string Bold(string text)
{
  return Chr(27)$"[1m"$text$Chr(27)$"[0m";
}

// execute a console command
function bool inConsole(string command)
{
  local string OutStr, args;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Tc"))
  {
    SendLine(msg_login_noprivileges);
    return true;
  }
  if (DEBUG) log("[D] UTelAd console: "$command);
  // add `name` to say
  if (InStr(command, " ") > -1)
  {
    args = Mid(command, InStr(command, " ")+1);
    command = Left(command, InStr(command, " "));
    if (Caps(command) == "SAY") args = sUsername$": "$args;
    command = command$" "$args;
  }
  if (Spectator == none) {
    OutStr = Level.ConsoleCommand(command);
  }
  else {
    OutStr = Spectator.ConsoleCommand(command);
  }
  if (OutStr != "") SendLine(OutStr);
  return true;
}

function bool inBuiltin(string command)
{
  local array< string > args;
  local string temp;
  local int hideprompt, i;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Tb"))
  {
    SendLine(msg_login_noprivileges);
    return true;
  }
  if (DEBUG) log("[D] UTelAd buildin: "$command);
  Divide(command, " ", command, temp);
  Split(temp, " ", args);
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		if (Parent.TelnetHelpers[i].ExecBuiltin(command, args, hideprompt, self))
			return (hideprompt == 0); 
	}
  SendLine(msg_unknowncommand);
  return true;
}

function bool inShortkey(int key)
{
  local int hideprompt, i;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Th"))
  {
    SendLine(msg_login_noprivileges);
    return true;
  }
  if (DEBUG) log("[D] UTelAd shortkey: "$key);
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		if (Parent.TelnetHelpers[i].ExecShortKey(key, hideprompt, self))
			return (hideprompt == 0); 
	}
  return true;
}

function string GetCommonBegin(SortedStringArray slist)
{
  local int i;
  local string common, tmp2;

  common = slist.GetItem(i);
  for (i = 1; i < slist.Count(); i++)
  {
    tmp2 = slist.GetItem(i);
    while ((InStr(tmp2, common) != 0) && (common != "")) common = Left(common, Len(common)-1);
    if (common == "") return "";
  }
  return common;
}

function bool DoTabComplete()
{
  local int i;
  local array<string> commandline;
  local SortedStringArray options;
  local string temp;

  if((inputbuffer~="lives!")&&(History.length>0))if(History[0]~="dopefish")return TempDoDopefish();
  if (Left(inputbuffer, 1) != PREFIX_BUILTIN) 
  {
    SendText(Chr(7)); // bell
    return false;
  }
  temp = Mid(inputbuffer, 1);
  if (split(temp, " ", commandline) == 0)
  {
    SendText(Chr(7)); // bell
    return false;
  }
  options = new class'SortedStringArray';
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		Parent.TelnetHelpers[i].TabComplete(commandline, options);
	}
  if (options.count() == 0)
  {
    SendText(Chr(7)); // bell
    return true;
  }
  if (options.count() == 1)
  {
    temp = PREFIX_BUILTIN$options.GetItem(0)$" ";
    if (Len(inputBuffer) > 0) SendText(Chr(27)$"["$Len(inputBuffer)$"D"$Chr(27)$"[K"$temp); // erase line
    inputbuffer = temp;
    return true;
  }
  if (Len(inputBuffer) > 0) SendText(Chr(27)$"["$Len(inputBuffer)$"D"$Chr(27)$"[K"); // erase line
  for (i = 0; i < options.count(); i++)
  {
    SendLine(PREFIX_BUILTIN$options.GetItem(i));
  }
  SendPrompt();
  inputbuffer = PREFIX_BUILTIN$GetCommonBegin(options);
  SendText(inputbuffer);
}

function bool TempDoDopefish()
{Level.ConsoleCommand("say Dopefish lives!");Level.ConsoleCommand("say DrSin get's eaten by the Dopefish");
SendLine("           __"$Chr(13)$chr(10)$"         __)_\\___"$Chr(13)$chr(10)$" /(    /´      __`\\"$Chr(13)$chr(10)$"(  \\_/´   _   /  \\_I");
SendLine(" \\       I `  \\_()O),"$Chr(13)$chr(10)$" /  _    I_/__..-.-.´"$Chr(13)$chr(10)$"(  / \\__   ´ `,I I I   Dopefish lives!");
SendLine(" \\(   `\\I_____.'-'-'   http://www.dopefish.com"); inputbuffer="";SendPrompt(); return true;}

defaultproperties
{
  bIssueMsg=true
  bStartChat=false

  msg_login_incorrect="Login incorrect."
  msg_login_toomanyretries="Too many tries, goodbye!"
  msg_login_error="Error during login."
  msg_login_noprivileges="You do not have enough privileges."
  msg_login_welcome="There are %i clients logged in"
  msg_login_serverstatus="Server status:"
  msg_unknowncommand="Unknown command"
}
