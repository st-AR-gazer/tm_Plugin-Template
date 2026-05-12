namespace PluginTemplate {
    Meta::Plugin@ PluginMeta = Meta::ExecutingPlugin();

    namespace App {
        [Setting hidden name = "Window open"]
        bool S_WindowOpen = true;

        [Setting hidden name = "Hide with game UI"]
        bool S_HideWithGame = true;

        [Setting hidden name = "Hide with Openplanet UI"]
        bool S_HideWithOP = false;

        string g_MenuIcon = "";

        string PluginNameHash() {
            return Crypto::MD5(PluginTemplate::PluginMeta.Name);
        }

        string MenuIcon() {
            if (g_MenuIcon.Length == 0) {
                g_MenuIcon = _Text::StableIconForSeed(PluginNameHash());
            }
            return g_MenuIcon;
        }

        string MenuTitle() {
            string hash = PluginNameHash();
            return "\\$" + hash.SubStr(0, 3) + MenuIcon() + "\\$z " + PluginTemplate::PluginMeta.Name;
        }
    }
}
