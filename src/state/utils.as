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
        for (int i = 0; i < n; ++i) {
            index = str.IndexOf(value, index + 1);
            if (index == -1) break;
        }
        return index;
    }

    // ty XertroV
    string GetRandomIcon(const string &in hash) {
        auto icons = Icons::GetAll();
        auto iconKeys = icons.GetKeys();
        if (hash.Length < 16) log("Hash must be at least 16 hex characters long.", LogLevel::Error, 84, "GetRandomIcon");
        auto n = Text::ParseUInt(hash.SubStr(4, 4), 16);
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
            if (verbose) log("Writing to file: " + path, LogLevel::Info, 84, "WriteFile");

            if (path.EndsWith("/") || path.EndsWith("\\")) { log("Invalid file path: " + path, LogLevel::Error, 86, "WriteFile"); return; }

            if (!IO::FolderExists(Path::GetDirectoryName(path))) { IO::CreateFolder(Path::GetDirectoryName(path), true); }

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

        void WriteJsonFile(const string &in path, const Json::Value &in value) {
            string content = Json::Write(value);
            WriteFile(path, content);
        }

        // Read from file
        string ReadFileToEnd(const string &in path, bool verbose = false) {
            if (verbose) log("Reading file: " + path, LogLevel::Info, 114, "ReadFileToEnd");
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 115, "ReadFileToEnd"); return ""; }

            IO::File file(path, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();
            return content;
        }
        
        string ReadSourceFileToEnd(const string &in path, bool verbose = false) {
            if (!IO::FileExists(path)) { log("File does not exist: " + path, LogLevel::Error, 124, "ReadSourceFileToEnd"); return ""; }

            IO::FileSource f(path);
            string content = f.ReadToEnd();
            return content;
        }

        // Move file
        void CopySourceFileToNonSource(const string &in originalPath, const string &in storagePath, bool verbose = false) {
            if (verbose) log("Moving the file content", LogLevel::Info, 133, "CopySourceFileToNonSource");
            
            string fileContents = ReadSourceFileToEnd(originalPath);
            WriteFile(storagePath, fileContents);

            if (verbose) log("Finished moving the file", LogLevel::Info, 138, "CopySourceFileToNonSource");

            // TODO: Must check how IO::Move works with source files
        }

        // Copy file
        void CopyFileTo(const string &in source, const string &in destination, bool verbose = false) {
            if (!IO::FileExists(source)) { if (verbose) log("Source file does not exist: " + source, LogLevel::Error, 145, "CopyFileTo"); return; }
            if (IO::FileExists(destination)) { if (verbose) log("Destination file already exists: " + destination, LogLevel::Error, 146, "CopyFileTo"); return; }

            string content = ReadFileToEnd(source, verbose);
            WriteFile(destination, content, verbose);
        }

        // Rename file
        void RenameFile(const string &in filePath, const string &in newFileName, bool verbose = false) {
            if (verbose) log("Attempting to rename file: " + filePath, LogLevel::Info, 154, "RenameFile");
            if (!IO::FileExists(filePath)) { log("File does not exist: " + filePath, LogLevel::Error, 155, "RenameFile"); return; }

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
            if (verbose) log("Folder does not exist: " + path, LogLevel::Info, 183, "OpenFolder");
        }
    }
}