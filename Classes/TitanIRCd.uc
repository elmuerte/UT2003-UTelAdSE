///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCd.uc
// version:     102
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     IRC server running on the UTelAdSE system
///////////////////////////////////////////////////////////////////////////////

class TitanIRCd extends UTelAdSE config exportstructs;

const IRCVERSION = "102";

var string sName;
var string sChatChannel;
var string sCreateTime;
var byte currentID;

struct IRCUser
{
  var string nickname;
  var string username;
  var string hostname;
  var string oldname;
  var PlayerController PC;
};
var array<IRCUser> IRCUsers;
var array<TitanIRCdConnection> IRCCLients;

// keep list of clients

event PreBeginPlay()
{
  if (!bEnabled) return;

  sCreateTime = class'wTime'.static.date("hh:nn:ss dd-mm-yyyy", Level.Year, Level.Month, Level.Day, Level.Hour, Level.Minute, Level.Second);
  Super.PreBeginPlay();
  if (Level.Game.GameReplicationInfo.ShortName != "") sChatChannel = "#"$fixName(Left(Level.Game.GameReplicationInfo.ShortName, 10));
    else sChatChannel = "#"$fixName(Left(Level.Game.GameReplicationInfo.ServerName, 10));
  sName = sIP$"."$Level.Game.GetServerPort();
}

event GainedChild( Actor C )
{
  Super.GainedChild(C);
  TitanIRCdConnection(C).IRCd = self;
  TitanIRCdConnection(C).id = currentID++;
  IRCCLients.Length = IRCCLients.Length+1;
  IRCCLients[IRCCLients.Length-1] = TitanIRCdConnection(C);
}

event LostChild( Actor C )
{
  local int i;

  Super.LostChild(C);
  for (i = 0; i < IRCCLients.Length; i++)
  {
    if (IRCCLients[i] == TitanIRCdConnection(C))
    {
      IRCCLients.Remove(i, 1);
      break;
    }
  }
}

static function FillPlayInfo(PlayInfo PI)
{
  Super.FillPlayInfo(PI);
}


// IRC User management
function CreatePlayerList()
{
  local int i;
  local PlayerController P;

  if (iVerbose > 1) Log("[D] Creating Player List", 'UTelAdSE');
  IRCUsers.length = 0;
  foreach DynamicActors(class'PlayerController', P)
  {
    i = IRCUsers.length;
    IRCUsers.length = i+1;
    IRCUsers[i].nickname = getNickName(fixName(P.PlayerReplicationInfo.PlayerName), P);
    IRCUsers[i].hostname = getPlayerHost(P);
    IRCUsers[i].PC = P;
  }
}

function int AddUserPlayerList(string nickname, string host, string username, PlayerController P, optional bool invalid)
{
  local int i, uid;
  local string uFlags;

  if (P == none) return -1;
  if (iVerbose > 1) Log("[D] Adding Player to Player List", 'UTelAdSE');
  i = IRCUsers.length;
  uid = i;
  IRCUsers.length = i+1;
  if (invalid)
  {
    nickname = getNickName(fixName(P.PlayerReplicationInfo.PlayerName), P);
    host = getPlayerHost(P);
    username = Mid(P, InStr(P, ".")+1);
  }
  IRCUsers[i].nickname = nickname;
  IRCUsers[i].hostname = host;
  IRCUsers[i].username = username;
  IRCUsers[i].PC = P;
  IRCUsers[i].oldname = P.PlayerReplicationInfo.PlayerName;
  for (i = 0; i < IRCClients.length; i++)
  {
    uFlags = GetUserFlags(P);
    IRCClients[i].SendRaw(":"$nickname$"!"$host@"JOIN"@sChatChannel);
    if (uFlags == "+") IRCClients[i].SendRaw(":"$sName@"MODE"@sChatChannel@":+v"@nickname);
    else if (uFlags == "@") IRCClients[i].SendRaw(":"$sName@"MODE"@sChatChannel@":+o"@nickname);
  }
  return uid;
}

function string GetUserFlags(PlayerController P)
{
  if (!P.PlayerReplicationInfo.bBot)
  {
    if (P.PlayerReplicationInfo.bAdmin) return "@";
      else return "+";
  }
  return "";
}

function RemoveUserPlayerList(PlayerController P, optional string msg)
{
  local int i;
  local string tmp;

  if (P == none) return;
  if (iVerbose > 1) Log("[D] Removing Player from Player List", 'UTelAdSE');
  for (i = 0; i < IRCUsers.length; i++)
  {
    if (IRCUsers[i].PC == P)
    {
      tmp = ":"$IRCUsers[i].nickname$"!"$IRCUsers[i].username$"@"$IRCUsers[i].hostname@"QUIT :"$msg;
      IRCUsers.Remove(i, 1);
      break;
    }
  }
  for (i = 0; i < IRCClients.length; i++)
  {
    if (tmp != "") IRCClients[i].SendRaw(tmp);
  }
}

function string getNickName(string base, PlayerController P)
{
  local int i, cnt;
  local string result;

  result = base;
  for (i = 0; i < IRCUsers.length; i++)
  {
    if (IRCUsers[i].PC != P)
    {
      if (IRCUsers[i].Nickname == result)
      {
        result = base$string(++cnt);
        i = 0;
      }
    }
  }
  return result;
}

function string getPlayerHost(PlayerController P)
{
  local string host;

  host = P.GetPlayerNetworkAddress();
  host = Left(host, InStr(host, ":"));
  if (host == "") host = "serverhost";
  return host;
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

defaultproperties
{
  AppName="TitanIRCd"
  ListenPort=7775
  AcceptClass=Class'UTelAdSE.TitanIRCdConnection'
}