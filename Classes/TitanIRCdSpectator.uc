///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCdSpecator.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The spectator that received messages
///////////////////////////////////////////////////////////////////////////////

class TitanIRCdSpectator extends UTelAdSESpectator;

var TitanIRCdConnection IRCClient;

event Destroyed()
{
	Server.Spectator = None;
	Super.Destroyed();
}

function string getPlayerHostByPRI(PlayerReplicationInfo PRI)
{
  local int i;
  local PlayerController P;

  for (i = 0; i < IRCClient.IRCd.IRCUsers.length; i++)
  {
  	if (IRCClient.IRCd.IRCUsers[i].PC.PlayerReplicationInfo == PRI)
    {
      return IRCClient.IRCd.IRCUsers[i].Nickname$"!"$IRCClient.IRCd.IRCUsers[i].Hostname;
    }
  }
  foreach DynamicActors(class'PlayerController', P)
  {
    if (P.PlayerReplicationInfo == PRI) break;
  }
  if (P == none) return "none!none@none";
  i = IRCClient.IRCd.AddUserPlayerList("", "", P, true);
  return IRCClient.IRCd.IRCUsers[i].Nickname$"!"$IRCClient.IRCd.IRCUsers[i].Hostname;
}

function PlayerController getPlayerByPRI(PlayerReplicationInfo PRI)
{
  local int i;
  local PlayerController P;

  foreach DynamicActors(class'PlayerController', P)
  {
    if (P.PlayerReplicationInfo == PRI) return P;
  }
  return none;
}

function String FormatMessage(PlayerReplicationInfo PRI, String Text, name Type)
{
  if (PRI == none) return ":"$IRCClient.IRCd.sIP@"NOTICE"@IRCClient.IRCd.sChatChannel@":"$Text;
	return ":"$getPlayerHostByPRI(PRI)@"PRIVMSG"@IRCClient.IRCd.sChatChannel@":"$Text;
}

event ClientMessage( coerce string S, optional Name Type )
{
  // do nothing
}

function TeamMessage( PlayerReplicationInfo PRI, coerce string S, name Type)
{
	if (bMsgEnable)
  {
    if (PRI == PlayerReplicationInfo) return;
    IRCClient.SendRaw(FormatMessage(PRI, S, Type));
  }
}

event PreClientTravel()
{
  IRCClient.SendLine(msg_shutdownwarning); // FIXME: notice
}

function ReceiveLocalizedMessage( class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject )
{
  if (bMsgEnable)
  {
    if (class<GameMessage>(Message) != none)
    {
      switch (switch)
      {
        case 1: // new player joined
                if (RelatedPRI_1 != none) getPlayerHostByPRI(RelatedPRI_1);
                break;
        case 2: // name change
                log("name change");
                if (RelatedPRI_1 != none) IRCClient.SendRaw(":"$RelatedPRI_1.OldName$" NICK "$RelatedPRI_1.PlayerName);
                break;
        case 4: // left the server
                if (RelatedPRI_1 != none) IRCClient.IRCd.RemoveUserPlayerList(getPlayerByPRI(RelatedPRI_1), "Left the server");
                break;
      }
    }
  }
}
