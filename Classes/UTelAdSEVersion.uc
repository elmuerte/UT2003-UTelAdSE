///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEVersion.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     checks for a new version of UTelAdSE, disable by setting
//              checkversion=false in [UTelAdSE] (main config)
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEVersion extends TCPLink config(UTelAdSEVersion);

var config int iLastChecked;
var config string sLatestVersion;
var config string sDownloadURL;

var string sHost;
var string sRequest;
var int iPort;

var private string buffer;
var UTelAdSE UTelAdSE;

function CheckVersion()
{
  // check once a week
  if (getTimeStamp() > (iLastChecked+7))
  {
    resolve(sHost);
  }
  else {
    setNotify();
    destroy(); // clean up
  }
}

event ResolveFailed()
{
  // Error, resolve failed
  setNotify();
  destroy(); // clean up
}

event Resolved( IpAddr Addr )
{
  Addr.Port = iPort;
  BindPort();
  ReceiveMode = RMODE_Event;
  LinkMode = MODE_Line;
  Open(Addr);  
}

event Opened()
{
  buffer = "";
  SendText("GET "$sRequest$" HTTP/1.0");
  SendText("Host: "$sHost);
  SendText("Connection: close");
  SendText("User-agent: UTelAdSE (version "$UTelAdSE.VERSION$"; UT2003 version "$Level.EngineVersion$")");
  SendText("");
}

event ReceivedLine( string Line )
{
  buffer = buffer$Line;
}

event Closed()
{
  local array<string> lines;
  local string header, value;
  local int i;
  
  // split buff into header and doc
  if (divide(buffer, Chr(13)$Chr(10)$Chr(13)$Chr(10), header, buffer) == false) {
    // error no valid data
    return;
  };
  
  // do some header parsing
  class'wString'.static.split2(header, chr(10), lines);  // split on newlines (may still contain carriage returns)
  if (!class'wString'.static.MaskedCompare(lines[0], "HTTP/1.? 200*", false))
  {
    //log("error no valid data");
    return;
  }

  for (i = 0; i < lines.length; i++)
  {
    if (class'wString'.static.MaskedCompare(lines[i], "Content-Type: *", false))
    {
      if (!class'wString'.static.MaskedCompare(lines[i], "content-type: text/plain*", false))
      {
        //log("only text/plain supported:"@lines[i]);
        return;
      }
    }
  }

  // data should be correct
  class'wString'.static.split2(buffer, chr(10), lines);
  for (i = 0; i < lines.length; i++)
  {
    // cut off CR
    if (InStr(lines[i], Chr(13)) > -1)
    {
      lines[i] = Left(lines[i], InStr(lines[i], Chr(13)));
    }
    if (lines[i] != "")
    {
      // add the line to something
      if (divide(lines[i], "=", header, value))
      {
        if (header ~= "version")
        {
          sLatestVersion=value;
        }
        if (header ~= "url")
        {
          sDownloadURL=value;
        }
      }
    }
  }
  iLastChecked=getTimeStamp();
  SaveConfig();
  setNotify();
  destroy(); // clean up
}

function setNotify()
{
  if (sLatestVersion > UTelAdSE.version)
  {
    log("Updated UTelAdSE found", 'UTelAdSE');
    UTelAdSE.VersionNotification = "The latest version of UTelAdSE is:"@sLatestVersion$chr(13)$chr(10)$"Please notify the server admin to install the latest version."$chr(13)$chr(10)$sDownloadURL;
  }
}

function int getTimeStamp()
{
  local string ts;
  ts = string(Level.Year)$Right("0"$string(Level.Month), 2)$Right("0"$string(Level.Day), 2);
  return int(ts);
}

defaultproperties
{
  sHost="www.drunksnipers.com"
  sRequest="/version.php?program=uteladse"
  iPort=80
}