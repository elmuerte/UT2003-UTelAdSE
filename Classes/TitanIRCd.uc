///////////////////////////////////////////////////////////////////////////////
// filename:    TitanIRCd.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     IRC server running on the UTelAdSE system
///////////////////////////////////////////////////////////////////////////////

class TitanIRCd extends UTelAdSE config;

const IRCVERSION = "100";

static function FillPlayInfo(PlayInfo PI)
{
  PI.AddSetting("TitanIRCd", "ListenPort", "Listen Port", 255, 1, "Text", "5;1:65535");
  PI.AddSetting("TitanIRCd", "MaxConnections", "Maximum number of connections", 255, 2, "Text", "3;0:255");
  PI.AddClass(class'TitanIRCdConnection');
  class'TitanIRCdConnection'.static.FillPlayInfo(PI);
	PI.PopClass();
}

defaultproperties
{
  AppName="TitanIRCd"
  ListenPort=7775
  AcceptClass=Class'UTelAdSE.TitanIRCdConnection'
}