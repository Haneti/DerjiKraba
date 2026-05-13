using System;
using System.IO;
using Avalonia;
using Avalonia.Styling;

namespace AvaloniaApplication1.Services
{
    public enum ThemeMode
    {
        Light,
        Dark
    }

    public class ThemeManager
    {
        private static ThemeManager? _instance;
        private const string SettingsFileName = "theme.txt";

        public event EventHandler<ThemeMode>? ThemeChanged;

        private ThemeManager()
        {
            LoadThemePreference();
        }

        public static ThemeManager Instance => _instance ??= new ThemeManager();

        public ThemeMode CurrentTheme => Application.Current?.RequestedThemeVariant == ThemeVariant.Dark 
            ? ThemeMode.Dark 
            : ThemeMode.Light;

        public void SetTheme(ThemeMode theme)
        {
            if (Application.Current == null) return;
            
            var newVariant = theme == ThemeMode.Dark ? ThemeVariant.Dark : ThemeVariant.Light;
            if (Application.Current.RequestedThemeVariant == newVariant) return;

            Application.Current.RequestedThemeVariant = newVariant;
            SaveThemePreference();
            ThemeChanged?.Invoke(this, theme);
        }

        public void ToggleTheme()
        {
            SetTheme(CurrentTheme == ThemeMode.Light ? ThemeMode.Dark : ThemeMode.Light);
        }

        private void LoadThemePreference()
        {
            if (Application.Current == null) return;
            
            try
            {
                var settingsPath = GetSettingsPath();
                if (File.Exists(settingsPath))
                {
                    var content = File.ReadAllText(settingsPath).Trim();
                    if (content == "Dark")
                    {
                        Application.Current.RequestedThemeVariant = ThemeVariant.Dark;
                        return;
                    }
                }
            }
            catch { }

            // Default to Light
            Application.Current.RequestedThemeVariant = ThemeVariant.Light;
        }

        private void SaveThemePreference()
        {
            try
            {
                var settingsPath = GetSettingsPath();
                Directory.CreateDirectory(Path.GetDirectoryName(settingsPath)!);
                File.WriteAllText(settingsPath, CurrentTheme.ToString());
            }
            catch { }
        }

        private string GetSettingsPath()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "DerjiKraba",
                SettingsFileName
            );
        }
    }
}
