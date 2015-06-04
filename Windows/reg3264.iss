[Icons]
Name: "{group}\RRO Rgui @RVER@ 64-bit"; Filename: "{app}\bin\x64\Rgui.exe"; IconFilename: "{app}\etc\REV_14419_Clark_2C.ico"; WorkingDir: "{userdocs}"; Parameters: {code:CmdParms}; Check: isComponentSelected('x64') and Is64BitInstallMode

Name: "{commondesktop}\RRO Rgui @RVER@ 64-bit"; Filename: "{app}\bin\x64\Rgui.exe"; MinVersion: 0,5.0; IconFilename: "{app}\etc\REV_14419_Clark_2C.ico"; Tasks: desktopicon; WorkingDir: "{userdocs}"; Parameters: {code:CmdParms}; Check: isComponentSelected('x64') and Is64BitInstallMode

Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\RRO Rgui @RVER@ 64-bit"; Filename: "{app}\bin\x64\Rgui.exe"; IconFilename: "{app}\etc\REV_14419_Clark_2C.ico"; Tasks: quicklaunchicon; WorkingDir: "{userdocs}"; Parameters: {code:CmdParms}; Check: isComponentSelected('x64') and Is64BitInstallMode 

[Registry] 
Root: HKLM; Subkey: "Software\Revolution"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletevalue; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletevalue; ValueType: string; ValueName: "Current Version"; ValueData: "@RVER@"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R\@RVER@"; Flags: uninsdeletekey; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R\@RVER@"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode

Root: HKLM; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletevalue; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletevalue; ValueType: string; ValueName: "Current Version"; ValueData: "@RVER@"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKLM; Subkey: "Software\Revolution\RRO\R64\@RVER@"; Flags: uninsdeletekey; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode 
Root: HKLM; Subkey: "Software\Revolution\RRO\R64\@RVER@"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode


Root: HKCU; Subkey: "Software\Revolution"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletevalue; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO\R"; Flags: uninsdeletevalue; ValueType: string; ValueName: "Current Version"; ValueData: "@RVER@"; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO\R\@RVER@"; Flags: uninsdeletekey; Tasks: recordversion; Check: NonAdmin
Root: HKCU; Subkey: "Software\Revolution\RRO\R\@RVER@"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: NonAdmin



Root: HKCU; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletekeyifempty; Tasks: recordversion; Check: NonAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKCU; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletevalue; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: NonAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKCU; Subkey: "Software\Revolution\RRO\R64"; Flags: uninsdeletevalue; ValueType: string; ValueName: "Current Version"; ValueData: "@RVER@"; Tasks: recordversion; Check: NonAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKCU; Subkey: "Software\Revolution\RRO\R64\@RVER@"; Flags: uninsdeletekey; Tasks: recordversion; Check: NonAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKCU; Subkey: "Software\Revolution\RRO\R64\@RVER@"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Tasks: recordversion; Check: NonAdmin and isComponentSelected('x64') and Is64BitInstallMode

Root: HKCR; Subkey: ".RData"; ValueType: string; ValueName: ""; ValueData: "RWorkspace"; Flags: uninsdeletevalue; Tasks: associate; Check: IsAdmin
Root: HKCR; Subkey: "RWorkspace"; ValueType: string; ValueName: ""; ValueData: "R Workspace"; Flags: uninsdeletekey; Tasks: associate; Check: IsAdmin
Root: HKCR; Subkey: "RWorkspace\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bin\x64\RGui.exe,0"; Tasks: associate; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode
Root: HKCR; Subkey: "RWorkspace\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bin\x64\RGui.exe"" ""%1"""; Tasks: associate; Check: IsAdmin and isComponentSelected('x64') and Is64BitInstallMode

