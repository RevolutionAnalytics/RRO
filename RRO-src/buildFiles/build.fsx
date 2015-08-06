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
    
    let mutable homeDir = environVar "HOME"
    if homeDir = "" then
        homeDir <- "/tmp"

    let specDirs = ["BUILD"; "RPMS"; "SOURCES"; "BUILDROOT"; "SRPMS"]
    
    FileUtils.mkdir(WORKSPACE)
    ignore(Shell.Exec("echo", "'%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros", WORKSPACE))

    for dir in specDirs do
        FileUtils.mkdir(homeDir +/ "rpmbuild" +/ dir)

    FileUtils.cp_r (BASE_DIR +/ "R-src") (WORKSPACE +/ "RRO-" + RRO_VERSION)

    ignore(Shell.Exec("tar", "czf RRO-" + RRO_VERSION + ".tar.gz RRO-" + RRO_VERSION, WORKSPACE))
    FileUtils.cp (WORKSPACE +/ "RRO-" + RRO_VERSION + ".tar.gz") (homeDir +/ "rpmbuild/SOURCES/")
    FileUtils.cp (RRO_DIR +/ "files/linux/spec" +/ "R_" + flavor.ToString() + ".spec") (homeDir +/ "rpmbuild/SOURCES")
    ()
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