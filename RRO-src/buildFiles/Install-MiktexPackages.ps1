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

$mpmDir = Join-Path $miktexDir 'miktex\bin\x64'

if (-not (Test-Path $mpmDir)) 
{
    Throw "The path to mpm.exe ($mpmDir) was not found in the miktex install directory $miktexDir"
}

$mpm = Join-Path $mpmDir 'mpm.exe'

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

Write-Host "Fixing miktex"

$initexmf = Join-Path $mpmDir 'initexmf.exe'

if (-not (Test-Path $initexmf))
{
    Throw "The initexmf.exe utility was not found in the expected location $mpmDir"
}

& $initexmf --update-fndb
$success = $miktexDir -match 'miktex-([0-9]\.[0-9])'

$profileConfig = Join-Path $env:APPDATA "MiKTeX\$($matches[1])\miktex\config\updmap"

Set-Content $profileConfig "Map zi4.map"

& $initexmf --mkmaps 

Write-Host "Done fixing miktex"