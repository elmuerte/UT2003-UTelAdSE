///////////////////////////////////////////////////////////////////////////////
// filename:    UnrealIRCD.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     IRC server running on the UTelAdSE system
///////////////////////////////////////////////////////////////////////////////

class UnrealIRCD extends UTelAdSE config;

const IRCVERSION = "100";

static function FillPlayInfo(PlayInfo PI)
{
  PI.AddSetting("UnrealIRCD", "ListenPort", "Listen Port", 255, 1, "Text", "5;1:65535");
  PI.AddSetting("UnrealIRCD", "MaxConnections", "Maximum number of connections", 255, 2, "Text", "3;0:255");
  PI.AddClass(class'UnrealIRCDConnection');
  class'UnrealIRCDConnection'.static.FillPlayInfo(PI);
	PI.PopClass();
}

defaultproperties
{
  AppName="UnrealIRCD"
  ListenPort=7775
  AcceptClass=Class'UTelAdSE.UnrealIRCDConnection'
}