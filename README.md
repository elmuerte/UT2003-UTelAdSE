# UT2003-UTelAdSE

UTelAdSE is a telnet administration server that will allow you do administer your UT2003 server using a telnet client.

UTelAdSE runs from within UT2003, just like the WebAdmin, so you won't open a security hole directly to your system. On an incorrect login UTelAdSE will pause 5 seconds before a retry is possible. This way it will prevent some brute forcing abilities.
Because UTelAdSE runs from within UT2003 you connections will be closed every time UT2003 switches a map.

For a list of all changes check the UTelAdSE Version.txt file
All versions of UTelAdSE work from UT2003 version 2107 and up, some features require a newer version tho.

# Installation
The installation is easy just copy all the *.u and *.int files to your UT2003 System directory (or just unzip this zip file with full paths).

Edit your server configuration and add the following lines:

```
    [Engine.GameEngine]
    ServerActors=UTelAdSE.UTelAdSE
```

If you use the XAdmin.AccessControlIni as Access Controll then you MUST add the following lines to the server config or else you won't be able to use UTelAdSE.

```
    [XAdmin.AccessControlIni]
    PrivClasses=Class'xadmin.xKickPrivs'
    PrivClasses=Class'xadmin.xGamePrivs'
    PrivClasses=Class'xadmin.xUserGroupPrivs'
    PrivClasses=Class'xadmin.xExtraPrivs'
    PrivClasses=Class'UTelAdSE.xTelnetPrivs'
```

Or if this section already exists, just add the line:

```
    PrivClasses=Class'UTelAdSE.xTelnetPrivs'
```

This will add some extra priviledge settings for UTelAdSE, which the user must have in order to use parts of UTelAdSE.

# Configuration
There's not much you need to configure, all configuration settings belong in the server configuration file (UT2003.ini)

```
    [UTelAdSE.UTelAdSE]
    ListenPort=7776
    MaxConnections=10
    iVerbose=1
    TelnetHelperClasses=class'UTelAdSE.DefaultBuiltins'
    TelnetHelperClasses=class'UTelAdSE.UserGroupAdmin'
    TelnetHelperClasses=class'UTelAdSE.ServerBuiltins'

    [UTelAdSE.UTelAdSEConnection]
    bIssueMsg=true
    bStartChat=false
    fLoginTimeout=30.0
    fInvalidLoginDelay=5.0
    bEnablePager=true
    bAnnounceLogin=false
```

### ListenPort
This is the port the telnet admin will listen on for connections
### MaxConnections
the maximum number of connections allowed
### TelnetHelperClasses
These lines define what helper classes should be loaded, this will control what commands are at your disposal.
If you want to enable support of Evolution's Ladder mod you must add the line:
```
TelnetHelperClasses=class'UTelAdSELadder.GameProfiles'
```

### bIssueMsg
Show the issue message before the login prompt, turning this off will make the login more secretive
### bStartChat
Start in `chat` mode, in chat mode all server conversations will be printed in the console, this way you can follow the chatting on your server
### fLoginTimeout
Number of seconds a user has the time to log in
### fInvalidLoginDelay
Number of seconds before a user can try to log in after an incorrect login
### bEnablePage
When this value is true output of commands will be pages when it doesn't fit on the screen
### bAnnounceLogin
Setting this to true will announce an admin loggin in the game

#Usage
Use a normal telnet client to connect to the correct port (the Listen port you configured above). You will be prompted for a username and password, you can use the same username and password as you can with the WebAdmin. You need to have Console privileges (if you use the advanced access controll). After you login on the server you will see the command prompt.

For more information read the 'UTelAdSE MANUAL.html' included with the download. 
