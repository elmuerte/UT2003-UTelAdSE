///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSE.uc
// version:     103
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     connection acceptng class for UTelAdSE
///////////////////////////////////////////////////////////////////////////////
/**
  Connection accepting class for UTelAdSE
*/
class UTelAdSE extends TcpLink config;

const VERSION = "103";

/** UnCodeX comment for a variable, This is the name identifying the application */
var string AppName;

var config bool bEnabled;
var config int ListenPort;
var config int MaxConnections;
var array<UTelAdSEHelper> TelnetHelpers;
var config bool CheckVersion;
var config int iVerbose;

var string VersionNotification;
var int ConnectionCount;

var string sIP;

//-----------------------------------------------------------------------------
// IPAddrToIp(IpAddr addr)
//-----------------------------------------------------------------------------

function string IPAddrToIp(IpAddr addr)
{
  local string tmp;
  tmp = IpAddrToString(addr);
  return Left(tmp, InStr(tmp, ":"));
}

// start Telnet server
event PreBeginPlay()
{
  local UTelAdSEVersion versioncheck;
  local IpAddr addr;

  if (!bEnabled) return;

  GetLocalIP(addr);
  sIP = IPAddrToIp(addr);

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
  LoadTelnetHelpersEx();
  //LoadTelnetHelpers();
  ConnectionCount = 0;
  BindPort( ListenPort );
	Listen();
  if (iVerbose > 0) log("[~] "$AppName$" Listing on: "$ListenPort, 'UTelAdSE');
}

// TODO: resource sharing
function LoadTelnetHelpersEx()
{
  local int i, j;
  local class<UTelAdSEHelper>	HelperClass;
	local string HelperClassName, HelperClassDescription;
  local UTelAdSEHelper TH;

  GetNextIntDesc("UTelAdSE.UTelAdSEHelper",0,HelperClassName,HelperClassDescription);
	while (HelperClassName != "")
	{
    HelperClass = class<UTelAdSEHelper>(DynamicLoadObject(HelperClassName,Class'Class',true));
    if (HelperClass != None)
		{
      // Make sure we dont have duplicate instance of the same class
			for (j=0;j<TelnetHelpers.Length; j++)
			{
				if (TelnetHelpers[j].Class == HelperClass)
				{
					HelperClass = None;
					break;
				}
			}
			
			if (HelperClass != None)
			{
				TH = new HelperClass;
				if (TH != None)
				{
					if (TH.Init())
					{
						TelnetHelpers.Length = TelnetHelpers.Length+1;
						TelnetHelpers[TelnetHelpers.Length - 1] = TH;
					}
					else
					{
						if (iVerbose > 0) Log("TelnetHelper:"@HelperClass@"could not be initialized", 'UTelAdSE');
					}
				}
			}

    }
    GetNextIntDesc("UTelAdSE.UTelAdSEHelper",++i, HelperClassName, HelperClassDescription);
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
  Super.FillPlayInfo(PI);
  PI.AddSetting(Default.AppName, "ListenPort", "Listen Port", 255, 1, "Text", "5;1:65535");
  PI.AddSetting(Default.AppName, "MaxConnections", "Maximum number of connections", 255, 2, "Text", "3;0:255");
  //class'UTelAdSEConnection'.static.FillPlayInfo(PI);
  Default.AcceptClass.static.FillPlayInfo(PI);
}

defaultproperties
{
  bEnabled=true
  AppName="UTelAdSE"
  ListenPort=7776
  MaxConnections=10
  AcceptClass=Class'UTelAdSE.UTelAdSEConnection'
  CheckVersion=true
  iVerbose=1
}