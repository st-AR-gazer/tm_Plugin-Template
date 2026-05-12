namespace PluginTemplate {
    namespace App {
        void Main() {
            log(
                "Loaded " + PluginTemplate::PluginMeta.Name + " v" + PluginTemplate::PluginMeta.Version,
                LogLevel::Debug,
                4,
                "PluginTemplate::App::Main"
            );
        }

        bool ShouldRenderWindow() {
            if (!S_WindowOpen) return false;
            if (S_HideWithGame && !UI::IsGameUIVisible()) return false;
            if (S_HideWithOP && !UI::IsOverlayShown()) return false;
            return true;
        }

        void RenderInterface() {
            if (!ShouldRenderWindow()) return;

            if (UI::Begin(MenuTitle() + "###main-" + PluginTemplate::PluginMeta.ID, S_WindowOpen, UI::WindowFlags::None)) {
                RenderWindow();
            }
            UI::End();
        }

        void RenderMenu() {
            if (UI::MenuItem(MenuTitle(), "", S_WindowOpen)) {
                S_WindowOpen = !S_WindowOpen;
            }
        }

        void RenderWindow() {
            UI::Text(PluginTemplate::PluginMeta.Name + " " + PluginTemplate::PluginMeta.Version);
            UI::Separator();
            PluginTemplate::Example::RenderPanel();
        }
    }
}
