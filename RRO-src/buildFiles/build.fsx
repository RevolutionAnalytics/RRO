#r "./packages/FAKE.4.0.3/tools/FakeLib.dll"
#r "./RevoUtils/bin/Release/RevoUtils.dll"

open Fake
open RevoUtils

let (+/) path1 path2 = System.IO.Path.Combine(path1, path2)

let SCRIPT_DIR = __SOURCE_DIRECTORY__
let RRO_DIR = System.IO.Directory.GetParent(SCRIPT_DIR).ToString()
let BASE_DIR = System.IO.Directory.GetParent(RRO_DIR).ToString()
let WORKSPACE = BASE_DIR +/ "workspace"

let R_VERSION = "3.2.1"
let RRO_VERSION = R_VERSION + "-" + R_VERSION


let platform = RevoUtils.Platform.GetPlatform()
let flavor = RevoUtils.Platform.GetPlatformFlavor()
let version = RevoUtils.Platform.GetReleaseVersion()

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

    let mutable rpmName = ""
    if (flavor = RevoUtils.Platform.PlatformFlavor.CentOS) then
        rpmName <- "RRO-" + RRO_VERSION + "-1.el" + version.Major.ToString() + ".x86_64.rpm"

    let specDirs = ["BUILD"; "RPMS"; "SOURCES"; "BUILDROOT"; "SRPMS"; "SPECS"]
    let customFiles = [ BASE_DIR +/ "COPYING"; BASE_DIR +/ "README.txt"; RRO_DIR +/ "files/common/Rprofile.site" ]
    
    FileUtils.mkdir(WORKSPACE)

    for dir in specDirs do
        FileUtils.mkdir(homeDir +/ "rpmbuild" +/ dir)
    for fileLoc in customFiles do
        ignore(FileUtils.cp fileLoc (homeDir +/ "rpmbuild/"))
    System.IO.File.WriteAllText((realHomeDir +/ ".rpmmacros"), ("%_topdir " + homeDir + "/rpmbuild"))
    FileUtils.cp_r (BASE_DIR +/ "R-src") (WORKSPACE +/ "RRO-" + RRO_VERSION)
    ignore(Shell.Exec("tar", "czf RRO-" + RRO_VERSION + ".tar.gz RRO-" + RRO_VERSION, WORKSPACE))
    FileUtils.cp (WORKSPACE +/ "RRO-" + RRO_VERSION + ".tar.gz") (homeDir +/ "rpmbuild/SOURCES/")
    FileUtils.cp (RRO_DIR +/ "files/linux/spec" +/ "R_" + flavor.ToString() + ".spec") (homeDir +/ "rpmbuild/SPECS/R.spec")
    ignore(Shell.Exec("rpmbuild", "-ba SPECS/R.spec", homeDir +/ "rpmbuild"))
    FileUtils.cp (homeDir +/ "rpmbuild/SOURCES/RPMS/x86_64" +/ rpmName) (homeDir)
    trace ("Copied " + rpmName + " to " + homeDir)
)

Target "Build_Windows" (fun _ ->
    trace "Entered Windows Logic"

    FileUtils.mkdir(WORKSPACE)
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