using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

using Microsoft.Win32;

namespace RevoUtils
{
    //Helper methods that can find tools need to build RRO
    public static class RTools
    {
        public static Version GetRToolsVersion()
        {
            return GetProgramVersionByName("Rtools");
        }

        public static string GetRToolsPath(Version rToolsVersion)
        {
            return GetProgramPathByNameAndVersion("Rtools", rToolsVersion);
        }

        public static string GetProgramPathByNameAndVersion(string name, Version version)
        {
            return GetProgram(name, version)?.InstallPath;
        }

        public static Version GetProgramVersionByName(string name)
        {
            return GetPrograms(name).FirstOrDefault()?.Version;
        }

        private static ProgramData GetProgram(string name, Version version)
        {
            return GetPrograms(name).FirstOrDefault(pd => pd.Version == version);
        }

        private static IEnumerable<ProgramData> GetPrograms(string name)
        {
            string[] paths = { @"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" };
            RegistryKey[] hives = { Registry.LocalMachine, Registry.CurrentUser };

            return from path in paths from hive in hives from program in GetPrograms(hive, path, name) select program;
        }

        private static IEnumerable<ProgramData> GetPrograms(RegistryKey hive, string path, string name)
        {
            if (Platform.GetPlatform() == PlatformID.Win32NT)
            {
                using (RegistryKey key = hive.OpenSubKey(path))
                {
                    foreach (RegistryKey subKey in key.GetSubKeyNames().Select(key.OpenSubKey))
                    {
                        using (subKey)
                        {
                            string displayName = subKey.GetValue("DisplayName")?.ToString();
                            if (displayName?.Contains(name) ?? false)
                            {
                                yield return
                                    new ProgramData
                                    {
                                        Name = name,
                                        Version = GetVersion(displayName, subKey.GetValue("DisplayVersion")?.ToString()),
                                        InstallPath = subKey.GetValue("InstallLocation")?.ToString()
                                    };
                            }
                        }
                    }
                }
            }
        }

        private static Version GetVersion(string name, string version)
        {
            Match ret = Regex.Match(version ?? name, "[0-9]+.[0-9]+");

            return new Version(ret.Success ? ret.ToString() : "0.0");
        }

        private class ProgramData
        {
            public string Name { get; set; }

            public Version Version { get; set; }

            public string InstallPath { get; set; }
        }
    }
}