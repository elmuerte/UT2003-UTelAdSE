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
      if (iVerbose > 1) Log("[D] UTelAdSE got username: "$sUsername, 'UTelAdSE');
      if (iVerbose > 1) Log("[D] UTelAdSE got password: "$sPassword, 'UTelAdSE');
      if (!Level.Game.AccessControl.AdminLogin(Spectator, sUsername, sPassword))
    	{
        if (iVerbose > 0) Log("[~] UnrealIRCD login failed from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        SendLine("464 :ERR_PASSWDMISMATCH");
        Close();
      }
      else {
        SendLine("375 :RPL_MOTDSTART");
        SendLine("372 :RPL_MOTD");
        SendLine("376 :RPL_ENDOFMOTD");
      }
    }
  }
}
