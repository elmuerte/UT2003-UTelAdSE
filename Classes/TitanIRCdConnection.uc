///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCdConnection.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual IRC server
///////////////////////////////////////////////////////////////////////////////

class TitanIRCdConnection extends UTelAdSEAccept config;

var string sNickname;
var string sUserhost;
var string sQuitMsg;
var TitanIRCd IRCd;
var byte id;

event Accepted()
{
  if (IRCd.IRCUsers.length == 0) IRCd.CreatePlayerList(); // may wanna fix this
  super.Accepted();
  TitanIRCdSpectator(Spectator).IRCClient = self;
}

event Closed()
{
  IRCd.RemoveUserPlayerList(Spectator, sQuitMsg);
  super.Closed();
}

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
        SendRaw("464 ERR_PASSWDMISMATCH");
        Close();
      }
      else {
        CurAdmin = Level.Game.AccessControl.GetLoggedAdmin(Spectator);
        if (CurAdmin == none)
        {
          //FIXME: SendRaw(msg_login_error);
          Close();
          return;
        }
        if (!Level.Game.AccessControl.CanPerform(Spectator, "Tl"))
        {
          //FIXME: SendRaw(msg_noprivileges);
          Close();
          return;
        }
        if (spectator != none) {
          spectator.PlayerReplicationInfo.PlayerName = sUsername;
        }
        // succesfull login
        sNickname = IRCd.getNickName(IRCd.fixName(sUsername), Spectator);
        sUserhost = input[1]$"@"$Parent.IPAddrToIp(RemoteAddr);         

        if (iVerbose > 0) Log("[~] TitanIRCd login succesfull from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        gotostate('logged_in'); 
        IRCSend(":Welcome to TitanIRCd"@sNickname, 001);
        IRCSend(":Your host is "$Parent.sIP$":"$string(parent.listenport)$", running TitanIRCd version"@IRCd.IRCVERSION, 002);
        IRCSend(":This server was created on"@IRCd.sCreateTime, 003); //FIXME: create date
        IRCSend("UTelAdSE/"$parent.VERSION$" TitanIRCd/"$IRCd.IRCVERSION$"", 004); //FIXME: version
        // PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003
        // ommited: WALLCHOPS MAXBANS=0 NICKLEN=-1 TOPICLEN=0 CHANMODES= KNOCK MODES=4
        IRCSend("PREFIX=(ov)@+ CHANTYPES=#& MAXCHANNELS=2 NETWORK=UT2003 MAPPING=rfc1459 :are supported by this server", 005); //FIXME:
        IRCSend(":There are"@Level.Game.NumPlayers@"players and"@Level.Game.NumSpectators@"specators online", 251);
        IRCSend(Level.Game.AccessControl.LoggedAdmins.Length@":Admins online", 252); // FIXME: 252
        // TODO: 254, channels formed
        // TODO: 255, I have .. clients
        // TODO: 265, current local
        // TODO: 266, current global
        // TODO: 250, highest count
        printMOTD();
        if (parent.VersionNotification != "")
        {
          // FIXME: in motd ?
          //SendRaw("");
          //SendRaw(bold(parent.VersionNotification));
        }
        Login();
        SendRaw(":"$sUsername$" NICK "$sNickname); // force nick change
        SendRaw(":"$sNickname$" MODE "$sNickname$" :+i");
        ircJoin(IRCd.sChatChannel);
        IRCd.AddUserPlayerList(sNickname, sUserhost, Spectator);
        Spectator.bMsgEnable = true;
        ircJoin("&"$sUsername);
        return;
      }
    }
  }
}

state logged_in {
 event ReceivedText( string Text )
  {
    ReplaceText(Text, Chr(10), "");
    super.ReceivedText(Text);
  }
}

function IRCSend(coerce string mesg, optional coerce string code, optional coerce string target)
{
  local string tmp;
  if (target == "") target = sNickname;
  if (code == "") code = "NOTICE";
  tmp = ":"$Parent.sIP@code@target@mesg;
  SendRaw(tmp);
}

function SendLine(string line)
{
  // send to admin channel
  SendRaw(":"$sNickname$"!"$sUserhost@"PRIVMSG &"$sUsername@":"$line); // come from server
}

function SendRaw(string line)
{
  log("Output["$id$"]:"@line);
  SendText(line$Chr(13)$Chr(10));
}

function procInput(string Text)
{
  local string prefix;
  local array<string> input;
  log("Input["$id$"]:"@Text);

  if (class'wString'.static.split2(Text, " ", input) < 1) return;
  if (Left(input[0], 1) == ":") 
  {
    // is prefixed
    prefix = class'wArray'.static.ShiftS(input);
  }
  switch (caps(class'wArray'.static.ShiftS(input)))
  {
    case "PRIVMSG": ircPRIVMSG(input); break;
    case "PING": SendRaw("PONG "$input[0]); break;
    case "QUIT": ircQUIT(input); break;
  }
}

function ircTopic(string channel)
{
  if (channel == ("&"$sUsername))
  {
    IRCSend(channel$" :Enter your admin commands here", 332); // FIXME: topic
    IRCSend(channel$" "$Parent.sIP$" "$unixTimeStamp(), 333); 
  }
  else {
    IRCSend(channel$" :chat channel - talk to players here", 332); // FIXME: topic
    IRCSend(channel$" "$Parent.sIP$" "$unixTimeStamp(), 333); 
  }
}

function ircNames(string channel)
{
  local string names;
  local int i;

  if (channel ~= ("&"$sUsername)) 
  {
    IRCSend("@"@channel$" :@"$sUsername, 353); // WTF is @ ??
    IRCSend(channel$" :End of /NAMES list.", 366);
    return; // private channel
  }

  for (i = 0; i < IRCd.IRCUsers.length; i++)
  {
  	names = names$IRCd.IRCUsers[i].Flag$IRCd.IRCUsers[i].Nickname$" "; 
  }
  IRCSend("@"@channel$" :"$names, 353); // WTF is @ ??
  IRCSend(channel$" :End of /NAMES list.", 366);
}

function ircJoin(string channel)
{
  SendRaw(":"$sNickname$"!"$sUserhost@"JOIN :"$channel);
  ircTopic(channel); 
  ircNames(channel); 
}

function ircPRIVMSG(array<string> input)
{
  local string text;
  if (input.length < 1) return;
  log("PRIVMSG from:"@input[0]);
  text = class'wArray'.static.ShiftS(input);
  if (Left(input[0], 1) == ":") input[0] = Mid(input[0], 1); // remove leading :
  if (text ~= IRCd.sChatChannel)
  {    
    Level.Game.Broadcast(Spectator, class'wArray'.static.join(input, " "), 'Say');
    return;
  }
  else if (text ~= ("&"$sUsername))
  {
    text = class'wArray'.static.join(input, " ");
    switch (Left(Text, 1))
    {
      //case PREFIX_SAY     : result = inConsole("say "$Mid(Text, 1)); break;
      case "." : inBuiltin(Mid(Text, 1)); break;
      default : inConsole(Text); 
    }
    return;
  }
}

function ircQUIT(array<string> input)
{
  if (Left(input[0], 1) == ":") input[0] = Mid(input[0], 1); // remove leading :
  sQuitMsg = class'wArray'.static.join(input, " ");
  Close();
}

////////////////////////

function string unixTimeStamp()
{
  return string(class'wTime'.static.mktime(Level.Year, Level.Month, Level.Day, Level.Hour, Level.Minute, Level.Second));
}

function printMOTD()
{
  IRCSend("- "$Parent.sIP@"Message of the Day", 375);
  IRCSend("- ,------------------------------------------------------------", 372);
  IRCSend("- | "$Bold("Welcome to TitanIRCd version "$IRCd.IRCVERSION), 372);
  IRCSend("- | Running on "$Bold(Level.Game.GameReplicationInfo.ServerName), 372);
  IRCSend("- | by Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>", 372);
  IRCSend("- | The Drunk Snipers               http://www.drunksnipers.com", 372);
  IRCSend("- `------------------------------------------------------------", 372);
  IRCSend("- End of /MOTD command.", 376);
}

defaultproperties
{
  SpectatorClass=class'TitanIRCdSpectator'
  sQuitMsg="Connection closed"
}