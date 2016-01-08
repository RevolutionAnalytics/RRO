$NUGET_URL = 'https://nuget.org/nuget.exe'

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

nuget restore RRO-src/buildFiles/RRO_Build.sln

Push-Location RRO-src/buildFiles

$msbuild = Join-Path ${env:ProgramFiles(x86)} "msbuild\14.0\bin\msbuild.exe"
& $msbuild /p:Configuration=Release

packages/FAKE.4.0.3/tools/fake.exe

Pop-Location

