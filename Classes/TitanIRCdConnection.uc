///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCdConnection.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The actual IRC server
///////////////////////////////////////////////////////////////////////////////

class TitanIRCdConnection extends UTelAdSEAccept config;

var string sNickname;
var string sUserhost;

event Accepted()
{
  if (TitanIRCd(Parent).IRCUsers.length == 0) CreatePlayerList(); // may wanna fix this
  super.Accepted();
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
        sNickname = getNickName(fixName(sUsername), Spectator);
        sUserhost = input[1]$"@"$Parent.IPAddrToIp(RemoteAddr); 
        AddUserPlayerList(sNickname, sUserhost, Spectator);        

        if (iVerbose > 0) Log("[~] TitanIRCd login succesfull from: "$IpAddrToString(RemoteAddr), 'UTelAdSE');
        gotostate('logged_in'); 
        IRCSend(":Welcome to TitanIRCd"@sNickname, 001);
        IRCSend(":Your host is "$Parent.sIP$":"$string(parent.listenport)$", running TitanIRCd version"@TitanIRCd(parent).IRCVERSION, 002);
        IRCSend(":This server was created on FIXME", 003); //FIXME: create date
        IRCSend("UTelAdSE/"$parent.VERSION$" TitanIRCd/"$TitanIRCd(parent).IRCVERSION$"", 004); //FIXME: version
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
          //SendLine("");
          //SendLine(bold(parent.VersionNotification));
        }
        Login();
        SendLine(":"$sUsername$" NICK "$sNickname); // force nick change
        SendLine(":"$sNickname$" MODE "$sNickname$" :+i");
        ircJoin(TitanIRCd(Parent).sChatChannel);
        Spectator.bMsgEnable = true;
        //ircJoin("&"$sUsername);
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
  SendLine(tmp);
}

function SendLine(string line)
{
  log("Output:"@line);
  super.SendLine(line);
}

function procInput(string Text)
{
  local string prefix;
  local array<string> input;
  log("Input:"@Text);

  if (class'wString'.static.split2(Text, " ", input) < 1) return;
  if (Left(input[0], 1) == ":") 
  {
    // is prefixed
    prefix = class'wArray'.static.ShiftS(input);
  }
  switch (caps(class'wArray'.static.ShiftS(input)))
  {
    case "PRIVMSG": ircPRIVMSG(input, prefix); break;
    case "PING": SendLine("PONG "$input[0]); break;
  }
}

function ircTopic(string channel)
{
  if (channel == ("&"$sUsername))
  {
    IRCSend(channel$" :Enter here your admin commands", 332); // FIXME: topic
    IRCSend(channel$" "$Parent.sIP$" "$unixTimeStamp(), 333); // FIXME: set by
  }
  else {
    IRCSend(channel$" :chat channel - talk to players here", 332); // FIXME: topic
    IRCSend(channel$" "$Parent.sIP$" "$unixTimeStamp(), 333); // FIXME: set by
  }
}

function ircNames(string channel)
{
  local string names;
  local int i;

  if (channel == ("&"$sUsername)) return; // private channel

  for (i = 0; i < TitanIRCd(Parent).IRCUsers.length; i++)
  {
  	names = names$TitanIRCd(Parent).IRCUsers[i].Flag$TitanIRCd(Parent).IRCUsers[i].Nickname$" "; 
  }
  IRCSend("@"@channel$" :"$names, 353); // WTF is @ ??
  IRCSend(channel$" :End of /NAMES list.", 366);
}

function ircJoin(string channel)
{
  SendLine(":"$sNickname$"!"$getPlayerHost(Spectator)@"JOIN :"$channel);
  ircTopic(channel); 
  ircNames(channel); 
  if (Spectator.PlayerReplicationInfo.bAdmin) SendLine(":"$Parent.sIP@"MODE"@channel@":+o"@sNickname);
    else SendLine(":"$Parent.sIP@"MODE"@channel@":+v"@sNickname);
}

function ircPRIVMSG(array<string> input, string prefix)
{
  if (class'wArray'.static.ShiftS(input) == TitanIRCd(Parent).sChatChannel)
  {
    if (input.length == 0) return;
    if (Left(input[0], 1) == ":") input[0] = Mid(input[0], 1); // remove leading :
    Level.Game.Broadcast(Spectator, class'wArray'.static.join(input, " "), 'Say');
    return;
  }
  else {
    // execute commands
  }
}

////////////////////////

function string unixTimeStamp()
{
  return "0";
}

function string getPlayerHost(PlayerController P)
{
  local string host;
  if (P == Spectator) return sUserhost; // is us
  host = P.GetPlayerNetworkAddress();
  Left(host, InStr(host, ":"));
  if (host == "") host = "local";
  return Mid(P, InStr(P, ".")+1)$"@"$host;
}

function string fixName(string username)
{
  local array<string> ichars, vchars;
  ichars[0] = "@";
  vchars[0] = "_";
  ichars[1] = " ";
  vchars[1] = "_";
  ichars[2] = "+";
  vchars[2] = "_";
  return class'wString'.static.StrReplace(username, ichars, vchars);
}

function CreatePlayerList()
{
  local int i;
  local PlayerController P;
  if (iVerbose > 1) Log("[D] Creating Player List", 'UTelAdSE');
  TitanIRCd(Parent).IRCUsers.length = 0;
  foreach DynamicActors(class'PlayerController', P)
  {
    i = TitanIRCd(Parent).IRCUsers.length;
    TitanIRCd(Parent).IRCUsers.length = i+1;
    TitanIRCd(Parent).IRCUsers[i].nickname = getNickName(fixName(P.PlayerReplicationInfo.PlayerName), P);
    TitanIRCd(Parent).IRCUsers[i].hostname = getPlayerHost(P);
    TitanIRCd(Parent).IRCUsers[i].PC = P;
    if (!P.PlayerReplicationInfo.bBot)
    {
      if (P.PlayerReplicationInfo.bAdmin) TitanIRCd(Parent).IRCUsers[i].Flag = "@";
        else TitanIRCd(Parent).IRCUsers[i].Flag = "+";
    }
  }
}

function int AddUserPlayerList(string nickname, string host, PlayerController P, optional bool invalid)
{
  local int i;
  if (iVerbose > 1) Log("[D] Adding Player to Player List", 'UTelAdSE');
  i = TitanIRCd(Parent).IRCUsers.length;
  TitanIRCd(Parent).IRCUsers.length = i+1;
  if (invalid)
  {
    nickname = getNickName(fixName(P.PlayerReplicationInfo.PlayerName), P);
    host = getPlayerHost(P);
  }
  TitanIRCd(Parent).IRCUsers[i].nickname = nickname;
  TitanIRCd(Parent).IRCUsers[i].hostname = host;
  TitanIRCd(Parent).IRCUsers[i].PC = P;
  if (!P.PlayerReplicationInfo.bBot)
  {
    if (P.PlayerReplicationInfo.bAdmin) TitanIRCd(Parent).IRCUsers[i].Flag = "@";
      else TitanIRCd(Parent).IRCUsers[i].Flag = "+";
  }
  return i;
}

function string getNickName(string base, PlayerController P)
{
  local int i, cnt;
  local string result;
  result = base;
  for (i = 0; i < TitanIRCd(Parent).IRCUsers.length; i++)
  {
    if (TitanIRCd(Parent).IRCUsers[i].PC != P)
    {
      if (TitanIRCd(Parent).IRCUsers[i].Nickname == result)
      {
        result = base$string(++cnt);
        i = 0;
      }
    }
  }
  return result;
}

function printMOTD()
{
  IRCSend("- "$Parent.sIP@"Message of the Day", 375);
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
  SpectatorClass=class'TitanIRCdSpectator'
}