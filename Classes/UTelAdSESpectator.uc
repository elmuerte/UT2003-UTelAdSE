///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSESpectator.uc
// version:     101
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     The spectator that received messages
///////////////////////////////////////////////////////////////////////////////

class UTelAdSESpectator extends MessagingSpectator;

var UTelAdSEAccept Server;
var bool bMsgEnable;

var localized string msg_shutdownwarning;

event Destroyed()
{
	Server.Spectator = None;
	Super.Destroyed();
}

function String FormatMessage(PlayerReplicationInfo PRI, String Text, name Type)
{
	local String Message;
	
	// format Say and TeamSay messages
	if (PRI != None) {
		if (Type == 'Say' && PRI == PlayerReplicationInfo)
			Message = Text;
		else if (Type == 'Say')
			Message = PRI.PlayerName$": "$Text;
		else if (Type == 'TeamSay')
			Message = "["$PRI.PlayerName$"]: "$Text;
		else
			Message = "("$Type$") "$Text;
	}
	else Message = Text;
		
	return Message;
}

event ClientMessage( coerce string S, optional Name Type )
{
  if (bMsgEnable)
  {
    Server.SendLine(FormatMessage(None, S, Type));
  }
}

function TeamMessage( PlayerReplicationInfo PRI, coerce string S, name Type)
{
	if (bMsgEnable)
  {
    Server.SendLine(FormatMessage(PRI, S, Type));
  }
}

function ClientVoiceMessage(PlayerReplicationInfo Sender, PlayerReplicationInfo Recipient, name messagetype, byte messageID)
{
	// do nothing?
}

function ReceiveLocalizedMessage( class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject )
{
  if (bMsgEnable)
  {
    if (class<GameMessage>(Message) != none)
    {
      Server.SendLine(Message.Static.GetString(Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject));
    }
  }
}

function ClientGameEnded() {}

function GameHasEnded() {}

event PreClientTravel()
{
  Server.SendLine("");
  Server.SendLine("        "$msg_shutdownwarning);
  Server.SendLine("");
}

defaultproperties
{
  msg_shutdownwarning="! Game has ended, connection will be closed shortly !"
}