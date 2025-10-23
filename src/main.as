Meta::Plugin@ pluginMeta = Meta::ExecutingPlugin();
const string  pluginNameHash = Crypto::MD5(pluginMeta.Name);
const string  menuIconColor = "\\$" + pluginNameHash.SubStr(0, 3);
const string  pluginIcon = GetRandomIcon(pluginNameHash); // Replace with an apropriate specific icon
const string  menuTitle = menuIconColor + pluginIcon + "\\$z " + pluginMeta.Name;

void Main() {
    
}

void RenderInterface() {
    if (!S_Enabled || (S_HideWithGame && !UI::IsGameUIVisible()) || (S_HideWithOP && !UI::IsOverlayShown())) { return; }

    if (UI::Begin(menuTitle + "###main-" + pluginMeta.ID, S_Enabled, UI::WindowFlags::None)) {
        RenderWindow();
    }
    UI::End();
}

void RenderMenu() {
    if (UI::MenuItem(menuTitle, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
    }
}

void RenderWindow() {
    
}