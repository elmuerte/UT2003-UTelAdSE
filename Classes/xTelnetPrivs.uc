///////////////////////////////////////////////////////////////////////////////
// filename:    xTelnetPrivs.uc
// version:     101
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     Privilegde flags for Telnet usage
///////////////////////////////////////////////////////////////////////////////

class xTelnetPrivs extends xPrivilegeBase;

defaultproperties
{
     LoadMsg="UTelAdSE Privileges Loaded"
     MainPrivs="T"
     SubPrivs="Tl|Tc|Tb|Th|Ts|Tp|Tg"
     Tags(0)="UTelAdSE"
     Tags(1)="Can login"
     Tags(2)="Use console"
     Tags(3)="Use builtins"
     Tags(4)="Use short-keys"
     Tags(5)="Use chat mode"
     Tags(6)="Player list"
     Tags(7)="Game profiles"
}
