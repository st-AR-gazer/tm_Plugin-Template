build_name_overwrite = ""
# Empty = use the repository folder name.

import argparse
import os
import zipfile
from pathlib import Path

ROOT = Path.cwd()
SRC_DIR = ROOT / "src"
ADDITIONAL_FILES = ("info.toml", "LICENSE", "README.md")

parser = argparse.ArgumentParser(description="Builds the plugin and creates an .op file.")
parser.add_argument("-s", "--sanitize", action="store_true", help="Remove underscores and hyphens from packaged file names.")
parser.add_argument("-o", "--overwrite-name", type=str, default=build_name_overwrite, help="Specify a custom output file name without .op.")
args = parser.parse_args()


def sanitize_filename(filename):
    return filename.replace("_", "").replace("-", "")


def normalize_build_name(filename):
    sanitized = sanitize_filename(filename)
    if len(sanitized) >= 3 and sanitized.startswith("tm") and sanitized[2].isupper():
        return sanitized[2:]
    return sanitized


def archive_name(path):
    rel_path = path.relative_to(ROOT)
    if not args.sanitize:
        return rel_path.as_posix()

    parts = list(rel_path.parts)
    parts[-1] = sanitize_filename(parts[-1])
    return "/".join(parts)


def zip_directory(src_dir, zip_file):
    for root, _, files in os.walk(src_dir):
        for file in files:
            file_path = Path(root) / file
            zip_file.write(file_path, archive_name(file_path))


def create_op_file():
    top_dir_name = ROOT.name
    base_name = args.overwrite_name if args.overwrite_name else top_dir_name
    op_file_name = normalize_build_name(base_name)
    op_file_name += ".op"

    with zipfile.ZipFile(op_file_name, "w", zipfile.ZIP_DEFLATED) as zipf:
        zip_directory(SRC_DIR, zipf)

        for file in ADDITIONAL_FILES:
            file_path = ROOT / file
            if file_path.exists():
                zipf.write(file_path, archive_name(file_path))

    print(f"Created {op_file_name} successfully.")
    print("Reminder: set logging::S_showDefaultLogs to the default you want before release builds.")


if __name__ == "__main__":
    create_op_file()
