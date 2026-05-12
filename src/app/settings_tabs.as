[SettingsTab name = "General" icon = "Cog" order = 1]
void RenderPluginTemplateGeneralSettingsTab() {
    PluginTemplate::App::RenderGeneralSettingsUI();
}

[SettingsTab name = "Logging" icon = "ListAlt" order = 99]
void RenderPluginTemplateLoggingSettingsTab() {
    PluginTemplate::App::RenderLoggingSettingsUI();
}
