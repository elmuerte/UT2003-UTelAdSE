///////////////////////////////////////////////////////////////////////////////
// filename:    UTelAdSEHelper.uc
// version:     101
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     Template for creating helper classes for UTelAdSE
///////////////////////////////////////////////////////////////////////////////

class UTelAdSEHelper extends Object within UTelAdSE;

const PREFIX_BUILTIN = "/";

var localized string msg_noprivileges;
var localized string msg_unknownsubcommand;
var localized string msg_usage;

// colors to use with the Colorise function
enum ETerm_color
{
  clBlack, clRed, clGreen, clYellow, clBlue, clMegenta, clCyan, clWhite
};

/*****************************************************************
  Called methods, the following methods will be called by UTelAdSE 
  *****************************************************************/

// the Init function, will be called when this class is loaded
// return false when the loading failes
function bool Init()
{
  return true;
}

// function:  will be called to execute a builtin command
// output:    return true if handeld
// input:     command = the command entered (case sensitive)
//            args = the arguments given with the command, if any
//            output variable: hideprompt != 0 -> don't show prompt
//            connection = the connection calling this function
function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEAccept connection)
{
  return false;
}

// function:  will be called to handle a shortkey
// output:    return true if handeld
// input:     key = ASCII value of the short-key entered
//            output variable: hideprompt != 0 -> don't show prompt
//            connection = the connection calling this function
function bool ExecShortkey(int key, out int hideprompt, UTelAdSEAccept connection)
{
  return false;
}

// function:  complete the current command
// output:    return true if handeld
// input:     mask = the current command
//            options = the current completed items
function bool TabComplete(array<string> commandline, out SortedStringArray options)
{
  return false;
}

// function:  Custom Input handler
// input:     Text = received input
//            connection = the connection to handle
function HandleInput(string Text, UTelAdSEAccept connection)
{
}

// function:  Do stuff when a client logs in
function OnLogin(UTelAdSEAccept connection)
{
}

// function:  Do stuff when a client logs out
// output:    set canlogout to a non zero value when the user can't logout
//            messages is the messages to be displayed on logout
function OnLogout(UTelAdSEAccept connection, out int canlogout, out array<string> messages)
{
}

/*************************************************************
  General perpose functions, you don't have to overwrite these 
  *************************************************************/

// function: same as ShiftArray but with a string as input
function string NextDelim(out string line, string delim)
{
  return class'wString'.static.StrShift(line, delim);
}

// function: the usual shift on a array of strings
function string ShiftArray(out array< string > ar)
{
  return class'wArray'.static.ShiftS(ar);
}

// function: join array elements to a string
function string JoinArray(array< string > ar, string delim)
{
  return class'wArray'.static.Join(ar, delim);
}

// funtion: add an items to a SortedStringArray
function AddArray(out SortedStringArray ar, string newitem)
{
  ar.Add(newitem, newitem, true);
}

// funtion: checks if a user has certain privileges
function bool CanPerform(playercontroller user, string privs)
{
  return Level.Game.AccessControl.CanPerform(user, privs);
}

// funtion: checks if a string is a numeric representation
function bool IsNumeric(string Param, optional bool bPositiveOnly)
{
  if (param == "") return false;
  return class'wMath'.static.IsInt(param, bPositiveOnly);
}

// function: compare a string, with a mask using wildcards
// Wildcards: * = X chars; ? = 1 char
// Wildcards can appear anywhere in the mask
function bool MaskedCompare(string target, string Mask)
{
  return class'wString'.static.MaskedCompare(target, Mask, false);
}

// same as ReplaceText bu then returns the new string
function string strReplace(coerce string source, coerce string change, coerce string with)
{
  ReplaceText(source, change, with);
  return source;
}

//-----------------------------------------------------------------------------
// Make the text bold
//-----------------------------------------------------------------------------
function static string Bold(string text)
{
  return Chr(27)$"[1m"$text$Chr(27)$"[0m";
}

//-----------------------------------------------------------------------------
// Make the text blink
//-----------------------------------------------------------------------------
function static string Blink(string text)
{
  return Chr(27)$"[5m"$text$Chr(27)$"[0m";
}

//-----------------------------------------------------------------------------
// Make the text reverse video
//-----------------------------------------------------------------------------
function static string Reverse(string text)
{
  return Chr(27)$"[7m"$text$Chr(27)$"[0m";
}

//-----------------------------------------------------------------------------
// Set the for and background color
//-----------------------------------------------------------------------------
function static string Colorise(string text, ETerm_color color, optional ETerm_color bgcolor)
{
  return Chr(27)$"["$string(int(color)+30)$";"$string(int(bgcolor)+40)$"m"$text$Chr(27)$"[0m";
}

//-----------------------------------------------------------------------------
// These need to be merged to wUtils
//-----------------------------------------------------------------------------

function static string AlignLeft(coerce string line, int length, optional string padchar)
{
  local int i;
  if (padchar == "") padchar = " ";
  i = length-Len(line);
  while (i > 0)
  {
    line = line$padchar;
    i--;
  }
  if (i < 0) line = Left(line, length);
  return line;
}

function static string AlignRight(coerce string line, int length, optional string padchar)
{
  local int i;
  if (padchar == "") padchar = " ";
  i = length-Len(line);
  while (i > 0)
  {
    line = padchar$line;
    i--;
  }
  if (i < 0) line = Right(line, length);
  return line;
}

function static string AlignCenter(coerce string line, int length, optional string padchar)
{
  local int i, j;
  if (padchar == "") padchar = " ";
  i = Len(line)/2;
  j = Len(line)-i;
  return AlignRight(Left(line, i), length-(length/2), padchar)$AlignLeft(Right(line, j), length/2, padchar);
}

defaultproperties
{
  msg_noprivileges="You do not have enough privileges."
  msg_unknownsubcommand="Unknown sub-command"
  msg_usage="Usage:"
}