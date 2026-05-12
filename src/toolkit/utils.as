// Fun Utils I use from time to time

namespace _Text {
    int NthLastIndexOf(const string &in str, const string &in value, int n) {
        int index = -1;
        for (int i = str.Length - 1; i >= 0; --i) {
            if (str.SubStr(i, value.Length) == value) {
                if (n == 1) {
                    index = i;
                    break;
                }
                --n;
            }
        }
        return index;
    }

    int NthIndexOf(const string &in str, const string &in value, int n) {
        int index = -1;
        int start = 0;

        for (int i = 0; i < n; ++i) {
            string segment = str.SubStr(start);
            int found = segment.IndexOf(value);
            if (found == -1) {
                index = -1;
                break;
            }
            index = start + found;
            start = index + 1;
            if (start >= str.Length) break;
        }
        return index;
    }

    // ty XertroV
    string GetRandomIcon(const string &in hash) {
        auto icons = Icons::GetAll();
        auto iconKeys = icons.GetKeys();
        if (hash.Length < 16) log("Hash must be at least 16 hex characters long.", LogLevel::Error, 40, "_Text::GetRandomIcon");
        auto n = Text::ParseUInt(hash.SubStr(4, 4), 16);
        return string(icons[iconKeys[n % iconKeys.Length]]);
    }

    string StableIconForSeed(const string &in seed) {
        auto icons = Icons::GetAll();
        auto iconKeys = icons.GetKeys();
        if (iconKeys.Length == 0) return "";

        string hash = seed.Length >= 16 ? seed : Crypto::MD5(seed);
        uint n = Text::ParseUInt(hash.SubStr(4, 4), 16);
        return string(icons[iconKeys[n % iconKeys.Length]]);
    }
}

namespace _IO {
    namespace Directory {
        bool IsDirectory(const string &in path) {
            if (path.EndsWith("/") || path.EndsWith("\\")) return true;
            return false;
        }

        string GetParentDirectoryName(const string &in path) {
            string trimmedPath = path;

            if (!IsDirectory(trimmedPath)) {
                return _IO::File::GetFilePathWithoutFileName(trimmedPath);
            }

            if (trimmedPath.EndsWith("/") || trimmedPath.EndsWith("\\")) {
                trimmedPath = trimmedPath.SubStr(0, trimmedPath.Length - 1);
            }

            int index = trimmedPath.LastIndexOf("/");
            int index2 = trimmedPath.LastIndexOf("\\");

            index = Math::Max(index, index2);

            if (index == -1) {
                return "";
            }

            return trimmedPath.SubStr(index + 1);
        }
    }

    namespace File {
        bool IsFile(const string &in path) {
            if (IO::FileExists(path)) return true;
            return false;
        }

        void WriteFile(string _path, const string &in content, bool verbose = false) {
            string path = _path;
            if (verbose) log("Writing to file: " + path, LogLevel::Info, 95, "_IO::File::WriteFile");

            if (path.EndsWith("/") || path.EndsWith("\\")) {
                log("Invalid file path: " + path, LogLevel::Error, 98, "_IO::File::WriteFile");
                return;
            }

            if (!IO::FolderExists(Path::GetDirectoryName(path))) {
                IO::CreateFolder(Path::GetDirectoryName(path), true);
            }

            IO::File file;
            file.Open(path, IO::FileMode::Write);
            file.Write(content);
            file.Close();
        }

        string GetFilePathWithoutFileName(const string &in path) {
            int index = path.LastIndexOf("/");
            int index2 = path.LastIndexOf("\\");

            index = Math::Max(index, index2);

            if (index == -1) {
                return "";
            }

            return path.SubStr(0, index);
        }

        void EnsureStorageFolder(const string &in relativePath) {
            string absPath = IO::FromStorageFolder(relativePath);
            if (!IO::FolderExists(absPath)) IO::CreateFolder(absPath, true);
        }

        void WriteJsonFile(const string &in path, const Json::Value &in value) {
            string content = Json::Write(value);
            WriteFile(path, content);
        }

        // Read from file
        string ReadFileToEnd(const string &in path, bool verbose = false) {
            if (verbose) log("Reading file: " + path, LogLevel::Info, 137, "_IO::File::ReadFileToEnd");
            if (!IO::FileExists(path)) {
                log("File does not exist: " + path, LogLevel::Error, 139, "_IO::File::ReadFileToEnd");
                return "";
            }

            IO::File file(path, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();
            return content;
        }

        string ReadSourceFileToEnd(const string &in path, bool verbose = false) {
            if (!IO::FileExists(path)) {
                log("File does not exist: " + path, LogLevel::Error, 151, "_IO::File::ReadSourceFileToEnd");
                return "";
            }

            IO::FileSource f(path);
            string content = f.ReadToEnd();
            return content;
        }

        // Move file
        void CopySourceFileToNonSource(
            const string &in originalPath,
            const string &in storagePath,
            bool verbose = false
        ) {
            if (verbose) log("Moving the file content", LogLevel::Info, 166, "_IO::File::ReadSourceFileToEnd");

            string fileContents = ReadSourceFileToEnd(originalPath);
            WriteFile(storagePath, fileContents);

            if (verbose) log("Finished moving the file", LogLevel::Info, 171, "_IO::File::ReadSourceFileToEnd");

            // TODO: Must check how IO::Move works with source files
        }

        // Copy file
        void CopyFileTo(const string &in source, const string &in destination, bool verbose = false) {
            if (!IO::FileExists(source)) {
                if (verbose) log(
                    "Source file does not exist: " + source,
                    LogLevel::Error,
                    179,
                    "_IO::File::CopyFileTo"
                );
                return;
            }
            if (IO::FileExists(destination)) {
                if (verbose) log(
                    "Destination file already exists: " + destination,
                    LogLevel::Error,
                    183,
                    "_IO::File::CopyFileTo"
                );
                return;
            }

            string content = ReadFileToEnd(source, verbose);
            WriteFile(destination, content, verbose);
        }

        // Rename file
        void RenameFile(const string &in filePath, const string &in newFileName, bool verbose = false) {
            if (verbose) log("Attempting to rename file: " + filePath, LogLevel::Info, 193, "_IO::File::RenameFile");
            if (!IO::FileExists(filePath)) {
                log("File does not exist: " + filePath, LogLevel::Error, 195, "_IO::File::RenameFile");
                return;
            }

            string currentPath = filePath;
            string newPath;

            string sanitizedNewName = Path::SanitizeFileName(newFileName);

            if (Directory::IsDirectory(newPath)) {
                while (currentPath.EndsWith("/") || currentPath.EndsWith("\\")) {
                    currentPath = currentPath.SubStr(0, currentPath.Length - 1);
                }

                string parentDirectory = Path::GetDirectoryName(currentPath);
                newPath = Path::Join(parentDirectory, sanitizedNewName);
            } else {
                string directoryPath = Path::GetDirectoryName(currentPath);
                string extension = Path::GetExtension(currentPath);
                newPath = Path::Join(directoryPath, sanitizedNewName + extension);
            }

            IO::Move(currentPath, newPath);
        }
    }

    void OpenFolder(const string &in path, bool verbose = false) {
        if (IO::FolderExists(path)) {
            OpenExplorerPath(path);
        } else {
            if (verbose) log("Folder does not exist: " + path, LogLevel::Info, 225, "_IO::OpenFolder");
        }
    }
}
