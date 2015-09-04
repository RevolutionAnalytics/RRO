c:\nuget.exe restore .\RRO-src\buildFiles\RRO_build.sln
C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe .\RRO-src\buildFiles\RRO_build.sln /t:Build /p:Configuration=Release
call .\RRO-src\buildFiles\packages\FAKE.4.0.3\tools\FAKE.exe .\RRO-src\buildFiles\build.fsx
