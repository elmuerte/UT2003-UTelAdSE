///////////////////////////////////////////////////////////////////////////////
// filename:    GameProfilesImport.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     Import a game profile
///////////////////////////////////////////////////////////////////////////////

class GameProfilesImport extends TCPLink;

var private string sHostname;
var private int iPort;
var private string sRequest;

var string url;
var string profilename;
var UTelAdSEConnection connection;

function Import()
{
}

function ParseDownloadUrl()
{
}
