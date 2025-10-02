[Setting hidden name="Enabled"]
bool S_Enabled = true;

[Setting hidden name="Show/hide with game UI"]
bool S_HideWithGame = true;

[Setting hidden name="Show/hide with Openplanet UI"]
bool S_HideWithOP = false;

[SettingsTab name="Settings" icon="Cog" order="99999999999999999999999999999999999999999999999998"] // One less than logging
void RenderBasicSettings() {
    UI::Checkbox("Enabled", S_Enabled);
    UI::Checkbox("Show/hide with game UI", S_HideWithGame);
    UI::Checkbox("Show/hide with Openplanet UI", S_HideWithOP);
}