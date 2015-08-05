PrivilegesRequired=none
MinVersion=0,5.0
DefaultGroupName=RRO
AllowNoIcons=yes
DisableReadyPage=yes
DisableStartupPrompt=yes
OutputDir=.
WizardSmallImageFile=clarkSmall.bmp
UsePreviousAppDir=no
ChangesAssociations=yes
Compression=lzma/ultra
SolidCompression=yes
AppPublisherURL=http://www.r-project.org
AppSupportURL=http://www.r-project.org
AppUpdatesURL=http://www.r-project.org

[Run]
Filename: "{app}\bin\x64\Rscript"; Parameters: """{app}\etc\checkpoint.R"""; Flags: runhidden

[Languages]
Name: en; MessagesFile: "compiler:Default.isl"
[CustomMessages]
en.regentries=Registry entries:
en.associate=&Associate R with .RData files
en.user=User installation
en.custom=Custom installation
en.adminprivilegesrequired=You should be logged in as an administrator when installing R
en.adminexplanation=Note:  A full R installation requires administrative privileges, and it appears that those are not available.  If you continue with this installation, you will not be able to associate R with .RData files.  Installation must be made to a directory where you have write permission.
en.recordversion=Save version number in registry
en.startupt=Startup options
en.startupq=Do you want to customize the startup options?
en.startupi=Please specify yes or no, then click Next.
en.startup0=Yes (customized startup)
en.startup1=No (accept defaults)
en.MDIt=Display Mode
en.MDIq=Do you prefer the MDI or SDI interface?
en.MDIi=Please specify MDI or SDI, then click Next.
en.MDI0=MDI (one big window)
en.MDI1=SDI (separate windows)
en.HelpStylet=Help Style
en.HelpStyleq=Which form of help display do you prefer?
en.HelpStylei=Please specify plain text or HTML help, then click Next.
en.HelpStyle0=Plain text
en.HelpStyle1=HTML help
en.Internett=Internet Access
en.Internetq=Do you want to use internet2.dll, to make use of Internet Explorer proxy settings?
en.Interneti=Please specify Standard or Internet2, then click Next.
en.Internet0=Standard
en.Internet1=Internet2

[Tasks]
Name: "desktopicon"; Description: {cm:CreateDesktopIcon}; GroupDescription: {cm:AdditionalIcons}; MinVersion: 0,5.0
Name: "quicklaunchicon"; Description: {cm:CreateQuickLaunchIcon}; GroupDescription: {cm:AdditionalIcons}; MinVersion: 0,5.0; Flags: unchecked 
Name: "recordversion"; Description: {cm:recordversion}; GroupDescription: {cm:regentries}; MinVersion: 0,5.0
Name: "associate"; Description: {cm:associate}; GroupDescription: {cm:regentries}; MinVersion: 0,5.0; Check: IsAdmin
