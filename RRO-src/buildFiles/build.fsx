#r "./packages/FAKE.4.0.3/tools/FakeLib.dll"
#r "./RevoUtils/bin/Release/RevoUtils.dll"

open Fake
open RevoUtils

let mutable platform = RevoUtils.Platform.GetPlatform();

Target "Build" (fun _ ->

    
    trace "The build starts here."
    trace("The platform is " + platform.ToString())
)

Run "Build"