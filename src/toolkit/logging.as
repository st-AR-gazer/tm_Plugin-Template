string pluginName = Meta::ExecutingPlugin().Name;

void NotifyDebug(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(.5, .5, .5, .3), t);
}

void NotifyInfo(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(.2, .8, .5, .3), t);
}

void NotifyNotice(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(.2, .8, .5, .3), t);
}

void NotifyWarning(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(1, .5, .1, .5), t);
}

void NotifyError(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(1, .2, .2, .3), t);
}

void NotifyCritical(const string &in msg = "", const string &in pn = pluginName, int t = 6000) {
    UI::ShowNotification(pn, msg, vec4(1, .2, .2, .3), t);
}

enum LogLevel {
    Debug, Info, Notice, Warning, Error, Critical, Custom
}

namespace logging {
    [Setting category = "z~DEV" name = "Write a copy of each log line to file" hidden]
    bool S_writeLogToFile = false;

    [Setting category = "z~DEV" name = "Show default OP logs" hidden]
    bool S_showDefaultLogs = true;

    [Setting category = "z~DEV" name = "Show Custom logs" hidden]
    bool DEV_S_sCustom = true;

    [Setting category = "z~DEV" name = "Show Debug logs" hidden]
    bool DEV_S_sDebug = true;

    [Setting category = "z~DEV" name = "Show Info logs" hidden]
    bool DEV_S_sInfo = true;

    [Setting category = "z~DEV" name = "Show Notice logs" hidden]
    bool DEV_S_sNotice = true;

    [Setting category = "z~DEV" name = "Show Warning logs" hidden]
    bool DEV_S_sWarning = true;

    [Setting category = "z~DEV" name = "Show Error logs" hidden]
    bool DEV_S_sError = true;

    [Setting category = "z~DEV" name = "Show Critical logs" hidden]
    bool DEV_S_sCritical = true;

    [Setting category = "z~DEV" name = "Set log level" min = 0 max = 5 hidden]
    int DEV_S_sLogLevelSlider = 0;

    [Setting category = "z~DEV" name = "Show function name in logs" hidden]
    bool S_showFunctionNameInLogs = true;

    [Setting category = "z~DEV" name = "Set max function name length in logs" min = 0 max = 50 hidden]
    int S_maxFunctionNameLength = 15;

    const string kLogsFolder = "Logs/";
    const string kDiagPrefix = "diagnostics_";
    const string kLatestBuildFile = "latest_build.txt";
    const string kBuildJsonFile = "build.json";
    const uint kRetentionDays = 14;
    const uint kOneDayMs = 86400000;

    string g_diagFilePath;
    int lastSliderValue = DEV_S_sLogLevelSlider;

    void AppendToDiagFile(const string &in line) {
        if (!S_writeLogToFile) return;
        if (g_diagFilePath.Length == 0) SetDiagFilePath();

        string absLogs = IO::FromStorageFolder(kLogsFolder);
        if (!IO::FolderExists(absLogs)) IO::CreateFolder(absLogs);

        IO::File f;
        f.Open(g_diagFilePath, IO::FileMode::Append);
        f.Write(line + "\n");
        f.Close();
    }

    void RotateOldLogFiles() {
        string absFolder = IO::FromStorageFolder(kLogsFolder);
        array<string> @files = IO::IndexFolder(absFolder, false);

        int64 earliestMs = Time::Now - int64(kRetentionDays - 1) * kOneDayMs;
        if (earliestMs < 0) earliestMs = 0;
        string earliestKeep = Time::FormatString("%Y-%m-%d", earliestMs);

        for (uint i = 0; i < files.Length; i++) {
            string fullPath = files[i];
            if (!fullPath.EndsWith(".log")) continue;

            string baseName = fullPath.SubStr(absFolder.Length);
            if (!baseName.StartsWith(kDiagPrefix)) continue;

            string dateStr = baseName.SubStr(kDiagPrefix.Length, 10);
            if (dateStr < earliestKeep) IO::Delete(fullPath);
        }
    }

    void SetDiagFilePath() {
        string today = Time::FormatString("%Y-%m-%d");
        g_diagFilePath = IO::FromStorageFolder(kLogsFolder + kDiagPrefix + today + ".log");
    }

    void UpdateBuildFiles() {
        string curVer = Meta::ExecutingPlugin().Version;
        string latestP = IO::FromStorageFolder(kLogsFolder + kLatestBuildFile);

        string prevVer;
        if (IO::FileExists(latestP)) {
            IO::File f;
            f.Open(latestP, IO::FileMode::Read);
            prevVer = f.ReadLine().Trim();
            f.Close();
        }

        if (curVer == prevVer) return;

        IO::File f;
        f.Open(latestP, IO::FileMode::Write);
        f.WriteLine(curVer);
        f.WriteLine("Updated: " + Time::FormatString("%Y-%m-%d %H:%M:%S"));
        f.Close();

        Json::Value j = Json::Object();
        j["name"] = Meta::ExecutingPlugin().Name;
        j["version"] = curVer;
        j["updatedAt"] = Time::FormatString("%Y-%m-%dT%H:%M:%SZ");
        j["author"] = Meta::ExecutingPlugin().Author;

        IO::File jf;
        jf.Open(IO::FromStorageFolder(kLogsFolder + kBuildJsonFile), IO::FileMode::Write);
        jf.Write(Json::Write(j, true));
        jf.Close();
    }

    string _Tag(const string &in txt, const string &in col) {
        string t = txt.ToUpper();
        while (t.Length < 7) t += " ";
        return col + "[" + t + "] ";
    }

    void Initialise() {
        string absLogs = IO::FromStorageFolder(kLogsFolder);
        if (!IO::FolderExists(absLogs)) IO::CreateFolder(absLogs);

        RotateOldLogFiles();
        SetDiagFilePath();
        UpdateBuildFiles();
    }

    string _LevelName(int level) {
        if (level == 0) return "Debug";
        if (level == 1) return "Info";
        if (level == 2) return "Notice";
        if (level == 3) return "Warning";
        if (level == 4) return "Error";
        return "Critical";
    }

    void _ApplyLevelPreset(int minLevel) {
        minLevel = Math::Clamp(minLevel, 0, 5);
        DEV_S_sDebug = minLevel <= 0;
        DEV_S_sInfo = minLevel <= 1;
        DEV_S_sNotice = minLevel <= 2;
        DEV_S_sWarning = minLevel <= 3;
        DEV_S_sError = minLevel <= 4;
        DEV_S_sCritical = minLevel <= 5;
        DEV_S_sLogLevelSlider = minLevel;
        lastSliderValue = minLevel;
    }

    void RenderSettingsUI(const string &in idPrefix = "logging") {
        if (g_diagFilePath.Length == 0) SetDiagFilePath();

        bool writeToFile = S_writeLogToFile;
        writeToFile = UI::Checkbox("Write a copy of each log line to file##" + idPrefix, writeToFile);
        if (writeToFile != S_writeLogToFile) S_writeLogToFile = writeToFile;
        UI::TextDisabled(g_diagFilePath.Length > 0 ? g_diagFilePath : IO::FromStorageFolder(kLogsFolder));
        if (UI::Button("Copy log path##" + idPrefix)) IO::SetClipboard(g_diagFilePath);

        UI::Separator();
        S_showDefaultLogs = UI::Checkbox("Mirror standard levels to Openplanet log##" + idPrefix, S_showDefaultLogs);
        S_showFunctionNameInLogs = UI::Checkbox("Show function name in logs##" + idPrefix, S_showFunctionNameInLogs);

        int maxFn = S_maxFunctionNameLength;
        UI::SetNextItemWidth(140.0f);
        maxFn = UI::InputInt("Function name width##" + idPrefix, maxFn);
        S_maxFunctionNameLength = Math::Clamp(maxFn, 0, 80);

        UI::Separator();
        int minLevel = Math::Clamp(DEV_S_sLogLevelSlider, 0, 5);
        UI::SetNextItemWidth(220.0f);
        minLevel = UI::SliderInt("Minimum standard level##" + idPrefix, minLevel, 0, 5);
        if (minLevel != DEV_S_sLogLevelSlider || minLevel != lastSliderValue) _ApplyLevelPreset(minLevel);
        UI::TextDisabled("Preset: " + _LevelName(minLevel) + " and above");

        DEV_S_sCustom = UI::Checkbox("Custom##" + idPrefix, DEV_S_sCustom);
        DEV_S_sDebug = UI::Checkbox("Debug##" + idPrefix, DEV_S_sDebug);
        DEV_S_sInfo = UI::Checkbox("Info##" + idPrefix, DEV_S_sInfo);
        DEV_S_sNotice = UI::Checkbox("Notice##" + idPrefix, DEV_S_sNotice);
        DEV_S_sWarning = UI::Checkbox("Warning##" + idPrefix, DEV_S_sWarning);
        DEV_S_sError = UI::Checkbox("Error##" + idPrefix, DEV_S_sError);
        DEV_S_sCritical = UI::Checkbox("Critical##" + idPrefix, DEV_S_sCritical);
    }
}

void log(
    const string &in msg,
    LogLevel level = LogLevel::,
    int line = -1,
    string _fnName = "",
    string _tag = "",
    string _tagColor = "\\$f80"
) {
    string lineInfo = line >= 0 ? " " + tostring(line) : "";
    while (lineInfo.Length > 0 && lineInfo.Length < 4) lineInfo += " ";

    if (_fnName.Length > logging::S_maxFunctionNameLength) {
        _fnName = _fnName.SubStr(0, logging::S_maxFunctionNameLength);
    } while (_fnName.Length<logging::S_maxFunctionNameLength) _fnName += " ";
    if (!logging::S_showFunctionNameInLogs) _fnName = "";

    array<string> tags = {
        "\\$0ff[DEBUG]  ",
        "\\$0f0[INFO]   ",
        "\\$0ff[NOTICE] ",
        "\\$ff0[WARNING] ",
        "\\$f00[ERROR]  ",
        "\\$f00\\$o\\$i\\$w[CRITICAL] "
    };
    array<string> bodies = {
        "\\$0cc",
        "\\$0c0",
        "\\$0cc",
        "\\$cc0",
        "\\$c00",
        "\\$f00\\$o\\$i\\$w"
    };

    string prefix, body;
    if (level == LogLevel::Custom) {
        prefix = logging::_Tag(_tag, _tagColor);
        body = _tagColor;
    } else {
        prefix = tags[int(level)];
        body = bodies[int(level)];
    }

    string full = prefix + "\\$z" + body + lineInfo + " : " + _fnName + " : \\$z" + msg;

    string ts = Time::FormatString("%Y-%m-%d %H:%M:%S  ");
    logging::AppendToDiagFile(ts + Text::StripOpenplanetFormatCodes(full));

    array<bool> enabled = {
        logging::DEV_S_sDebug,
        logging::DEV_S_sInfo,
        logging::DEV_S_sNotice,
        logging::DEV_S_sWarning,
        logging::DEV_S_sError,
        logging::DEV_S_sCritical
    };
    if (level != LogLevel::Custom && !enabled[int(level)]) return;
    if (level == LogLevel::Custom && !logging::DEV_S_sCustom) return;

    ///<
    if (logging::S_showDefaultLogs && level != LogLevel::Custom) {
        switch (level) {
        case LogLevel::Warning : warn(msg);
            break;
        case LogLevel::Error : error(msg);
            break;
        case LogLevel::Critical : error("\$o\$i\$w" + msg);
            break;
        default:
            trace(msg);
            break;
        }
    } else {
        print(full);
    }
    ///>
}

auto logging_initializer = startnew(logging::Initialise);
