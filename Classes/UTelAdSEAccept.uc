///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEAccept.uc
// version:     105
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     General accepting class of UTelAdSE
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEAccept extends TcpLink config;

const PREFIX_BUILTIN = "/";
const PREFIX_SAY = ".";

var config float fLoginTimeout;

var int iVerbose;
var class<UTelAdSESpectator> SpectatorClass;
var UTelAdSESpectator Spectator; // message spectator
var UTelAdSE parent; // parent, used to reuse the TelnetHelpers

var string sUsername;
var string sPassword;

var xAdminUser CurAdmin;
var UTelAdSESession Session; // session per connection, can be used to keep variables in TelnetHandlers

var string inputBuffer; 
var UTelAdSEHelper STDIN; // active STDIN handlers

var localized string msg_login_timeout;
var localized string msg_goodbye;
var localized string msg_unknowncommand;
var localized string msg_shutdownwarning;
var localized string msg_noprivileges;

//-----------------------------------------------------------------------------
// Socket accepted start working
//-----------------------------------------------------------------------------
event Accepted()
{
  if (iVerbose > 1) log("[?] Creating UTelAdSE Spectator", 'UTelAdSE');
	Spectator = spawn(SpectatorClass);
	if (Spectator != None) 
  {
    Spectator.Server = self;
  }
  Session = new(none) class'UTelAdSESession';

  LinkMode = MODE_Binary;
  if (int(Level.EngineVersion) < 2175)
  {
    gotostate('initialize');
    // ReceiveBinary is broken
    if (iVerbose > 1) log("[D] Unreal engine version below 2175, switch to RMODE_Manual", 'UTelAdSE');
    ReceiveMode = RMODE_Manual;
  }
  startInitialize();
}

event Closed()
{
  if (iVerbose > 1) log("[D] Connection closed, destroying server peer...", 'UTelAdSE');
  Destroy();
}

event Destroyed()
{
  Level.Game.AccessControl.AdminLogout(Spectator);
  Spectator.Destroy();
  if (IsConnected()) Close();
}

//-----------------------------------------------------------------------------
// Initial Telnet Control handshaking
//-----------------------------------------------------------------------------
function startInitialize()
{
  StartLogin();
}

//-----------------------------------------------------------------------------
// Start login sequence
//-----------------------------------------------------------------------------
function StartLogin()
{
  gotostate('loggin_in');
  SetTimer(fLoginTimeout,false);
}

///////////////////////////////////////////////////////////////////////////////
// Connection initialization
///////////////////////////////////////////////////////////////////////////////
state initialize {  

  event ReceivedBinary( int Count, byte B[255] )
  {
  }
}

///////////////////////////////////////////////////////////////////////////////
// State login fail, waiting for retry
///////////////////////////////////////////////////////////////////////////////
state login_fail {

  event ReceivedText( string Text )
  {
  }

  event ReceivedBinary( int Count, byte B[255] )
  {
  }
}

///////////////////////////////////////////////////////////////////////////////
// State client in loggin in
///////////////////////////////////////////////////////////////////////////////
state loggin_in {
  // login timeout
  event Timer()
  {
    SendLine(msg_login_timeout);
    SendLine("");
    Close();
  }

  event ReceivedText( string Text )
  {
    local int c;
    local string Temp;

    if (InStr(Text, Chr(13)) == -1)
    {
      inputBuffer = inputBuffer$Text;
      return;
    }
    else {
      c = InStr(Text, Chr(13));
      while (c > -1)
      {
        Temp = Left(Text, c);
        Text = Mid(Text, c+1);
        inputBuffer = inputBuffer$Temp;
        procLogin(inputBuffer);
        inputBuffer = "";
        c = InStr(Text, Chr(13));
      }
      inputBuffer = Text;
    }
  }

  event ReceivedBinary( int Count, byte B[255] )
  {
    local string tmp;
    local int i;
    if (count < 1) return;
    for (i = 0; i < count; i++)
    {
      tmp = tmp$Chr(B[i]);
    }
    ReceivedText(tmp);
  }

  //---------------------------------------------------------------------------
  // Try to login
  //---------------------------------------------------------------------------
  function procLogin(string Text)
  {
  }
}

///////////////////////////////////////////////////////////////////////////////
// State client logged in
///////////////////////////////////////////////////////////////////////////////
state logged_in {
  event ReceivedText( string Text )
  {
    local int c;
    local string Temp;

    if (InStr(Text, Chr(13)) == -1)
    {
      inputBuffer = inputBuffer$Text;
      return;
    }
    else {
      c = InStr(Text, Chr(13));
      while (c > -1)
      {
        Temp = Left(Text, c);
        Text = Mid(Text, c+1);
        inputBuffer = inputBuffer$Temp;
        procInput(inputBuffer);
        inputBuffer = "";
        c = InStr(Text, Chr(13));
      }
      inputBuffer = Text;
    }
  }

  event ReceivedBinary( int Count, byte B[255] )
  {
    local string tmp;
    local int i;
    if (count < 1) return;
    for (i = 0; i < count; i++)
    {
      tmp = tmp$Chr(B[i]);
    }
    ReceivedText(tmp);
  }
}

///////////////////////////////////////////////////////////////////////////////
// State steal_stdin, input is handled by an other command
///////////////////////////////////////////////////////////////////////////////
state steal_stdin extends logged_in {

  event ReceivedText( string Text )
  {
    if (STDIN == none)
    {
      if (iVerbose > 1) log("[E] No STDIN handler, switching back", 'UTelAdSE');
      gotostate('logged_in');
      return;
    }
    STDIN.HandleInput(Text, self);
  }
}

//-----------------------------------------------------------------------------
// Process the input
//-----------------------------------------------------------------------------
function procInput(string Text)
{
  local bool result;
  switch (Left(Text, 1))
  {
    case PREFIX_SAY     : result = inConsole("say "$Mid(Text, 1)); break;
    case PREFIX_BUILTIN : result = inBuiltin(Mid(Text, 1)); break;
    default : result = inConsole(Text); 
  }
  if (result) SendPrompt();
}

//-----------------------------------------------------------------------------
// send a line of text
//-----------------------------------------------------------------------------
function SendLine(string text)
{
  SendText(text$Chr(13)$Chr(10));
}

//-----------------------------------------------------------------------------
// send the command prompt
//-----------------------------------------------------------------------------
function SendPrompt()
{
}

//-----------------------------------------------------------------------------
// Execute a console command
//-----------------------------------------------------------------------------
function bool inConsole(string command)
{
  local string OutStr, args;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Tc"))
  {
    SendLine(msg_noprivileges);
    return true;
  }
  if (iVerbose > 1) log("[D] UTelAd console: "$command, 'UTelAdSE');
  // add `name` to say
  if (InStr(command, " ") > -1)
  {
    args = Mid(command, InStr(command, " ")+1);
    command = Left(command, InStr(command, " "));
    if (Caps(command) == "SAY") 
    {
      Level.Game.Broadcast(Spectator, args, 'Say');
      return true;
    }
    command = command$" "$args;
  }
  if ((Caps(command) == "EXIT") || (Caps(command) == "QUIT"))
  {
    if (InStr(caps(args), "Y") == -1)
    {
      OutStr = msg_shutdownwarning;
      ReplaceText(OutStr, "%s", command);
      // show warning
      SendLine(OutStr);
      return true;
    }
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

//-----------------------------------------------------------------------------
// Execute builtin command
//-----------------------------------------------------------------------------
function bool inBuiltin(string command)
{
  local array< string > args;
  local string temp;
  local int hideprompt, i;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Tb"))
  {
    SendLine(msg_noprivileges);
    return true;
  }
  if (iVerbose > 1) log("[D] UTelAd buildin: "$command, 'UTelAdSE');
  Divide(command, " ", command, temp);
  class'wString'.static.Split2(temp, " ", args, true);
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		if (Parent.TelnetHelpers[i].ExecBuiltin(command, args, hideprompt, self))
			return (hideprompt == 0); 
	}
  SendLine(msg_unknowncommand);
  return true;
}

//-----------------------------------------------------------------------------
// Try to logout Logout
//-----------------------------------------------------------------------------
function Logout()
{
  local int i, canlogout;
  local array<string> messages;
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		Parent.TelnetHelpers[i].OnLogout(self, canlogout, messages);
	}
  if (canlogout != 0)
  {
    for (i = 0; i < messages.length; i++)
    {
      SendLine(messages[i]);
    }
    SendPrompt();
  }
  else {
    SendLine(msg_goodbye);
    SendLine("");
    Close();
  }
}

//-----------------------------------------------------------------------------
// Execute builtin command
//-----------------------------------------------------------------------------
function Login()
{
  local int i;
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		Parent.TelnetHelpers[i].OnLogin(self);
	}
}

//-----------------------------------------------------------------------------
// Make the text bold
//-----------------------------------------------------------------------------
function string Bold(string text)
{
  return class'UTelAdSEHelper'.static.Bold(text);
}

//-----------------------------------------------------------------------------
// Make the text blink
//-----------------------------------------------------------------------------
function string Blink(string text)
{
  return class'UTelAdSEHelper'.static.Blink(text);
}

//-----------------------------------------------------------------------------
// Make the text reverse video
//-----------------------------------------------------------------------------
function string Reverse(string text)
{
  return class'UTelAdSEHelper'.static.Reverse(text);
}

//-----------------------------------------------------------------------------
// Clear the screen
//-----------------------------------------------------------------------------
function CLSR()
{
  SendText(Chr(27)$"[2J");
}

//-----------------------------------------------------------------------------
// Move the cursor to a specified location
//-----------------------------------------------------------------------------
function MoveCursor(int top, int left)
{
  SendText(Chr(27)$"["$string(top)$";"$string(left)$"H");
}

//-----------------------------------------------------------------------------
// Take over the handling of the input 
//-----------------------------------------------------------------------------
function captureSTDIN(UTelAdSEHelper handler)
{
  if (handler == none) return;
  STDIN = handler;
  gotostate('steal_stdin');
  if (iVerbose > 1) log("[D] "$handler.name@"is taking over STDIN", 'UTelAdSE');
}

//-----------------------------------------------------------------------------
// Return the STDIN to the connection
//-----------------------------------------------------------------------------
function releaseSTDIN()
{
  gotostate('logged_in');
  STDIN = none;
  if (iVerbose > 1) log("[D] STDIN released", 'UTelAdSE');
}

//-----------------------------------------------------------------------------
// Setting
//-----------------------------------------------------------------------------
static function FillPlayInfo(PlayInfo PI)
{
	Super.FillPlayInfo(PI);
}

defaultproperties 
{
  SpectatorClass=class'UTelAdSESpectator'

  msg_login_timeout="Login timeout"
  msg_unknowncommand="Unknown command"
  msg_goodbye="Goodbye!"
  msg_shutdownwarning="Warning, this will shutdown the server. To shutdown the server use: `%s yes`"
  msg_noprivileges="You do not have enough privileges."
}