namespace PluginTemplate {
    namespace Shared {
        string FormatStatusLine(const string &in label, const string &in value) {
            return label + ": " + value;
        }

        class StatusLine {
            string label;
            string value;

            StatusLine() {
            }

            StatusLine(const string &in label, const string &in value) {
                this.label = label;
                this.value = value;
            }
        }
    }
}
