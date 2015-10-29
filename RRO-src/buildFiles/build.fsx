#r "./packages/FAKE.4.0.3/tools/FakeLib.dll"
#r "./packages/FAKE.4.0.3/tools/Newtonsoft.Json.dll"
#r "./RevoUtils/bin/Release/RevoUtils.dll"

open Fake
open RevoUtils
open Newtonsoft


let (+/) path1 path2 = System.IO.Path.Combine(path1, path2)

let SCRIPT_DIR = __SOURCE_DIRECTORY__
let RRO_DIR = System.IO.Directory.GetParent(SCRIPT_DIR).ToString()
let BASE_DIR = System.IO.Directory.GetParent(RRO_DIR).ToString()
let mutable WINDOWS_FILES_DIR = RRO_DIR +/ "files" +/ "windows"
let mutable COMMON_FILES_DIR = RRO_DIR +/ "files" +/ "common"
let WORKSPACE = BASE_DIR +/ "workspace"

let mutable FLAVOR = "RRO"
let R_VERSION = "3.2.2"
let RRO_VERSION = R_VERSION
let RRC_VERSION = "7.5.0"
let mutable FLAVOR_VERSION = R_VERSION

let CURL_VERSION = "7.45.0"
let CURL_NAME = "curl-" + CURL_VERSION

let mutable BUILD_ID = "dev"
if fileExists (BASE_DIR +/ "BuildID.txt") then
    BUILD_ID <- System.IO.File.ReadAllText(BASE_DIR +/ "BuildID.txt")


let CONNECTOR = environVarOrNone "CONNECTOR"
let mutable BUILD_CONNECTOR = false

match CONNECTOR with
| None -> ( BUILD_CONNECTOR <- false )
| _ -> ( 
            BUILD_CONNECTOR <- true
            WINDOWS_FILES_DIR <- RRO_DIR +/ "files" +/ "windows" +/ "connector"
            COMMON_FILES_DIR <- RRO_DIR +/ "files" +/ "common" +/ "connector"
            FLAVOR <- "Revolution-R-Connector"
            FLAVOR_VERSION <- RRC_VERSION
       )

let platform = RevoUtils.Platform.GetPlatform()
let flavor = RevoUtils.Platform.GetPlatformFlavor()
let version = RevoUtils.Platform.GetReleaseVersion()

let mutable PKG_DIR = ""
if platform = System.PlatformID.Win32NT then
    PKG_DIR <- WORKSPACE +/ "packages"
else
    PKG_DIR <- "/tmp/rro_extra_pkgs"

let BuildIdPackages = ["RevoUtils"; "RevoMods"]

// HELPER FUNCTIONS
//

//VerifyWindowsTools returns a Map with information about needed windows paths
//Can throw exceptions if needed tools aren't present

let VerifyWindowsTools() : Map<string, string> =

    
    let RTOOLS_VERSION = RevoUtils.RTools.GetRToolsVersion()
    let TEX_VERSION = RevoUtils.RTools.GetProgramVersionByName("MiKTeX")
    let INNO_VERSION = RevoUtils.RTools.GetProgramVersionByName("Inno Setup")
    let PERL_VERSION = RevoUtils.RTools.GetProgramVersionByName("Strawberry")

    match RTOOLS_VERSION with
    | null -> ( 
                traceError ("No Rtools found")
                raise (new System.Exception("There was no version of RTools found on this computer."))
                
              )
    | _ -> trace ("Found Rtools version " + RTOOLS_VERSION.ToString())

    let RTOOLS_PATH = RevoUtils.RTools.GetRToolsPath(RTOOLS_VERSION)

    match RTOOLS_PATH with
    | null -> (
                traceError ("No Path found for Rtools")
              )
    | _ -> trace ("Rtools lives at: " + RTOOLS_PATH)

    match TEX_VERSION with
    | null -> ( 
                traceError ("No MiKTeX found")
                raise (new System.Exception("There was no version of MiKTeX found on this computer."))
              )
    | _ -> trace ("Found MiKTeX version " + TEX_VERSION.ToString())

    let TEX_PATH = RevoUtils.RTools.GetProgramPathByNameAndVersion("MiKTeX", TEX_VERSION)
    match TEX_PATH with
    | null -> traceError ("No Path found for MiKTeX")
    | _ -> trace ("MiKTeX lives at: " + TEX_PATH)

    match INNO_VERSION with
    | null -> (
                raise ( new System.Exception("There was no version of InnoSetup found on this computer"))
              )
    | _ -> trace ("Found InnoSetup version " + INNO_VERSION.ToString())

    let INNO_PATH = RevoUtils.RTools.GetProgramPathByNameAndVersion("Inno Setup", INNO_VERSION)
    match INNO_PATH with
    | null -> traceError ("No Path found for InnoSetup")
    | _ -> trace ("Innosetup lives at " + INNO_PATH)

    match PERL_VERSION with
    | null -> ( raise ( new System.Exception("There was no version of Strawberry perl found on this computer" )))
    | _ -> trace ("Strawberry perl version " + PERL_VERSION.ToString())

    let PERL_PATH = RevoUtils.RTools.GetProgramPathByNameAndVersion("Strawberry Perl", PERL_VERSION)
    match PERL_PATH with
    | null -> traceError ("No path found for perl")
    | _ -> trace ("Perl lives at " + PERL_PATH)

    Map.empty.
        Add("Rtools", RTOOLS_PATH).
        Add("MiKTeX", TEX_PATH).
        Add("Inno Setup", INNO_PATH).
        Add("Perl", PERL_PATH)

let executeProcess (exe, cmdline, wd) =
    let psi = new System.Diagnostics.ProcessStartInfo(exe,cmdline) 
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- false
    psi.RedirectStandardError <- false
    psi.CreateNoWindow <- true
    if wd <> null then psi.WorkingDirectory <- wd    
    let p = System.Diagnostics.Process.Start(psi) 
    p.WaitForExit()

Target "Info" (fun _ ->
    trace("The platform is " + platform.ToString())
    trace("The platform flavor is " + flavor.ToString())
    trace("The platform version is " + version.ToString())
    trace("This script is executing in " + SCRIPT_DIR)

    
)

Target "Clean" (fun _ ->
    FileUtils.rm_rf(WORKSPACE)
    
)

Target "Build_Linux" (fun _ ->
    trace "Entered Linux Logic"
    
    let realHomeDir = environVar "HOME"
    let mutable homeDir = environVar "HOME"
    if (homeDir = "") || (homeDir = "/root")  then
        homeDir <- "/tmp"

    let mutable specName = ""
    if(flavor = RevoUtils.Platform.PlatformFlavor.CentOS || flavor = RevoUtils.Platform.PlatformFlavor.Ubuntu) then
        specName <- "R_" + flavor.ToString().ToUpper() + ".spec"
    elif(flavor = RevoUtils.Platform.PlatformFlavor.SLES) then
        specName <- "R_" + flavor.ToString() + version.Major.ToString() + ".spec"
    elif(flavor = RevoUtils.Platform.PlatformFlavor.OpenSUSE) then
        specName <- "R_SUSE.spec"

    let mutable rpmName = ""
    if (flavor = RevoUtils.Platform.PlatformFlavor.CentOS && version.Major = 5) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.CentOS && version.Major = 6) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.el" + version.Major.ToString() + ".x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.CentOS && version.Major = 7) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.el" + version.Major.ToString() + ".centos.x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.SLES) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.Ubuntu) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.OpenSUSE) then
        rpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-1.x86_64.rpm"

    let mutable finalRpmName = ""
    let mutable finalDebName = ""
    if (flavor = RevoUtils.Platform.PlatformFlavor.CentOS) then
        finalRpmName <- FLAVOR + "-" + FLAVOR_VERSION + ".el" + version.Major.ToString() + ".x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.SLES) then
        finalRpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-SLES" + version.Major.ToString() + ".x86_64.rpm"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.Ubuntu) then
        finalDebName <- FLAVOR + "-" + FLAVOR_VERSION + "-Ubuntu-" + version.Major.ToString() + "." + version.Minor.ToString() + ".x86_64.deb"
    elif (flavor = RevoUtils.Platform.PlatformFlavor.OpenSUSE) then
        finalRpmName <- FLAVOR + "-" + FLAVOR_VERSION + "-openSUSE-13.1.x86_64.rpm"

    let specDirs = ["BUILD"; "RPMS"; "SOURCES"; "BUILDROOT"; "SRPMS"; "SPECS"]
    let customFiles = [ BASE_DIR +/ "COPYING"; BASE_DIR +/ "README.txt"; COMMON_FILES_DIR +/ "Rprofile.site" ]

    let tmpDir = WORKSPACE +/ "tmp"
    
    FileUtils.mkdir(WORKSPACE)
    FileUtils.mkdir(PKG_DIR)
    FileUtils.mkdir(tmpDir)

    setProcessEnvironVar "QA_SKIP_BUILD_ROOT" "1"

    let curlURL = "http://curl.askapache.com/download/" + CURL_NAME + ".tar.gz"
    use curlWebClient = new System.Net.WebClient()
    curlWebClient.DownloadFile(curlURL.ToString(), (WORKSPACE +/ "curl.tar.gz"))
    let curlFile = System.IO.FileInfo((WORKSPACE +/ "curl.tar.gz"))
    ArchiveHelper.Tar.GZip.Extract (System.IO.DirectoryInfo(WORKSPACE)) curlFile
    ignore(Shell.Exec("/bin/bash", "configure", WORKSPACE +/ CURL_NAME))
    ignore(Shell.Exec("make", "", WORKSPACE +/ CURL_NAME))

    let path = environVar "PATH"
    setProcessEnvironVar "LDFLAGS" ("-L" + WORKSPACE +/ CURL_NAME +/ "lib/.libs/libcurl.a")
    setProcessEnvironVar "CPPFLAGS" ("-I" + WORKSPACE +/ CURL_NAME +/ "include")

    let mutable packageFile = "packages-linux.json"
    if BUILD_CONNECTOR then
        packageFile <- "packages-linux-connector.json"
    //Stage packages listed in packages.json
    let fileContents = System.IO.File.ReadAllText(SCRIPT_DIR +/ packageFile)
    let jsonObject = Newtonsoft.Json.Linq.JObject.Parse(fileContents)
    let packages = jsonObject.GetValue("packages")
    let mutable extraPackageList = ""

    for package in packages do     
        //Download the package
        use webClient = new System.Net.WebClient()
        let url = package.Value("location")
        webClient.DownloadFile(url.ToString(), (PKG_DIR +/ package.Value("destFileName")))
        extraPackageList <- extraPackageList + " " + package.Value("destFileName")

    for package in BuildIdPackages do
        if fileExists (PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz") then
            FileUtils.cp (PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz") WORKSPACE
            let packageFile = System.IO.FileInfo((WORKSPACE +/ package + "_" + RRC_VERSION + ".tar.gz"))
            ArchiveHelper.Tar.GZip.Extract (System.IO.DirectoryInfo(tmpDir)) packageFile
            RegexReplaceInFileWithEncoding ":::RevoBuildID:::" BUILD_ID (System.Text.ASCIIEncoding()) (tmpDir +/ package +/ "DESCRIPTION")
            ignore(Shell.Exec("tar", "czf " + PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz " + package + "/", tmpDir))

    for dir in specDirs do
        FileUtils.mkdir(homeDir +/ "rpmbuild" +/ dir)
    for fileLoc in customFiles do
        ignore(FileUtils.cp fileLoc (homeDir +/ "rpmbuild/"))
    RegexReplaceInFileWithEncoding ":::BUILDID:::" "\"1\"" (System.Text.ASCIIEncoding()) (homeDir +/ "rpmbuild" +/ "Rprofile.site")
    System.IO.File.WriteAllText((realHomeDir +/ ".rpmmacros"), ("%_topdir " + homeDir + "/rpmbuild"))
    FileUtils.cp_r (BASE_DIR +/ "R-src") (WORKSPACE +/ FLAVOR + "-" + FLAVOR_VERSION)
    ignore(executeProcess("patch", "-p1 -i ../../RRO-src/patches/relocatable_r.patch", WORKSPACE +/ FLAVOR + "-" + FLAVOR_VERSION))
    ignore(Shell.Exec("tar", "czf " + FLAVOR + "-" + FLAVOR_VERSION + ".tar.gz " + FLAVOR + "-" + FLAVOR_VERSION, WORKSPACE))
    FileUtils.cp (WORKSPACE +/ FLAVOR + "-" + FLAVOR_VERSION + ".tar.gz") (homeDir +/ "rpmbuild/SOURCES/")
    FileUtils.cp (RRO_DIR +/ "files/linux/spec" +/ specName) (homeDir +/ "rpmbuild/SPECS/R.spec")

    let replacements = [ (":::EXTRA_PKGS:::", extraPackageList);
                         (":::RPM_NAME:::", FLAVOR); 
                         (":::RPM_VERSION:::", FLAVOR_VERSION);
                         (":::R_VERSION:::", R_VERSION) ]

    for replacement in replacements do
        RegexReplaceInFileWithEncoding (fst replacement) (snd replacement) (System.Text.ASCIIEncoding()) (homeDir +/ "rpmbuild/SPECS/R.spec")
    
    ignore(Shell.Exec("rpmbuild", "-ba SPECS/R.spec", homeDir +/ "rpmbuild"))
    FileUtils.cp (homeDir +/ "rpmbuild/RPMS/x86_64" +/ rpmName) (WORKSPACE)
    trace ("Copied " + rpmName + " to " + WORKSPACE)

    if(flavor = RevoUtils.Platform.PlatformFlavor.Ubuntu) then
        ignore(Shell.Exec("fakeroot", "alien --scripts --to-deb " + WORKSPACE +/ rpmName, BASE_DIR))
        ignore(Shell.Exec("mv", BASE_DIR +/ "rro_" + R_VERSION + "-2_amd64.deb" + " " + BASE_DIR +/ finalDebName))
    else
        ignore(Shell.Exec("mv", WORKSPACE +/ rpmName + " " + WORKSPACE +/ finalRpmName))

    FileUtils.rm_rf(PKG_DIR)
)


Target "Build_Windows" (fun _ ->
    trace "Entered Windows Logic"

    //Verify that our build environment is sane. This section still needs work and tools to be added.
    let tools = VerifyWindowsTools()
    trace ("Rtools found at " + tools.["Rtools"])
    trace ( "MiKTeX found at " + tools.["MiKTeX"])
    trace ( "Inno Setup found at " + tools.["Inno Setup"])
    trace ( "Strawberry Perl found at " + tools.["Perl"])
    let path = environVar "PATH"
    setProcessEnvironVar "PATH" (tools.["Rtools"] +/ "bin;" + tools.["Rtools"] +/ "gcc-4.6.3\\bin;" + tools.["MiKTeX"] +/ "miktex\\bin;" + tools.["Perl"] +/ "perl\\bin;" + tools.["Inno Setup"] + ";" + path)
    trace ("PATH IS " + (environVar "PATH"))
    trace ( "Build Connector set to " + BUILD_CONNECTOR.ToString())
    let tmpDir = WORKSPACE +/ "tmp"
    FileUtils.mkdir(WORKSPACE)
    FileUtils.mkdir(PKG_DIR)
    FileUtils.mkdir(tmpDir)

    let mutable packageFile = "packages-windows.json"
    if BUILD_CONNECTOR then
        packageFile <- "packages-windows-connector.json"
        
    //Stage packages listed in packages.json
    let fileContents = System.IO.File.ReadAllText(SCRIPT_DIR +/ packageFile)
    let jsonObject = Newtonsoft.Json.Linq.JObject.Parse(fileContents)
    let packages = jsonObject.GetValue("packages")
    let mutable extraPackageList = ""

    for package in packages do     
        //Download the package
        use webClient = new System.Net.WebClient()
        let url = package.Value("location")
        webClient.DownloadFile(url.ToString(), (PKG_DIR +/ package.Value("destFileName")))
        System.IO.File.WriteAllText((PKG_DIR +/ package.Value("name") + ".tgz"), package.Value("destFileName"))
        extraPackageList <- extraPackageList + " " + package.Value("name")
    
    for package in BuildIdPackages do
        if fileExists (PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz") then
            FileUtils.cp (PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz") WORKSPACE
            let packageFile = System.IO.FileInfo((WORKSPACE +/ package + "_" + RRC_VERSION + ".tar.gz"))
            ArchiveHelper.Tar.GZip.Extract (System.IO.DirectoryInfo(tmpDir)) packageFile
            RegexReplaceInFileWithEncoding ":::RevoBuildID:::" BUILD_ID (System.Text.ASCIIEncoding()) (tmpDir +/ package +/ "DESCRIPTION")
            ignore(ArchiveHelper.Tar.GZip.CompressDirWithDefaults (System.IO.DirectoryInfo(tmpDir)) (System.IO.FileInfo((PKG_DIR +/ package + "_" + RRC_VERSION + ".tar.gz"))))
            FileUtils.rm_rf tmpDir
            FileUtils.mkdir tmpDir
        

    //Prep directories, copying over custom files
    let rDir = WORKSPACE +/ "R-" + R_VERSION
    let gnuWin32Dir = rDir +/ "src" +/ "gnuwin32"
    let installerDir = gnuWin32Dir +/ "installer"
    let packageDir = rDir +/ "src" +/ "library" +/ "Recommended"

    let etcFiles = [ WINDOWS_FILES_DIR +/ "REV_14419_Clark_2C.ico"; BASE_DIR +/ "README.txt"; BASE_DIR +/ "COPYING" ]
    let installerFiles = [ WINDOWS_FILES_DIR +/ "clarkSmall.bmp"; WINDOWS_FILES_DIR +/ "header1.iss";
                           WINDOWS_FILES_DIR +/ "reg3264.iss"; WINDOWS_FILES_DIR +/ "JRins.R"; COMMON_FILES_DIR +/ "intro.txt"; 
                           WINDOWS_FILES_DIR +/ "Makefile"; ]
   
    
    FileUtils.cp_r (BASE_DIR +/ "R-src") (WORKSPACE +/ "R-" + R_VERSION)
    FileUtils.cp_r ("c:\\R64\\Tcl") (WORKSPACE +/ "R-" + R_VERSION +/ "Tcl")
    FileUtils.cp (COMMON_FILES_DIR +/ "Rprofile.site") (gnuWin32Dir +/ "fixed" +/ "etc")
    FileUtils.cp (COMMON_FILES_DIR +/ "vars.mk") (rDir +/ "share" +/ "make")
    FileUtils.cp (WINDOWS_FILES_DIR +/ "MkRules_64.local") (gnuWin32Dir +/ "MkRules.local")
    FileUtils.cp_r (PKG_DIR +/ ".") (packageDir)
    ReplaceInFiles [ (":::BUILDID:::", "\"1\"") ] [ (gnuWin32Dir +/ "fixed" +/ "etc" +/ "Rprofile.site") ]
    ReplaceInFiles [ (":::EXTRA_PACKAGES:::", extraPackageList) ] [ rDir +/ "share" +/ "make" +/ "vars.mk" ] 

    for file in etcFiles do
        FileUtils.cp file (rDir +/ "etc")
    for file in installerFiles do
        FileUtils.cp file installerDir

    RegexReplaceInFileWithEncoding "INSTALL_OPTS=--pkglock --install-tests --data-compress=xz" "INSTALL_OPTS=--pkglock --install-tests --keep-empty-dirs --data-compress=xz" (System.Text.ASCIIEncoding()) (packageDir +/ "Makefile.win")

    //invoke build
    setProcessEnvironVar "tmpdir" (WORKSPACE +/ "tmp")
    ignore(Shell.Exec("make", "-j8 all", gnuWin32Dir))
    ignore(Shell.Exec("make", "-j8 cairodevices", gnuWin32Dir))
    ignore(Shell.Exec("make", "-j8 recommended", gnuWin32Dir))
    ignore(Shell.Exec("make", "-j8 vignettes", gnuWin32Dir))
    ignore(Shell.Exec("make", "-j8 manuals", gnuWin32Dir))

    //Stage binary packages
    let binaryPackages = jsonObject.GetValue("binary_packages")
    let mutable extraBinaryPackageList = ""
    for package in binaryPackages do
        //Download the package
        use webClient = new System.Net.WebClient()
        let url = package.Value("location")
        webClient.DownloadFile(url.ToString(), (PKG_DIR +/ package.Value("destFileName")))
        let source = Fake.FileSystemHelper.fileInfo (PKG_DIR +/ package.Value("destFileName"))
        let target = Fake.FileSystemHelper.directoryInfo (rDir +/ "library")
        Fake.ArchiveHelper.Zip.Extract target source
        FileUtils.rm_rf ( rDir +/ "library" +/ package.Value("name") +/ "libs" +/ "i386" )
        extraBinaryPackageList <- extraBinaryPackageList + " " + package.Value("name")

    //Remove foreach and iterators
    if directoryExists ( rDir +/ "library" +/ "foreach" ) then
        FileUtils.rm_rf ( rDir +/ "library" +/ "foreach" )
        ReplaceInFiles [ ("foreach ", "") ] [ rDir +/ "share" +/ "make" +/ "vars.mk" ]
    if directoryExists ( rDir +/ "library" +/ "iterators" ) then
        FileUtils.rm_rf ( rDir +/ "library" +/ "iterators" )
        ReplaceInFiles [ ("iterators ", "") ] [ rDir +/ "share" +/ "make" +/ "vars.mk" ]

    if directoryExists ( rDir +/ "library" +/ "RevoIOQ" ) then
        let file = System.IO.File.Create( rDir +/ "library" +/ "RevoIOQ" +/ "unitTests" +/ "R" +/ "windows" +/ "win")
        file.Dispose();

    //Create the installer
    ignore(Shell.Exec("make", "rinstaller EXTRA_PKGS=\'" + extraBinaryPackageList + "\'", gnuWin32Dir))
    ()
)

Target "Default" (fun _ ->
    trace "Default task"
)

"Info"
  ==> "Clean"
  =?> ("Build_Windows", (platform = System.PlatformID.Win32NT))
  =?> ("Build_Linux", (platform = System.PlatformID.Unix) && (flavor <> Platform.PlatformFlavor.UnknownUnix))
  ==> "Default"

Run "Default"
