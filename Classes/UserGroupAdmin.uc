///////////////////////////////////////////////////////////////////////////////
// filename:    UserGroupAdmin.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     Administration of users and groups (XAdmin.AccessControlIni)
///////////////////////////////////////////////////////////////////////////////

class UserGroupAdmin extends UTelAdSEHelper;

const VERSION = "100";

var localized string msg_admin_noadmins;
var localized string msg_admin_usernames;
var localized string msg_admin_noname;
var localized string msg_admin_nogroup;
var localized string msg_admin_invalidname;
var localized string msg_admin_nameexists;
var localized string msg_admin_invalidpass;
var localized string msg_admin_usercreated;
var localized string msg_admin_exception;
var localized string msg_admin_userremoved;
var localized string msg_admin_passupdated;
var localized string msg_admin_addedtogroup;
var localized string msg_admin_removedfromgroup;
var localized string msg_admin_addedtomgroup;
var localized string msg_admin_removedfrommgroup;
var localized string msg_admin_updatedprivs;

var localized string msg_group_nogroups;
var localized string msg_group_groups;
var localized string msg_group_nogroup;
var localized string msg_group_invalidgroup;
var localized string msg_group_groupexists;
var localized string msg_group_negseclevel;
var localized string msg_group_highseclevel;
var localized string msg_group_addgroup;
var localized string msg_group_exception;
var localized string msg_group_removedgroup;
var localized string msg_group_updatedseclevel;
var localized string msg_group_updatedprivs;

function bool Init()
{
  if (Level.Game.AccessControl.IsA('AccessControlIni')) 
  {
    log("[~] Loading User and Group Admin builtins"@VERSION, 'UTelAdSE');
    return true;
  }
  log("[~] Not using XAdmin.AccessControlIni", 'UTelAdSE');
  return false;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEConnection connection)
{
  switch (command)
  {
    case "user" : UserAdmin(args, connection); return true;
    case "group" : GroupAdmin(args, connection); return true;
    case "privileges" : ShowPrivileges(args, connection); return true;
  }
}

// SHOW Privileges

function ShowPrivileges(array< string > args, UTelAdSEConnection connection)
{
  local int i,pi;
  local xPrivilegeBase PM;
  local string mprivs, mpriv, sprivs, spriv, mprivtag, mask, pmask;
  if (!(Level.Game.AccessControl.CanPerform(connection.Spectator, "A") || Level.Game.AccessControl.CanPerform(connection.Spectator, "G")))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  mask = Caps(ShiftArray(args));
  pmask = "";
  if (Left(mask, 1) == "-")
  {
    // filter on privilege token
    pmask = Mid(mask, 1);
    mask = "";
  }

  for (i = 0; i < Level.Game.AccessControl.PrivManagers.Length; i++)
  {
    PM = Level.Game.AccessControl.PrivManagers[i];
    PI=0;
    mprivs=PM.MainPrivs;
    while (mprivs != "")
  	{
      mpriv = NextDelim(mprivs, "|");
      mprivtag = PM.tags[PI];
      if ((InStr(Caps(mprivtag), mask) > -1) && (InStr(Caps(mpriv), pmask) == 0)) connection.SendLine(mpriv$Chr(9)$mprivtag);
      PI++;
      sprivs = PM.SubPrivs;
      while (sprivs != "")
    	{
        spriv = NextDelim(sprivs, "|");
        if (Left(spriv,1) == mpriv)
  			{
          if ((InStr(Caps(PM.tags[PI]), mask) > -1) && (InStr(Caps(spriv), pmask) == 0)) connection.SendLine(spriv$Chr(9)$PM.tags[PI]$" ("$mprivtag$")");
          PI++;
        }
      }
    }
  }
}

// USER ADMIN stuff

function ObjectArray ManagedUsers(UTelAdSEConnection connection)
{
  local ObjectArray Users;
  local int i, j;
  local xAdminGroup Group;
  local xAdminUser User;
  local xAdminGroupList Groups;

	Users = New(None) class'SortedObjectArray';	
	
	if (connection.CurAdmin.bMasterAdmin)
		Groups = Level.Game.AccessControl.Groups;
	else
		Groups = connection.CurAdmin.ManagedGroups;
	
	for (i=0; i<Groups.Count(); i++)
	{
		Group = Groups.Get(i);
		for (j=0; j<Group.Users.Count(); j++)
		{
			User = Group.Users.Get(j);
			if (Users.FindTagId(User.UserName) < 0)
				Users.Add(User, User.UserName);
		}
	}
	return Users;
}

function UserAdmin(array< string > args, UTelAdSEConnection connection)
{
  local string command;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "A"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  command = ShiftArray(args);
  switch (command)
  {
    case "" : connection.SendLine(msg_usage@PREFIX_BUILTIN$"user <list|show|add|remove|set|loggedin>"); return;
    case "list" : UserAdminList(connection); return;
    case "show" : UserAdminShow(args, connection); return;
    case "add" : UserAdminAdd(args, connection); return;
    case "del":
    case "remove" : UserAdminRemove(args, connection); return;
    case "set" : UserAdminSet(args, connection); return;
    case "loggedin": UserShowLoggegin(connection); return;
    default : connection.SendLine(msg_unknownsubcommand);
  }
}

// show all users
function UserAdminList(UTelAdSEConnection connection)
{
  local ObjectArray	Users;
  local xAdminUser User;
  local int i;
  local string tmp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Al"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  Users = ManagedUsers(connection);
  if (Users.Count() == 0)
  {
    connection.SendLine(msg_admin_noadmins);
    return;
  }
  connection.SendLine(msg_admin_usernames);
  for (i = 0; i<Users.Count(); i++)
	{
		User = xAdminUser(Users.GetItem(i));
    if ((i % 5) == 0)
    {
      if (tmp != "") connection.SendLine(tmp);
      tmp = "";
    }
    tmp = tmp$User.Username$Chr(9);
  }
  if (tmp != "") connection.SendLine(tmp);
}

// show user information
function UserAdminShow(array< string > args, UTelAdSEConnection connection)
{
  local ObjectArray	Users;
  local xAdminUser User;
  local int i;
  local string tmp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Al"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 1)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"user show <username>");
    return;
  }
  Users = ManagedUsers(connection);
  for (i = 0; i < Users.Count(); i++)
  {
    User = xAdminUser(Users.GetItem(i));
    if (User.Username == args[0])
    {
      connection.SendLine("| Username:           "$User.UserName);
      connection.SendLine("| Privileges:         "$User.Privileges);
      connection.SendLine("| Merged Privileges:  "$User.MergedPrivs);
      connection.SendLine("| Max Security Level: "$User.MaxSecLevel());
      for (i = 0; i < User.Groups.Count(); i++)
      {
        if (tmp != "") tmp = tmp$", ";
        tmp = tmp$User.Groups.Get(i).GroupName;
      }
      connection.SendLine("| In groups:          "$tmp);
      tmp = "";
      for (i = 0; i < User.ManagedGroups.Count(); i++)
      {
        if (tmp != "") tmp = tmp$", ";
        tmp = tmp$User.ManagedGroups.Get(i).GroupName;
      }
      connection.SendLine("| Can manage groups:  "$tmp);
      return;
    }
  }
  connection.SendLine(msg_admin_noname); 
}

// add a new user
function UserAdminAdd(array< string > args, UTelAdSEConnection connection)
{
  local xAdminUser User;
  local xAdminGroup Group;
  local xAdminGroupList Groups;
  local string newusername, newpassword, newgroup, newprivs;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Aa"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length >= 3)
  {
    newusername = ShiftArray(args);
    newpassword = ShiftArray(args);
    newgroup = ShiftArray(args);
    newprivs = ShiftArray(args);
    if ((newusername != "") && (newpassword != "") && (newgroup != ""))
    {
      if (Connection.CurAdmin.bMasterAdmin)
  			Groups = Level.Game.AccessControl.Groups;
	  	else
		  	Groups = Connection.CurAdmin.ManagedGroups;

      Group = Groups.FindByName(newgroup);
      if (Group == none)
      {
        connection.SendLine(msg_admin_nogroup);
        return;
      }
      if (!Connection.CurAdmin.ValidName(newusername))
      {
				connection.SendLine(msg_admin_invalidname);
        return;
      }
      if (Level.Game.AccessControl.Users.FindByName(newusername) != None)
      {
				connection.SendLine(msg_admin_nameexists);
        return;
      }
      if (!Connection.CurAdmin.ValidPass(newpassword))
      {
				connection.SendLine(msg_admin_invalidpass);
        return;
      }
      User = Level.Game.AccessControl.Users.Create(newusername, newpassword, newprivs);
      if (User != None)
			{
        connection.SendLine(strReplace(msg_admin_usercreated, "%s", newusername));
			  User.AddGroup(Group);
				Level.Game.AccessControl.Users.Add(User);
				Level.Game.AccessControl.SaveAdmins();
			}
			else {
				connection.SendLine(msg_admin_exception);
			}
      return;
    }
  }
  connection.SendLine(msg_usage@PREFIX_BUILTIN$"user add <name> <password> <group> [privileges]");
}

function UserAdminRemove(array< string > args, UTelAdSEConnection connection)
{
  local xAdminUser User;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Aa"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 1)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"user remove <username>");
    return;
  }
  User = Level.Game.AccessControl.Users.FindByName(args[0]);
	if (User != None)
	{
		connection.SendLine(strReplace(msg_admin_userremoved, "%s", User.UserName)); 
		// Remove User
		User.UnlinkGroups();
		Level.Game.AccessControl.Users.Remove(User);
		Level.Game.AccessControl.SaveAdmins();
	}
	else
		connection.SendLine(msg_admin_noname);
}

function UserAdminSet(array< string > args, UTelAdSEConnection connection)
{
  local xAdminUser User;
  local xAdminGroup Group;
  local xAdminGroupList Groups;
  local string temp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ae"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 2)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"user set <username> [-pass <password>] [-addgroup <group>] [-delgroup <group>] [-addmgroup <group>] [-delmgroup <group>] [-privs <privileges>]");
    return;
  }
  User = Level.Game.AccessControl.Users.FindByName(ShiftArray(args));
  if (Connection.CurAdmin.bMasterAdmin)
  	Groups = Level.Game.AccessControl.Groups;
	else
	 	Groups = Connection.CurAdmin.ManagedGroups;
	if (User != None)
	{
    if (Connection.CurAdmin.CanManageUser(User))
    {
      while (args.length > 0)
      {
        switch ShiftArray(args)
        {
          case "-pass":     temp = ShiftArray(args);
                            if (!Connection.CurAdmin.ValidPass(temp))
                            {
                              connection.SendLine(msg_admin_invalidpass);
                            }
                            else {
                              User.Password = temp;
                              connection.SendLine(msg_admin_passupdated);
                            }
                            break;
          case "-addgroup": if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ag"))
                            {
                              connection.SendLine(msg_noprivileges);
                              return;
                            }
                            Group = Groups.FindByName(ShiftArray(args));
                            if (Group == none)
                            {
                              connection.SendLine(msg_admin_nogroup);
                            }
                            else {
                              connection.SendLine(strReplace(msg_admin_addedtogroup, "%s", Group.GroupName));
                              User.AddGroup(Group);
                            }
                            break;
          case "-delgroup": if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ag"))
                            {
                              connection.SendLine(msg_noprivileges);
                              return;
                            }
                            Group = Groups.FindByName(ShiftArray(args));
                            if (Group == none)
                            {
                              connection.SendLine(msg_admin_nogroup);
                            }
                            else {
                              connection.SendLine(strReplace(msg_admin_removedfromgroup, "%s", Group.GroupName));
                              User.RemoveGroup(Group);
                            }
                            break;
          case "-addmgroup": if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Am"))
                            {
                              connection.SendLine(msg_noprivileges);
                              return;
                            }          
                            Group = Groups.FindByName(ShiftArray(args));
                            if (Group == none)
                            {
                              connection.SendLine(msg_admin_nogroup);
                            }
                            else {
                              connection.SendLine(strReplace(msg_admin_addedtomgroup, "%s", Group.GroupName));
                              User.AddManagedGroup(Group);
                            }
                            break;
          case "-delmgroup": if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Am"))
                            {
                              connection.SendLine(msg_noprivileges);
                              return;
                            }          
                            Group = Groups.FindByName(ShiftArray(args));
                            if (Group == none)
                            {
                              connection.SendLine(msg_admin_nogroup);
                            }
                            else {
                              connection.SendLine(strReplace(msg_admin_removedfrommgroup, "%s", Group.GroupName));
                              User.RemoveManagedGroup(Group);
                            }
                            break;
          case "-privs":    User.privileges = ShiftArray(args);
                            User.RedoMergedPrivs();
                            connection.SendLine(msg_admin_updatedprivs);
                            break;
        }
      } 
      Level.Game.AccessControl.SaveAdmins();
    }
    else 
      connection.SendLine(msg_noprivileges);
  }
  else
		connection.SendLine(msg_admin_noname);
}

function UserShowLoggegin(UTelAdSEConnection connection)
{
  local ObjectArray	Users;
  local xAdminUser User;
  local int i, j;
  local string tmp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Al"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  Users = ManagedUsers(connection);
  if (Users.Count() == 0)
  {
    connection.SendLine(msg_admin_noadmins);
    return;
  }
  connection.SendLine(msg_admin_usernames);
  for (i = 0; i<Users.Count(); i++)
	{
		User = xAdminUser(Users.GetItem(i));
    if (AccessControlIni(Level.Game.AccessControl).IsLogged(User))
    {
      if ((j % 5) == 0)
      {
        if (tmp != "") connection.SendLine(tmp);
        tmp = "";
      }
      tmp = tmp$User.Username$Chr(9);
      j++;
    }
  }
  if (tmp != "") connection.SendLine(tmp);
}

// GROUP ADMIN stuff

function GroupAdmin(array< string > args, UTelAdSEConnection connection)
{
  local string command;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "G"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  command = ShiftArray(args);
  switch (command)
  {
    case "" : connection.SendLine(msg_usage@PREFIX_BUILTIN$"group <list|show|add|remove|set>"); return;
    case "list" : GroupAdminList(connection); return;
    case "show" : GroupAdminShow(args, connection); return;
    case "add" : GroupAdminAdd(args, connection); return;
    case "del" :
    case "remove" : GroupAdminRemove(args, connection); return;
    case "set" : GroupAdminSet(args, connection); return;
    default : connection.SendLine(msg_unknownsubcommand);
  }
}

// show all users
function GroupAdminList(UTelAdSEConnection connection)
{
  local xAdminGroup Group;
  local xAdminGroupList Groups;
  local int i;
  local string tmp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Gl"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (Connection.CurAdmin.bMasterAdmin)
		Groups = Level.Game.AccessControl.Groups;
	else
		Groups = Connection.CurAdmin.ManagedGroups;

  if (Groups.Count() == 0)
  {
    connection.SendLine(msg_group_nogroups);
    return;
  }
  connection.SendLine(msg_group_groups);
  for (i = 0; i<Groups.Count(); i++)
	{
		Group = Groups.Get(i);
    if ((i % 5) == 0)
    {
      if (tmp != "") connection.SendLine(tmp);
      tmp = "";
    }
    tmp = tmp$Group.Groupname$Chr(9);
  }
  if (tmp != "") connection.SendLine(tmp);
}

// show group info
function GroupAdminShow(array< string > args, UTelAdSEConnection connection)
{
  local xAdminGroup Group;
  local xAdminGroupList Groups;
  local int i;
  local string tmp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Gl"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 1)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"group show <group name>");
    return;
  }
  if (Connection.CurAdmin.bMasterAdmin)
		Groups = Level.Game.AccessControl.Groups;
	else
		Groups = Connection.CurAdmin.ManagedGroups;

  Group = Groups.FindByName(ShiftArray(args));
  if (Group != none)
  {
    connection.SendLine("| Group nane:          "$Group.GroupName);
    connection.SendLine("| Privileges:          "$Group.Privileges);
    connection.SendLine("| Security Level:      "$Group.GameSecLevel);
    for (i = 0; i < Group.Users.Count(); i++)
    {
      if (tmp != "") tmp = tmp$", ";
      tmp = tmp$Group.Users.Get(i).UserName;
    }
    connection.SendLine("| Users in this group: "$tmp);
    tmp = "";
    for (i = 0; i < Group.Managers.Count(); i++)
    {
      if (tmp != "") tmp = tmp$", ";
      tmp = tmp$Group.Managers.Get(i).UserName;
    }
    connection.SendLine("| Managers:            "$tmp);
    return;
    
  }
  connection.SendLine(msg_group_nogroup); 
}

function GroupAdminAdd(array< string > args, UTelAdSEConnection connection)
{
  local xAdminGroup Group;
  local string newgroup, newprivs;
  local int newsec;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ga"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length >= 1)
  {
    newgroup = ShiftArray(args);
    newsec = Int(ShiftArray(args));
    newprivs = ShiftArray(args);
    if (newgroup != "")
    {
      if (!class'xAdminGroup'.static.ValidName(newgroup))
      {
				connection.SendLine(msg_group_invalidgroup);
        return;
      }
      if (Level.Game.AccessControl.Groups.FindByName(newgroup) != None)
      {
				connection.SendLine(msg_group_groupexists);
        return;
      }
      if (newsec < 0)
      {
				connection.SendLine(msg_group_negseclevel);
        return;
      }
      if (newsec > Connection.CurAdmin.MaxSecLevel())
      {
				connection.SendLine(msg_group_highseclevel);
        return;
      }
      Group = Level.Game.AccessControl.Groups.CreateGroup(newgroup, newprivs, byte(newsec));
      if (Group != None)
			{
        connection.SendLine(strReplace(msg_group_addgroup, "%s", newgroup));
			  Connection.CurAdmin.AddManagedGroup(Group);
				Level.Game.AccessControl.Groups.Add(Group);
				Level.Game.AccessControl.SaveAdmins();
			}
			else {
				connection.SendLine(msg_group_exception);
			}
      return;
    }
  }
  connection.SendLine(msg_usage@PREFIX_BUILTIN$"group add <name> <security level> [privileges]");
}

function GroupAdminRemove(array< string > args, UTelAdSEConnection connection)
{
  local xAdminGroup Group;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ga"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 1)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"group remove <group name>");
    return;
  }
  Group = Level.Game.AccessControl.Groups.FindByName(ShiftArray(args));
	if (Group != None)
	{
		connection.SendLine(strReplace(msg_group_removedgroup, "%s", Group.GroupName));
		// Remove User
		Group.UnlinkUsers();
		Level.Game.AccessControl.Groups.Remove(Group);
		Level.Game.AccessControl.SaveAdmins();
	}
	else
		connection.SendLine(msg_group_nogroup);
}

function GroupAdminSet(array< string > args, UTelAdSEConnection connection)
{
  local xAdminGroup Group;
  local int temp;
  if (!Level.Game.AccessControl.CanPerform(connection.Spectator, "Ge"))
  {
    connection.SendLine(msg_noprivileges);
    return;
  }
  if (args.length < 2)
  {
    connection.SendLine(msg_usage@PREFIX_BUILTIN$"group set <groupname> [-level <security level>] [-privs <privileges>]");
    return;
  }
  Group = Level.Game.AccessControl.Groups.FindByName(ShiftArray(args));
	if (Group != None)
	{
    if (Connection.CurAdmin.CanManageGroup(Group))
    {
      while (args.length > 0)
      {
        switch ShiftArray(args)
        {
          case "-level":    temp = Int(ShiftArray(args));
                            if (temp < 0)
                            {
				                      connection.SendLine(msg_group_negseclevel);
                            }
                            else if (temp > Connection.CurAdmin.MaxSecLevel())
                            {
                      				connection.SendLine(msg_group_highseclevel);
                            }
                            else {
                              Group.GameSecLevel = Byte(temp);
                              connection.SendLine(msg_group_updatedseclevel);
                            }
                            break;
          case "-privs":    Group.SetPrivs(ShiftArray(args));
                            connection.SendLine(msg_group_updatedprivs);
                            break;
        }
      } 
      Level.Game.AccessControl.SaveAdmins();
    }
    else 
      connection.SendLine(msg_noprivileges);
  }
  else
		connection.SendLine(msg_group_nogroup);
}

function bool TabComplete(array<string> commandline, out SortedStringArray options)
{
  if (commandline.length == 1)
  {
    if (InStr("user", commandline[0]) == 0) AddArray(options, "user");
    if (InStr("group", commandline[0]) == 0) AddArray(options, "group");
    if (InStr("privileges", commandline[0]) == 0) AddArray(options, "privileges");
  }
  else if (commandline.length == 2)
  {
    if ((commandline[0] == "user") || (commandline[0] == "group"))
    {
      if (InStr("add", commandline[1]) == 0) AddArray(options, commandline[0]@"add");
      if (InStr("list", commandline[1]) == 0) AddArray(options, commandline[0]@"list");
      if (InStr("show", commandline[1]) == 0) AddArray(options, commandline[0]@"show");
      if (InStr("del", commandline[1]) == 0) AddArray(options, commandline[0]@"del");
      if (InStr("remove", commandline[1]) == 0) AddArray(options, commandline[0]@"remove");
      if (InStr("set", commandline[1]) == 0) AddArray(options, commandline[0]@"set");
    }
    if (commandline[0] == "user")
    {
      if (InStr("loggedin", commandline[1]) == 0) AddArray(options, commandline[0]@"loggedin");
    }
  }
  return true;
}

defaultproperties
{
  msg_admin_noadmins="There are no admins to list"
  msg_admin_usernames="Usernames:"
  msg_admin_noname="No admin found with that name"
  msg_admin_nogroup="No such group"
  msg_admin_invalidname="User name contains invalid characters"
  msg_admin_nameexists="User name already used"
  msg_admin_invalidpass="Password contains invalid characters"
  msg_admin_usercreated="User '%s' has been created."
  msg_admin_exception="Exceptional error creating the new user"
  msg_admin_userremoved="User '%s' was removed"
  msg_admin_passupdated="Password updated"
  msg_admin_addedtogroup="Added user to group group '%s'"
  msg_admin_removedfromgroup="Removed user from group '%s'"
  msg_admin_addedtomgroup="Added user as manager for group '%s'"
  msg_admin_removedfrommgroup="Removed user as manager for group '%s'"
  msg_admin_updatedprivs="Updated user privileges"

  msg_group_nogroups="There are no groups to list"
  msg_group_groups="Groups:"
  msg_group_nogroup="No group found with that name"
  msg_group_invalidgroup="Group name contains invalid characters"
  msg_group_groupexists="Group name already used"
  msg_group_negseclevel="Negative security level is invalid"
  msg_group_highseclevel="You cannot assign a security level higher than yours"
  msg_group_addgroup="Group '%s' has been created."
  msg_group_exception="Exceptional error creating the new group"
  msg_group_removedgroup="Group '%s' was removed"
  msg_group_updatedseclevel="Updated group security level"
  msg_group_updatedprivs="Updated group privileges"
}