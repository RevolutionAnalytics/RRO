#r "./packages/FAKE.4.0.3/tools/FakeLib.dll"
#r "./RevoUtils/bin/Release/RevoUtils.dll"

open Fake
open RevoUtils

let platform = RevoUtils.Platform.GetPlatform()
let version = RevoUtils.Platform.GetReleaseVersion()

Target "Build" (fun _ ->
    trace "The build starts here."
    trace("The platform is " + platform.ToString())
    trace("The platform version is " + version.ToString())
)

Run "Build"