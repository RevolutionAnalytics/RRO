$NUGET_URL = 'https://nuget.org/nuget.exe'
$REVO_NUGET_FEED = 'https://msdata.pkgs.visualstudio.com/DefaultCollection/_packaging/MRS_Vendor/nuget/v3/index.json'
$output = takeown /r /f .

md c:\temp
$env:temp='c:\temp'
$env:tmp='c:\temp'

Write-Host Dumping environment variables
gci env:

if ($LastExitCode -ne 0)
{
    Write-Error "Take ownership failed"
    Write-Output $output
    
    exit -1
}
else
{
    Write-Output "Successfully took ownership of all items in the `"$PWD`" directory"
}

if (-Not (Get-Command nuget.exe -ErrorAction SilentlyContinue))
{
    $nugetPath = '\nuget'
    md $nugetPath -Force
    
    $nugetPath = Convert-Path $nugetPath
    Write-Host $nugetPath
    
	Invoke-WebRequest -Uri $NUGET_URL -OutFile \nuget\nuget.exe

    $env:Path = $env:Path + ';' + $nugetPath
    [Environment]::SetEnvironmentVariable('PATH', $env:Path, 'Machine')
}

nuget update -self
nuget restore RRO-src/buildFiles/RRO_Build.sln

if($env:NUGET_PASSWORD)
{
    nuget sources add -Name mro -UserName token -Password $env:NUGET_PASSWORD -Source $REVO_NUGET_FEED
    if($LastExitCode -ne 0)
    {
        nuget sources update -Name mro -UserName token -Password $env:NUGET_PASSWORD -Source $REVO_NUGET_FEED
    }
}

$retries = 0
do
{
    $output = nuget install packages.config -ExcludeVersion -OutputDirectory .\vendor
    
    $needsRetry = ($LastExitCode -ne 0) -or ($output -cmatch 'WARNING:')
    
    if ($needsRetry)
    {
        Write-Warning "Failed to retrieve all nuget packages for vendor directory"
    }

    Write-Output $output
} while ($needsRetry -and ($retries++ -lt 5))

if ($needsRetry)
{
    Write-Error "Failed to restore the vendor directory"
    exit -1
}

Push-Location RRO-src/buildFiles

$msbuild = Join-Path ${env:ProgramFiles(x86)} "msbuild\14.0\bin\msbuild.exe"
& $msbuild /p:Configuration=Release

packages/FAKE.4.0.3/tools/fake.exe

Pop-Location

