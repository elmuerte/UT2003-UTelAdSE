///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSESession.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     Session class for UTelAdSE
///////////////////////////////////////////////////////////////////////////////

class UTelAdSESession extends Object;

struct export KeyValuePair
{
    var string Key;
    var string Value;
};

// contains the unique identifier
var string hash;
// contains the data for this session
var array<KeyValuePair> Data;

// get the value of a var name, return sdefault if not found
// bFound is 1 when the value exists, 0 otherwise
function string getValue(string name, optional string sdefault, optional out int bFound)
{
  local int i;
  bFound = 1;
  for (i = 0; i<data.length; i++)
  {
    if (data[i].key == name) return data[i].value;
  }
  bFound = 0;
  return sdefault;
}

// Set the value of a var name, if bAddIfNotExists it will be added when it doesn't exist
// oldValue will have the previous value
function bool setValue(string name, string value, optional bool bAddIfNotExists, optional out string oldValue)
{
  local int i;
  for (i = 0; i<data.length; i++)
  {
    if (data[i].key == name) 
    {
      oldValue = data[i].value;
      data[i].value = value;
      return true;
    }
  }
  if (bAddIfNotExists)
  {
    data.length = data.length+1;
    data[data.length-1].Key = name;
    data[data.length-1].Value = value;
    return true;
  }
  return false;
}

// Remove a value from the session
function bool removeValue(string name, optional out string oldValue)
{
  local int i;
  for (i = 0; i<data.length; i++)
  {
    if (data[i].key == name) 
    {
      oldValue = data[i].value;
      data.remove(i, 1);
      return true;
    }
  }
  return false;
}
