///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCdConnection.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual IRC server
///////////////////////////////////////////////////////////////////////////////

class TitanIRCdConnection extends UTelAdSEAccept config;

var string sNickname;
var float fPingDelay;

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
      if (iVerbose > 1) Log("[D] TitanIRCd got username: "$sUsername, 'UTelAdSE');
      if (iVerbose > 1) Log("[D] TitanIRCd got password: "$sPassword, 'UTelAdSE');
      if (!Level.Game.AccessControl.AdminLogin(Spectator, sUsername, sPassword))
    	{
        if (iVerbose > 0) Log("[~] TitanIRCd login failed from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
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
        setTimer(fPingDelay, true);
        sNickname = sUsername; //FIXME: find free nick
        if (iVerbose > 0) Log("[~] TitanIRCd login succesfull from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        gotostate('logged_in'); 
        IRCSend(":Welcome to TitanIRCd"@sNickname, 001);
        IRCSend(":Your host is "$sIP$":"$string(parent.listenport)$", running TitanIRCd version"@TitanIRCd(parent).IRCVERSION, 002);
        IRCSend(":This server was created on FIXME", 003); //FIXME: create date
        IRCSend("UTelAdSE/"$parent.VERSION$" TitanIRCd/"$TitanIRCd(parent).IRCVERSION$"", 004); //FIXME: version
        // PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003
        // ommited: WALLCHOPS MAXBANS=0 NICKLEN=-1 TOPICLEN=0 CHANMODES= KNOCK MODES=4
        // #servername
        // &adminname
        IRCSend("PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003 MAPPING=rfc1459 :are supported by this server", 005); //FIXME:
        IRCSend(":There are"@Level.Game.NumPlayers@"players and"@Level.Game.NumSpectators@"specators online", 251);
        IRCSend("1 :Admins online", 252); // FIXME: 252
        // TODO: 254, channels formed
        // TODO: 255, I have .. clients
        // TODO: 265, current local
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
        SendLine(":"$snickname$" MODE "$snickname$" :+i");
        ircJoin("#"$sIP);
        //ircJoin("&"$sUsername);
        return;
      }
    }
  }
}

state logged_in {
  function Timer()
  {
    SendLine("PING :"$sIP);
  }

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
  if (target == "") target = sNickname;
  if (code == "") code = "NOTICE";
  tmp = ":"$sIP@code@target@mesg;
  SendLine(tmp);
}

function SendLine(string line)
{
  log("Output:"@line);
  super.SendLine(line);
}

function procInput(string Text)
{
  // do nothing now
}

function ircTopic(string channel)
{
  if (channel == ("&"$sUsername))
  {
    IRCSend(channel$" :Enter here your admin commands", 332); // FIXME: topic
    IRCSend(channel$" "$sIP$" "$unixTimeStamp(), 333); // FIXME: set by
  }
  else {
    IRCSend(channel$" :chat channel - talk to players here", 332); // FIXME: topic
    IRCSend(channel$" "$sIP$" "$unixTimeStamp(), 333); // FIXME: set by
  }
}

function ircNames(string channel)
{
  local PlayerController P;
  local string names;
  local int i;

  if (channel == ("&"$sUsername)) return; // private channel

  foreach DynamicActors(class'PlayerController', P)
  {
    if (P.PlayerReplicationInfo.bBot == false) 
      if (P.PlayerReplicationInfo.bAdmin == true) names = names$"@"; 
        else names = names$"+";
  	names = names$P.PlayerReplicationInfo.PlayerName$" "; //FIXME: fix names (replace space and @)
    log(getPlayerHost(P)); 
  }
  IRCSend("@"@channel$" :"$names, 353); // WTF is @ ??
  IRCSend(channel$" :End of /NAMES list.", 366);
}

function ircJoin(string channel)
{
  SendLine(":"$getPlayerHost(Spectator)@" JOIN :"$channel);
  SendLine(":"$sIP@"MODE"@channel@":+o"@sNickname);
  ircTopic(channel); 
  ircNames(channel); 
}

function string unixTimeStamp()
{
  return "12345679";
}

function string getPlayerHost(PlayerController P)
{
  local string host;
  host = P.GetPlayerNetworkAddress();
  if (host == "") host = "local";
  return P.PlayerReplicationInfo.PlayerName$"!"$Mid(P, InStr(P, ".")+1)$"@"$host; //FIXME: playername
}

function printMOTD()
{
  IRCSend("- "$sIP@"Message of the Day", 375);
  IRCSend("- ,------------------------------------------------------------", 372);
  IRCSend("- | "$Bold("Welcome to TitanIRCd version "$TitanIRCd(parent).IRCVERSION), 372);
  IRCSend("- | Running on "$Bold(Level.Game.GameReplicationInfo.ServerName), 372);
  IRCSend("- | by Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>", 372);
  IRCSend("- | The Drunk Snipers               http://www.drunksnipers.com", 372);
  IRCSend("- `------------------------------------------------------------", 372);
  IRCSend("- End of /MOTD command.", 376);
}

defaultproperties
{
  fPingDelay=60
}