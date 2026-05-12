namespace PluginTemplate {
    namespace Example {
        uint g_ActionCount = 0;
        string g_Status = "Ready";

        void RunExampleAction() {
            g_ActionCount++;
            g_Status = "Ran action " + g_ActionCount + " at " + Time::FormatString("%H:%M:%S");
            log(g_Status, LogLevel::Info, 9, "PluginTemplate::Example::RunExampleAction");
        }

        void Reset() {
            g_ActionCount = 0;
            g_Status = "Ready";
            log("Example state reset", LogLevel::Debug, 15, "PluginTemplate::Example::Reset");
        }

        void RenderPanel() {
            UI::Text(PluginTemplate::Shared::FormatStatusLine("Status", g_Status));
            UI::Text(PluginTemplate::Shared::FormatStatusLine("Actions", tostring(g_ActionCount)));

            UI::Separator();
            if (UI::Button("Run example action##plugin-template")) {
                RunExampleAction();
            }
            UI::SameLine();
            if (UI::Button("Reset##plugin-template")) {
                Reset();
            }
        }

        void RenderSettingsUI() {
            UI::Text("Example");
            UI::TextDisabled("Small replaceable feature module used by the template scaffold.");
            if (UI::Button("Reset example state##plugin-template-settings")) {
                Reset();
            }
        }
    }
}
