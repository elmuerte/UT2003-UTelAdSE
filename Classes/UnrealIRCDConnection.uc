///////////////////////////////////////////////////////////////////////////////
// filename:    UnrealIRCDConnection.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual IRC server
///////////////////////////////////////////////////////////////////////////////

class UnrealIRCDConnection extends UTelAdSEAccept config;

state loggin_in {
  
  event ReceivedText( string Text )
  {
    ReplaceText(Text, Chr(10), "");
    log("Input:"@Text);
    super.ReceivedText(Text);
  }

  function procLogin(string Text)
  {
    local array<string> input;
    if (class'wString'.static.split2(Text, " ", input) < 2) return;
    if (Caps(input[0]) == "NICK") sUsername = input[1];
    if (Caps(input[0]) == "PASS") sPassword = input[1];
    if (Caps(input[0]) == "USER") 
    {
      // login here
      if (iVerbose > 1) Log("[D] UnrealIRCD got username: "$sUsername, 'UTelAdSE');
      if (iVerbose > 1) Log("[D] UnrealIRCD got password: "$sPassword, 'UTelAdSE');
      if (!Level.Game.AccessControl.AdminLogin(Spectator, sUsername, sPassword))
    	{
        if (iVerbose > 0) Log("[~] UnrealIRCD login failed from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        SendLine("464 ERR_PASSWDMISMATCH");
        Close();
      }
      else {
        CurAdmin = Level.Game.AccessControl.GetLoggedAdmin(Spectator);
        if (CurAdmin == none)
        {
          //FIXME: SendLine(msg_login_error);
          Close();
          return;
        }
        if (!Level.Game.AccessControl.CanPerform(Spectator, "Tl"))
        {
          //FIXME: SendLine(msg_noprivileges);
          Close();
          return;
        }
        if (spectator != none) {
          spectator.PlayerReplicationInfo.PlayerName = sUsername;
        }
        // succesfull login
        if (iVerbose > 0) Log("[~] UnrealIRCD login succesfull from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        gotostate('logged_in'); 
        IRCSend(":Welcome to UnrealIRCD"@sUsername, 001);
        IRCSend(":Your host is "$sIP$":"$string(parent.listenport)$", running UnrealIRCD version"@UnrealIRCD(parent).IRCVERSION, 002);
        IRCSend(":This server was created on //FIXME:", 003); //FIXME: create date
        IRCSend("UTelAdSE/"$parent.VERSION$" UnrealIRCD/"$UnrealIRCD(parent).IRCVERSION$"", 004); //FIXME: version
        // PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003
        // ommited: WALLCHOPS MAXBANS=0 NICKLEN=-1 TOPICLEN=0 CHANMODES= KNOCK MODES=4
        // #servername
        // &adminname
        IRCSend("PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003 MAPPING=rfc1459 :are supported by this server", 005); //FIXME:
        IRCSend(":There are"@Level.Game.NumPlayers@"players and"@Level.Game.NumSpectators@"specators online", 251);
        IRCSend("1 :Admins online", 252); // FIXME: 252
        // TODO: 254, channels formed
        // TODO: 255, I have .. clients
        // TODO: 265, current count
        // TODO: 266, current global
        // TODO: 250, highest count
        printMOTD();
        if (parent.VersionNotification != "")
        {
          // FIXME: in motd ?
          SendLine("");
          SendLine(bold(parent.VersionNotification));
        }
        Login();
        // join #servername
        SendLine(":"$sUsername$" JOIN :#test");
        IRCSend("#test :chat channel - talk to players here", 332); // FIXME: topic
        IRCSend("#test server 1", 333); // FIXME: set by
        // join &username
        SendLine(":"$sUsername$" JOIN :&"$sUsername);
        IRCSend("&"$sUsername$" :Enter here your admin commands", 332); // FIXME: topic
        IRCSend("&"$sUsername$" server 1", 333); // FIXME: set by
        return;
      }
    }
  }
}

state logged_in {
  event ReceivedText( string Text )
  {
    ReplaceText(Text, Chr(10), "");
    log("Input:"@Text);
    super.ReceivedText(Text);
  }

}

function IRCSend(coerce string mesg, optional coerce string code, optional coerce string target)
{
  local string tmp;
  if (target == "") target = sUsername;
  if (code == "") code = "NOTICE";
  tmp = ":"$sIP@code@target@" "$mesg;
  SendLine(tmp);
}

function procInput(string Text)
{
  // do nothing now
}

function printMOTD()
{
  IRCSend("- "$sIP@"Message of the Day", 375);
  IRCSend("- ,------------------------------------------------------------", 372);
  IRCSend("- | "$Bold("Welcome to UnrealIRCD version "$UnrealIRCD(parent).IRCVERSION), 372);
  IRCSend("- | Running on "$Bold(Level.Game.GameReplicationInfo.ServerName), 372);
  IRCSend("- | by Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>", 372);
  IRCSend("- | The Drunk Snipers               http://www.drunksnipers.com", 372);
  IRCSend("- `------------------------------------------------------------", 372);
  IRCSend("- End of /MOTD command.", 376);
}