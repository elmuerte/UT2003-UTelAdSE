///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSE.uc
// version:     102
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     connection acceptng class for UTelAdSE
///////////////////////////////////////////////////////////////////////////////

class UTelAdSE extends TcpLink config;

const VERSION = "102";

var string AppName;

var config int ListenPort;
var config int MaxConnections;
var config array< class<UTelAdSEHelper> > TelnetHelperClasses;
var array<UTelAdSEHelper> TelnetHelpers;
var config bool CheckVersion;
var config int iVerbose;

var string VersionNotification;
var int ConnectionCount;

// start Telnet server
event PreBeginPlay()
{
  local UTelAdSEVersion versioncheck;
  if (iVerbose > 0) log("[~] Loading "$AppName$" version "$VERSION, 'UTelAdSE');
  if (iVerbose > 0) log("[~] Michiel 'El Muerte' Hendriks - elmuerte@drunksnipers.com", 'UTelAdSE');
  if (iVerbose > 0) log("[~] The Drunk Snipers - http://www.drunksnipers.com", 'UTelAdSE');
  if (CheckVersion)
  {
    versioncheck = spawn(class'UTelAdSEVersion');
    versioncheck.UTelAdSE = self;
    versioncheck.CheckVersion();
  }
  Super.PreBeginPlay();
  LoadTelnetHelpers();
  ConnectionCount = 0;
  BindPort( ListenPort );
	Listen();
  if (iVerbose > 0) log("[~] "$AppName$" Listing on: "$ListenPort, 'UTelAdSE');
}

// load TelnetHelpers for builtins/short-keys
function LoadTelnetHelpers()
{
  local int i, j, cnt;
  local UTelAdSEHelper TH;
  local class<UTelAdSEHelper> THC;

	cnt = 0;
	for (i=0; i<TelnetHelperClasses.Length; i++)
	{
		THC = TelnetHelperClasses[i];
		// Skip invalid classes;
		if (THC != None)
		{
			// Make sure we dont have duplicate instance of the same class
			for (j=0;j<TelnetHelpers.Length; j++)
			{
				if (TelnetHelpers[j].Class == THC)
				{
					THC = None;
					break;
				}
			}
			
			if (THC != None)
			{
				TH = new THC;
				if (TH != None)
				{
					if (TH.Init())
					{
						TelnetHelpers.Length = TelnetHelpers.Length+1;
						TelnetHelpers[TelnetHelpers.Length - 1] = TH;
					}
					else
					{
						if (iVerbose > 0) Log("TelnetHelper:"@THC@"could not be initialized", 'UTelAdSE');
					}
				}
			}
		}
	}
}

// new connection established
event GainedChild( Actor C )
{
	Super.GainedChild(C);
  UTelAdSEAccept(C).Parent = self;
  UTelAdSEAccept(C).iVerbose = iVerbose;
	ConnectionCount++;

	// if too many connections, close down listen.
	if(MaxConnections > 0 && ConnectionCount > MaxConnections && LinkState == STATE_Listening)
	{
		if (iVerbose > 0) Log("[~] "$AppName$": Too many connections - closing down Listen.");
		Close();
	}
}

// connection closed
event LostChild( Actor C )
{
	Super.LostChild(C);
	ConnectionCount--;

	// if closed due to too many connections, start listening again.
	if(ConnectionCount <= MaxConnections && LinkState != STATE_Listening)
	{
		if (iVerbose > 0) Log("[~] "$AppName$": Listening again - connections have been closed.", 'UTelAdSE');
		Listen();
	}
}

static function FillPlayInfo(PlayInfo PI)
{
  PI.AddSetting("UTelAdSE", "ListenPort", "Listen Port", 255, 1, "Text", "5;1:65535");
  PI.AddSetting("UTelAdSE", "MaxConnections", "Maximum number of connections", 255, 2, "Text", "3;0:255");
  PI.AddClass(class'UTelAdSEConnection');
  class'UTelAdSEConnection'.static.FillPlayInfo(PI);
	PI.PopClass();
}

defaultproperties
{
  AppName="UTelAdSE"
  ListenPort=7776
  MaxConnections=10
  AcceptClass=Class'UTelAdSE.UTelAdSEConnection'
  CheckVersion=true
  iVerbose=1
  TelnetHelperClasses(0)=class'UTelAdSE.DefaultBuiltins'
  TelnetHelperClasses(1)=class'UTelAdSE.UserGroupAdmin'
  TelnetHelperClasses(2)=class'UTelAdSE.ServerBuiltins'
}