///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEConnection.uc
// version:     104
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual Telnet Admin client
//              command prefixes:
//              none      execute console command
//              /         execute build-in
//              .         shortcut for `say`
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEConnection extends TcpLink config;

const MAXHISTSIZE = 10; // size of the history
const PREFIX_BUILTIN = "/";
const PREFIX_SAY = ".";
const TERM_NEGOTIATION = 1.0; // telnet negotiation timeout, in seconds

var globalconfig bool bIssueMsg;
var globalconfig bool bStartChat;
var globalconfig float fLoginTimeout;
var globalconfig float fInvalidLoginDelay;
var globalconfig bool bEnablePager;
var globalconfig bool bAnnounceLogin;

var int iVerbose;

var UTelAdSESpectator Spectator; // message spectator
var UTelAdSE parent; // parent, used to reuse the TelnetHelpers
var string sUsername;
var private string sPassword;
var private int iLoginTries;
var string sIP; // server IP

var private array<string> history; // array with command history
var private int iHistOffset; // current offset in the history
var string inputBuffer; 
var bool bEcho; // echo the input characters
var private bool bEscapeCode; // working on an escape code

var private int iLinesDisplayed; // used for the pager
var array<string> pagerBuffer; // pager buffer

var bool bTelnetGotType, bTelnetGotSize;
var private float fTelnetNegotiation;

var xAdminUser CurAdmin;
var UTelAdSESession Session; // session per connection, can be used to keep variables in TelnetHandlers

var localized string msg_login_incorrect;
var localized string msg_login_timeout;
var localized string msg_login_toomanyretries;
var localized string msg_login_error;
var localized string msg_login_noprivileges;
var localized string msg_login_welcome;
var localized string msg_login_serverstatus;
var localized string msg_unknowncommand;
var localized string msg_pager;
var localized string msg_goodbye;
var localized string msg_shutdownwarning;

// STDIN\STDOUT handlers
var UTelAdSEHelper STDIN;

event Accepted()
{
  local IpAddr addr;

  if (iVerbose > 1) log("[?] Creating UTelAdSE Spectator", 'UTelAdSE');
	Spectator = Spawn(class'UTelAdSESpectator');
	if (Spectator != None) 
  {
    Spectator.Server = self;
  }
  Session = new(None) class'UTelAdSESession';

  // init vars
  GetLocalIP(addr);
  sIP = IpAddrToString(addr);
  sIP = Left(sIP, InStr(sIP, ":"));
  bEcho = true;
  iHistOffset = 0;
  bEscapeCode = false;

  gotostate('telnet_control');

  LinkMode = MODE_Binary;
  ReceiveMode = RMODE_Manual;
  procTelnetControl(); // process telnet controlls
}

event Closed()
{
  Destroy();
}

event Destroyed()
{
  Spectator.Destroy();
  if (IsConnected()) Close();
}

function procTelnetControl()
{
  // don't echo - server: WILL ECHO
  SendText(Chr(255)$Chr(251)$Chr(1));
  // will supress go ahead
  SendText(Chr(255)$Chr(251)$Chr(3));
  // do terminal-type
  SendText(Chr(255)$Chr(253)$Chr(24));
  SendText(Chr(255)$Chr(250)$Chr(24)$Chr(1)$Chr(255)$Chr(240));
  session.setValue("TERM_TYPE", "UNKNOWN", true);
  // do terminal size
  SendText(Chr(255)$Chr(253)$Chr(31));
  // default
  session.setValue("TERM_WIDTH", "80", true);
  session.setValue("TERM_HEIGHT", "25", true);

  bTelnetGotSize = false;
  bTelnetGotType = false;
  fTelnetNegotiation = 0;
  enable('Tick');
}

///////////////////////////////////////////////////////////////////////////////
// Telnet negotiation
///////////////////////////////////////////////////////////////////////////////
state telnet_control {

  // This is realy realy realy bad code
  event Tick(float delta)
  {
    local byte bCode[255];
    local int i, j;
    local string tmp;

    fTelnetNegotiation += delta;

    i = ReadBinary(255,bCode);
    tmp = "";
    for (j = 0; j < i; j++)
    {
      if (bCode[j] == 255) // IAC
      {
        j++;
        if (bCode[j] == 250) // SB
        {
          j++;
          switch (bCode[j])
          {
            case 31:  // term size
                      session.setValue("TERM_WIDTH", string(bCode[j+1]*256+bCode[j+2]), true);
                      session.setValue("TERM_HEIGHT", string(bCode[j+3]*256+bCode[j+4]), true);
                      j = j+5;
                      bTelnetGotSize = true;
                      if (iVerbose > 1) log("[D] received term size:"@session.getValue("TERM_WIDTH")$"x"$session.getValue("TERM_HEIGHT"), 'UTelAdSE');
                      break;
            case 24:  // term type
                      j += 2;
                      tmp = "";
                      while (bCode[j] != 255) 
                      {
                        tmp = tmp$Chr(bCode[j]);
                        j++;
                      }
                      j--;
                      bTelnetGotType = true;
                      session.setValue("TERM_TYPE", tmp, true);
                      if (iVerbose > 1) log("[D] received term type:"@tmp, 'UTelAdSE');
                      break;
          }
        }
      }
    }
    if ((bTelnetGotSize && bTelnetGotType) || (fTelnetNegotiation > TERM_NEGOTIATION))
    {
      disable('Tick');
      LinkMode = MODE_Text;
      ReceiveMode = RMODE_Event;
      if (bIssueMsg) printIssueMessage();
      iLoginTries = 0;
      // start login
      gotostate('loggin_in');
      SendLine("Username: ");
      SetTimer(fLoginTimeout,false);
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// State login fail, waiting for retry
///////////////////////////////////////////////////////////////////////////////
state login_fail {

  // used to delay incorrect login
  event Timer()
  {
    SendLine("Username: ");
    gotostate('loggin_in');
    SetTimer(fLoginTimeout,false);
  }

  event ReceivedText( string Text )
  {
    // do nothing
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

    // fill buffer, while no go ahead (return)
    if (Left(Text, 1) == Chr(255)) return; // telnet commands ignore in this state
    if (Left(Text, 1) == Chr(27)) return; // ignore escaped chars
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
      c = InStr(Text, Chr(13));
      while (c > -1)
      {
        Temp = Left(Text, c);
        Text = Mid(Text, c+1);
        if (bEcho) SendText(Temp);
        inputBuffer = inputBuffer$Temp;
        procLogin(inputBuffer);
        inputBuffer = "";
        c = InStr(Text, Chr(13));
      }
      if (bEcho) SendText(Text);
      inputBuffer = Text;
    }
  }

  //---------------------------------------------------------------------------
  // Try to login
  //---------------------------------------------------------------------------
  function procLogin(string Text)
  {
    local string tmp;
    if (sUsername == "") 
    {
      sUsername = Text;
      SendLine("Password: ");
      bEcho = false;
      if (iVerbose > 1) Log("[D] UTelAdSE got username: "$sUsername, 'UTelAdSE');
      if (sUsername == "") sUsername = Chr(127);
    }
    else {
      sPassword = Text;
      bEcho = true;
      if (iVerbose > 1) Log("[D] UTelAdSE got password: *hidden*", 'UTelAdSE');
      if (!Level.Game.AccessControl.AdminLogin(Spectator, sUsername, sPassword))
    	{
        if (iVerbose > 0) Log("[~] UTelAdSE login failed from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
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
        gotostate('login_fail');
        SetTimer(fInvalidLoginDelay,false);
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
        // succesfull login
        if (bAnnounceLogin) Level.Game.AccessControl.AdminEntered(Spectator, sUsername);
        if (iVerbose > 0) Log("[~] UTelAdSE login succesfull from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
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
        gotostate('logged_in');
        Login();
        SendPrompt();
        return;
      }
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// State client logged in
///////////////////////////////////////////////////////////////////////////////
state logged_in {

  event Timer()
  {
    // do nothing
  }

  event ReceivedText( string Text )
  {
    local int c;
    local string temp;

    if (Left(Text, 1) == Chr(255)) return; // telnet commands ignore in this state

    // if controll char don't buffer
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
    // check first char for control chars
    c = Asc(Left(Text,1));
    //                    CR          BS           ESC         TAB
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
      c = InStr(Text, Chr(13));
      while (c > -1)
      {
        Temp = Left(Text, c);
        Text = Mid(Text, c+1);
        if (bEcho) SendText(Temp);
        inputBuffer = inputBuffer$Temp;
        procInput(inputBuffer);
        inputBuffer = "";
        c = InStr(Text, Chr(13));
      }
      if (bEcho) SendText(Text);
      inputBuffer = Text;
    }
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

///////////////////////////////////////////////////////////////////////////////
// State pager
///////////////////////////////////////////////////////////////////////////////

state auto_pager extends logged_in {

  event ReceivedText( string Text )
  {
    local int i;
    if (Left(Text, 1) == Chr(255)) return; // telnet commands ignore in this state
    if (Left(Text, 1) == Chr(27)) return; // ignore escaped chars

    SendText(Chr(27)$"["$Len(msg_pager)$"D"$Chr(27)$"[K"$Chr(27)$"[1A"); // erase line
    for (i = 0; (pagerBuffer.Length > 0) && (i < int(session.getValue("TERM_HEIGHT", "9999"))); i++)
    {
      SendText(pagerBuffer[0]);
      pagerBuffer.remove(0,1);
    }
    if (pagerBuffer.Length == 0)
    {
      gotostate('logged_in');
      SendPrompt();
    }
    else {
      SendText(Chr(13)$Chr(10)$Reverse(Blink(msg_pager)));
    }
  }
}


//-----------------------------------------------------------------------------
// Precess the input
//-----------------------------------------------------------------------------
function procInput(string Text)
{
  local bool result;
  addHistory(Text);
  switch (Left(Text, 1))
  {
    case PREFIX_SAY     : result = inConsole("say "$Mid(Text, 1)); break;
    case PREFIX_BUILTIN : result = inBuiltin(Mid(Text, 1)); break;
    default : result = inConsole(Text); 
  }
  if (result) SendPrompt();
}

//-----------------------------------------------------------------------------
// Add a line to the history
//-----------------------------------------------------------------------------
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

//-----------------------------------------------------------------------------
// send a line of text, will add a CR+LN to the beginning of the line
//-----------------------------------------------------------------------------
function SendLine(string text)
{
  if ((STDIN == none) && (!IsInState('loggin_in')))
  {
    iLinesDisplayed++;
    if (iLinesDisplayed > int(session.getValue("TERM_HEIGHT", "9999")) && bEnablePager)
    {
      pagerBuffer.length = pagerBuffer.length+1;
      pagerBuffer[pagerBuffer.length-1] = Chr(13)$Chr(10)$text;
      if (!IsInState('auto_pager'))
      {
        SendText(Chr(13)$Chr(10)$Reverse(Blink(msg_pager)));
        if (iVerbose > 1) log("[D] enable pager", 'UTelAdSE');
        gotostate('auto_pager');
      }
      return;
    }
  }
  SendText(Chr(13)$Chr(10)$text);
}

//-----------------------------------------------------------------------------
// send the command prompt
//-----------------------------------------------------------------------------
function SendPrompt()
{
  if (!IsInState('auto_pager'))
  {
    iLinesDisplayed = 0;
    SendLine(sUsername$"@"$sIP$"# ");
  }
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
// Execute a console command
//-----------------------------------------------------------------------------
function bool inConsole(string command)
{
  local string OutStr, args;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Tc"))
  {
    SendLine(msg_login_noprivileges);
    return true;
  }
  if (iVerbose > 1) log("[D] UTelAd console: "$command, 'UTelAdSE');
  // add `name` to say
  if (InStr(command, " ") > -1)
  {
    args = Mid(command, InStr(command, " ")+1);
    command = Left(command, InStr(command, " "));
    if (Caps(command) == "SAY") args = sUsername$": "$args;
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
    SendLine(msg_login_noprivileges);
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
// Handle short key
//-----------------------------------------------------------------------------
function bool inShortkey(int key)
{
  local int hideprompt, i;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Th"))
  {
    SendLine(msg_login_noprivileges);
    return true;
  }
  if (iVerbose > 1) log("[D] UTelAd shortkey: "$key, 'UTelAdSE');
  for (i=0; i<Parent.TelnetHelpers.Length; i++)
	{
		if (Parent.TelnetHelpers[i].ExecShortKey(key, hideprompt, self))
			return (hideprompt == 0); 
	}
  return true;
}

//-----------------------------------------------------------------------------
// Internal function for tabcompletion
//-----------------------------------------------------------------------------
function string GetCommonBegin(SortedStringArray slist)
{
  local int i;
  local string common, tmp2;

  common = slist.GetItem(0);
  for (i = 1; i < slist.Count(); i++)
  {
    tmp2 = slist.GetItem(i);
    while ((InStr(tmp2, common) != 0) && (common != "")) common = Left(common, Len(common)-1);
    if (common == "") return "";
  }
  return common;
}

//-----------------------------------------------------------------------------
// Tab completion
//-----------------------------------------------------------------------------
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
  if (class'wString'.static.Split2(temp, " ", commandline) == 0)
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

//-----------------------------------------------------------------------------
// Easter egg
//-----------------------------------------------------------------------------
function bool TempDoDopefish()
{Level.ConsoleCommand("say Dopefish lives!");Level.ConsoleCommand("say DrSin get's eaten by the Dopefish");
SendLine("           __"$Chr(13)$chr(10)$"         __)_\\___"$Chr(13)$chr(10)$" /(    /´      __`\\"$Chr(13)$chr(10)$"(  \\_/´   _   /  \\_I");
SendLine(" \\       I `  \\_()O),"$Chr(13)$chr(10)$" /  _    I_/__..-.-.´"$Chr(13)$chr(10)$"(  / \\__   ´ `,I I I   Dopefish lives!");
SendLine(" \\(   `\\I_____.'-'-'   http://www.dopefish.com"); inputbuffer="";SendPrompt(); return true;}

//-----------------------------------------------------------------------------
// Print issue message
//-----------------------------------------------------------------------------
function printIssueMessage()
{
  SendLine(",------------------------------------------------------------");
  SendLine("| "$Bold("Welcome to UTelAdSE version "$parent.VERSION));
  SendLine("| Running on "$Bold(Level.Game.GameReplicationInfo.ServerName));
  SendLine("| by Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>");
  SendLine("| The Drunk Snipers               http://www.drunksnipers.com");
  SendLine("`------------------------------------------------------------");
}

defaultproperties
{
  bIssueMsg=true
  bStartChat=false
  fLoginTimeout=30.0
  fInvalidLoginDelay=5.0
  bEnablePager=true
  bAnnounceLogin=false

  msg_login_incorrect="Login incorrect."
  msg_login_timeout="Login timeout"
  msg_login_toomanyretries="Too many tries, goodbye!"
  msg_login_error="Error during login."
  msg_login_noprivileges="You do not have enough privileges."
  msg_login_welcome="There are %i clients logged in"
  msg_login_serverstatus="Server status:"
  msg_unknowncommand="Unknown command"
  msg_goodbye="Goodbye!"
  msg_shutdownwarning="Warning, this will shutdown the server. To shutdown the server use: `%s yes`"

  msg_pager="-- Press any key to continue --"
}
