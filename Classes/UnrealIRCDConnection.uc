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
        IRCSend("Welcome to UnrealIRCD"@sUsername, 001);
        IRCSend("Your host is "$sIP$":"$string(parent.listenport)@", running UnrealIRCD version"$UnrealIRCD(parent).IRCVERSION, 002);
        IRCSend("This server was created on //FIXME:", 003); //FIXME:
        // TODO: 004
        // TODO: 005
        // TODO: 004
        // TODO: 251
        // TODO: 252
        // TODO: 254
        // TODO: 255
        // TODO: 265
        // TODO: 266
        // TODO: 250
        printMOTD();
        if (parent.VersionNotification != "")
        {
          // FIXME:
          SendLine("");
          SendLine(bold(parent.VersionNotification));
        }
        Login();
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
  tmp = ":"$sIP@code@target@":"$mesg;
  SendLine(tmp);
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