param 
(
    [parameter(Position=0)]
    [string]$miktexDir
)

Write-Host "Verifying mpm packages"

function installPackage([string] $packageName, [string] $pathToMpm) 
{
    $installed = & $pathToMpm --verify=$packageName
    
    if ($installed -ne "Package $packageName is correctly installed.") 
    {
        Write-Host "Installing $packageName, mpm reported $installed"
        
        & $pathToMpm --install=$packageName
    }
    else
    {
        Write-Host "Package $packageName is correctly installed"
    }
}

if (-not (Test-Path $miktexDir)) 
{
    Throw "The specified miktex directory $miktexDir does not exist."
}

$mpmDir = Combine-Path $miktexDir 'miktex\bin\x64'

if (-not (Test-Path $mpmDir)) 
{
    Throw "The path to mpm.exe ($mpmDir) was not found in the miktex install directory $miktexDir"
}

$mpm = Combine-Path $mpmDir 'mpm.exe'

if (-not (Test-Path $mpm)) 
{
    Throw "The miktex package manager was not found in the expected location $mpm"
}

$packages = "url", "mptopdf", "inconsolata", "epsf"

foreach ($package in $packages)
{
    installPackage $package $mpm
}

Write-Host "Done verifying mpm packages"