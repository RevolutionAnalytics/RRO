using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RevoUtils
{
    //Helper methods that can find tools need to build RRO
    public static class RTools
    {
        public static Version GetRToolsVersion()
        {
            if (Platform.GetPlatform() != System.PlatformID.Win32NT)
                return null;

            string rToolsName = null;
            
            string programRegKey = @"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
            using(Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(programRegKey))
            {
                foreach(string subKey_name in key.GetSubKeyNames())
                {
                    using(Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                    {
                        if (subKey.GetValueNames().Contains("DisplayName") && subKey.GetValue("DisplayName").ToString().Contains("Rtools"))
                            rToolsName = subKey.GetValue("DisplayName").ToString();
                    }
                }
            }
            
            if (rToolsName == null)
            {
                using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(programRegKey))
                {
                    if (key != null)
                    {
                        foreach (string subKey_name in key.GetSubKeyNames())
                        {
                            using (Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                            {
                                if (subKey.GetValueNames().Contains("DisplayName") && subKey.GetValue("DisplayName").ToString().Contains("Rtools"))
                                    rToolsName = subKey.GetValue("DisplayName").ToString();
                            }
                        }
                    }
                }

            }

            if (rToolsName == null)
                return null;

            var version = System.Text.RegularExpressions.Regex.Match(rToolsName, "[0-9].[0-9]");
            if (version.Success)
                return new System.Version(version.ToString());
            else
                return null;
        }
        public static string GetRToolsPath(Version rToolsVersion)
        {
            if (Platform.GetPlatform() != System.PlatformID.Win32NT)
                return null;

            if (rToolsVersion == null)
                return null;

            string rToolsPath = null;

            string programRegKey = @"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
            using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(programRegKey))
            {
                foreach (string subKey_name in key.GetSubKeyNames())
                {
                    using (Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                    {
                        if (subKey.GetValueNames().Contains("DisplayName") && subKey.GetValue("DisplayName").ToString().Contains("Rtools " + rToolsVersion.ToString()))
                        {
                            if (subKey.GetValueNames().Contains("InstallLocation"))
                                rToolsPath = subKey.GetValue("InstallLocation").ToString();
                        }
                    }
                }
            }

            return rToolsPath;
        }
        public static string GetProgramPathByNameAndVersion(string name, Version version)
        {
            if (Platform.GetPlatform() != System.PlatformID.Win32NT)
                return null;

            if (version == null)
                return null;

            string rToolsPath = null;

            string programRegKey = @"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
            using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(programRegKey))
            {
                foreach (string subKey_name in key.GetSubKeyNames())
                {
                    using (Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                    {
                        if (subKey.GetValueNames().Contains("DisplayName") && 
                            subKey.GetValue("DisplayName").ToString().Contains(name) &&
                            subKey.GetValue("DisplayName").ToString().Contains(version.ToString()))
                        {
                            if (subKey.GetValueNames().Contains("InstallLocation"))
                                rToolsPath = subKey.GetValue("InstallLocation").ToString();
                        }
                        else if (subKey.GetValueNames().Contains("DisplayName") && 
                                 subKey.GetValueNames().Contains("DisplayVersion") &&
                                 subKey.GetValue("DisplayName").ToString().Contains(name))
                        {
                            if (subKey.GetValueNames().Contains("InstallLocation"))
                                rToolsPath = subKey.GetValue("InstallLocation").ToString();
                        }
                    }
                }
            }

            return rToolsPath;
        }

        public static Version GetProgramVersionByName(string name)
        {
            if (Platform.GetPlatform() != System.PlatformID.Win32NT)
                return null;

            string rToolsName = null;
            string progVersion = null;

            string programRegKey = @"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall";
            using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(programRegKey))
            {
                foreach (string subKey_name in key.GetSubKeyNames())
                {
                    
                    using (Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                    {
                        if (subKey.GetValueNames().Contains("DisplayName") && subKey.GetValue("DisplayName").ToString().Contains(name))
                        {
                            rToolsName = subKey.GetValue("DisplayName").ToString();
                            if(subKey.GetValueNames().Contains("DisplayVersion"))
                            {
                                progVersion = subKey.GetValue("DisplayVersion").ToString();
                            }
                        }
                    }
                }
            }

            if (rToolsName == null)
            {
                using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(programRegKey))
                {
                    if (key != null)
                    {
                        foreach (string subKey_name in key.GetSubKeyNames())
                        {
                            using (Microsoft.Win32.RegistryKey subKey = key.OpenSubKey(subKey_name))
                            {
                                if (subKey.GetValueNames().Contains("DisplayName") && subKey.GetValue("DisplayName").ToString().Contains(name))
                                    rToolsName = subKey.GetValue("DisplayName").ToString();
                            }
                        }
                    }
                }

            }

            if (rToolsName == null)
                return null;


            if(progVersion == null)
            {
                var version = System.Text.RegularExpressions.Regex.Match(rToolsName, "[0-9]+.[0-9]+");
                if (version.Success)
                    return new System.Version(version.ToString());
                else
                    return new System.Version("0.0");
            }
            else
            {
                var version = System.Text.RegularExpressions.Regex.Match(progVersion, "[0-9]+.[0-9]+");
                if (version.Success)
                    return new System.Version(version.ToString());
                else
                    return new System.Version("0.0");
            }


        }

    }

    
}
