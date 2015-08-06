#r "./packages/FAKE.4.0.3/tools/FakeLib.dll"
#r "./RevoUtils/bin/Release/RevoUtils.dll"

open Fake
open RevoUtils

let (+/) path1 path2 = System.IO.Path.Combine(path1, path2)

let SCRIPT_DIR = __SOURCE_DIRECTORY__
let RRO_DIR = System.IO.Directory.GetParent(SCRIPT_DIR).ToString()
let BASE_DIR = System.IO.Directory.GetParent(RRO_DIR).ToString()
let WORKSPACE = BASE_DIR +/ "workspace"


let platform = RevoUtils.Platform.GetPlatform()
let flavor = RevoUtils.Platform.GetPlatformFlavor()
let version = RevoUtils.Platform.GetReleaseVersion()

Target "Build" (fun _ ->
    trace "The build starts here."
    trace("The platform is " + platform.ToString())
    trace("The platform version is " + version.ToString())
    trace("This script is executing in " + SCRIPT_DIR)

    FileUtils.mkdir(WORKSPACE)
)

Target "Build_Linux" (fun _ ->
    trace "Entered Linux Logic"
)

Target "Build_Windows" (fun _ ->
    trace "Entered Windows Logic"
)

Target "Default" (fun _ ->
    trace "Default task"
)

"Build"
  =?> ("Build_Windows", (platform = System.PlatformID.Win32NT))
  =?> ("Build_Linux", (platform = System.PlatformID.Unix) && (flavor <> Platform.PlatformFlavor.UnknownUnix))
  ==> "Default"

Run "Default"