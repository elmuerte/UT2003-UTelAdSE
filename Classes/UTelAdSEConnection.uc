///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEConnection.uc
// version:     105
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual Telnet Admin client
//              command prefixes:
//              none      execute console command
//              /         execute build-in
//              .         shortcut for `say`
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEConnection extends UTelAdSEAccept config;

const MAXHISTSIZE = 20; // size of the history
const TERM_NEGOTIATION = 1.0; // telnet negotiation timeout, in seconds

// telnet protocol
const T_IAC       = 255;
const T_WILL      = 251;
const T_WONT      = 252;
const T_DO        = 253;
const T_DONT      = 254;
const T_SB        = 250;
const T_SE        = 240;
// options
const O_ECHO      = 1;
const O_SGOAHEAD  = 3;
const O_TERMINAL  = 24;
const O_WSIZE     = 31;

var config bool bIssueMsg;
var config bool bStartChat;
var config float fInvalidLoginDelay;
var config bool bEnablePager;
var config bool bAnnounceLogin;

var private int iLoginTries;

var private array<string> history; // array with command history
var private int iHistOffset; // current offset in the history
var bool bEcho; // echo the input characters
var private bool bEscapeCode; // working on an escape code

var private int iLinesDisplayed; // used for the pager
var array<string> pagerBuffer; // pager buffer

var bool bTelnetGotType, bTelnetGotSize;
var private float fTelnetNegotiation;

var localized string msg_login_incorrect;
var localized string msg_login_toomanyretries;
var localized string msg_login_error;
var localized string msg_login_welcome;
var localized string msg_login_serverstatus;
var localized string msg_pager;

//-----------------------------------------------------------------------------
// Socket accepted start working
//-----------------------------------------------------------------------------
event Accepted()
{
  bEcho = true;
  iHistOffset = 0;
  bEscapeCode = false;
  Super.Accepted();
}

//-----------------------------------------------------------------------------
// Initial Telnet Control handshaking
//-----------------------------------------------------------------------------
function startInitialize()
{
  // don't echo - server: WILL ECHO
  SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_ECHO));
  // will supress go ahead
  SendText(Chr(T_IAC)$Chr(T_WILL)$Chr(O_SGOAHEAD));
  // do terminal-type
  SendText(Chr(T_IAC)$Chr(T_DO)$Chr(O_TERMINAL));
  SendText(Chr(T_IAC)$Chr(T_SB)$Chr(O_TERMINAL)$Chr(1)$Chr(T_IAC)$Chr(T_SE));
  session.setValue("TERM_TYPE", "UNKNOWN", true);
  // do terminal size
  SendText(Chr(T_IAC)$Chr(T_DO)$Chr(O_WSIZE));
  // default
  session.setValue("TERM_WIDTH", "80", true);
  session.setValue("TERM_HEIGHT", "25", true);
  // do envoirement variables
  SendText(Chr(T_IAC)$Chr(T_DO)$Chr(39));

  if (int(Level.EngineVersion) < 2175)
  {
    if (iVerbose > 1) log("[D] Unreal engine version below 2175, pre control processing", 'UTelAdSE');
    bTelnetGotSize = false;
    bTelnetGotType = false;
    fTelnetNegotiation = 0; 
    enable('Tick');
  }
  else {
    StartLogin();
  }
}

//-----------------------------------------------------------------------------
// Start login sequence
//-----------------------------------------------------------------------------
function StartLogin()
{
  if (bIssueMsg) printIssueMessage();
  iLoginTries = 0;
  // start login
  super.StartLogin();
  SendLine("Username: ");
}

//-----------------------------------------------------------------------------
// Process incoming telnet control codes
//-----------------------------------------------------------------------------
function procTelnetControl(int Count, byte B[255])
{
  local int j;
  local string tmp;

  for (j = 0; j < Count; j++)
  {
    if (B[j] == T_IAC) // IAC
    {
      j++;
      if (B[j] == T_SB) // SB
      {
        j++;
        switch (B[j])
        {
          case O_WSIZE:  // term size
                    session.setValue("TERM_WIDTH", string(B[j+1]*256+B[j+2]), true);
                    session.setValue("TERM_HEIGHT", string(B[j+3]*256+B[j+4]), true);
                    j = j+5;
                    bTelnetGotSize = true;
                    if (iVerbose > 1) log("[D] received term size:"@session.getValue("TERM_WIDTH")$"x"$session.getValue("TERM_HEIGHT"), 'UTelAdSE');
                    break;
          case O_TERMINAL:  // term type
                    j += 2;
                    tmp = "";
                    while (B[j] != T_IAC) 
                    {
                      tmp = tmp$Chr(B[j]);
                      j++;
                    }
                    j--;
                    bTelnetGotType = true;
                    session.setValue("TERM_TYPE", tmp, true);
                    if (iVerbose > 1) log("[D] received term type:"@tmp, 'UTelAdSE');
                    break;
          case 39: // envoirement vars
                    j += 2;
                    tmp = "";
                    while (B[j] != T_IAC) 
                    {
                      tmp = tmp@B[j];
                      j++;
                    }
                    j--;
                    if (iVerbose > 1) log("[D] received envoirement vars, contact elmuerte about this: "$tmp, 'UTelAdSE');
                    break;
                    
        }
      }
      else if (B[j] == T_WILL)
      {
        j++;
        switch (B[j])
        {
          case 39: // will envoirement                  SEND    VAR   
                   SendText(Chr(T_IAC)$Chr(T_SB)$Chr(39)$Chr(1)$Chr(0)$Chr(T_IAC)$Chr(T_SE));
                   break;
        }
      }
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// Telnet negotiation
///////////////////////////////////////////////////////////////////////////////
state initialize {  

  function oldProcTelnetControl(int Count, byte B[255])
  {
    procTelnetControl(Count, B);
    if ((bTelnetGotSize && bTelnetGotType) || (fTelnetNegotiation > TERM_NEGOTIATION))
    {
      disable('Tick');

      if (int(Level.EngineVersion) < 2175)
      {
        if (iVerbose > 1) log("[D] Unreal engine version below 2175, switch to MODE_Text", 'UTelAdSE');
        LinkMode = MODE_Text;
      } // else remain in binary mode
      ReceiveMode = RMODE_Event;
      StartLogin();
    }
  }

  // This is realy realy realy bad code
  event Tick(float delta)
  {
    local byte bCode[255];
    local int i;

    fTelnetNegotiation += delta;
    if (int(Level.EngineVersion) >= 2175) return;
    i = ReadBinary(255,bCode);
    oldProcTelnetControl(i, bCode);
  }

  event ReceivedBinary( int Count, byte B[255] )
  {
    oldProcTelnetControl(count, B);
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
}

///////////////////////////////////////////////////////////////////////////////
// State client in loggin in
///////////////////////////////////////////////////////////////////////////////
state loggin_in {
  event ReceivedText( string Text )
  {
    local int c;
    local string Temp;

    // fill buffer, while no go ahead (return)
    if (Left(Text, 1) == Chr(T_IAC)) return; // telnet commands ignore in this state
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

  event ReceivedBinary( int Count, byte B[255] )
  {
    if (count < 1) return;
    if (B[0] == 255) procTelnetControl(Count, B);
    else super.ReceivedBinary(Count, B);
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
          SendLine(msg_noprivileges);
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

    if (Left(Text, 1) == Chr(T_IAC)) return; // telnet commands ignore in this state

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

  event ReceivedBinary( int Count, byte B[255] )
  {
    if (count < 1) return;
    if (B[0] == 255) procTelnetControl(Count, B);
    else super.ReceivedBinary(Count, B);
  }
}

///////////////////////////////////////////////////////////////////////////////
// State pager
///////////////////////////////////////////////////////////////////////////////

state auto_pager extends logged_in {

  event ReceivedText( string Text )
  {
    local int i;
    if (Left(Text, 1) == Chr(T_IAC)) return; // telnet commands ignore in this state
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
// Process the input
//-----------------------------------------------------------------------------
function procInput(string Text)
{
  addHistory(Text);
  super.procInput(Text);
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
// Handle short key
//-----------------------------------------------------------------------------
function bool inShortkey(int key)
{
  local int hideprompt, i;
  if (!Level.Game.AccessControl.CanPerform(Spectator, "Th"))
  {
    SendLine(msg_noprivileges);
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
    commandline[0] = ""; // use empty line
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

//-----------------------------------------------------------------------------
// Setting
//-----------------------------------------------------------------------------
static function FillPlayInfo(PlayInfo PI)
{
  PI.AddSetting("UTelAdSE", "bAnnounceLogin", "Announce login", 255, 3, "check");
  PI.AddSetting("UTelAdSE", "bIssueMsg", "Show login banner", 255, 4, "check");
  PI.AddSetting("UTelAdSE", "bStartChat", "Start in Chat mode", 255, 5, "check");
  PI.AddSetting("UTelAdSE", "fLoginTimeout", "Login timeout", 255, 6, "text");
  PI.AddSetting("UTelAdSE", "fInvalidLoginDelay", "Invalid login delay", 255, 5, "text");
  // call connection shit
	PI.PopClass();
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
  msg_login_welcome="There are %i clients logged in"
  msg_login_serverstatus="Server status:"
  msg_pager="-- Press any key to continue --"
}
