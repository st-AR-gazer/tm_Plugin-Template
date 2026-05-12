import argparse
import bisect
import os
import re
from pathlib import Path

parser = argparse.ArgumentParser(description="Process log statements in code files.")
parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output of all log modifications.")
args = parser.parse_args()

default_params = ['""', "LogLevel::Info", "-1", '""']

function_pattern = re.compile(
    r"(void|int|uint|int8|uint8|int16|uint16|int64|uint64|float|double|bool|string|wstring|"
    r"vec2|vec3|vec4|int2|int3|nat2|nat3|iso3|mat3|iso4|mat4|quat|RGBAColor|MemoryBuffer|"
    r"DataRef|CMwStack|MwId|MwSArray|MwStridedArray|MwFastArray|MwFastBuffer|MwFastBufferCat|"
    r"MwRefBuffer|MwNodPool|MwVirtualArray|array<[^>]*>|enum\w*|dictionaryValue|dictionary|ref)"
    r"\s+(\w+)\s*\(([^)]*)\)\s*\{"
)
namespace_pattern = re.compile(r"\bnamespace\s+(\w+)\b")

skip_files = {
    Path("src/runtime/logging.as").as_posix().lower(),
    Path("src/toolkit/logging.as").as_posix().lower(),
}

skip_file_names = {
    "logging.as",
}


def sanitize_code(text):
    sanitized = []
    in_string = False
    in_line_comment = False
    in_block_comment = False
    index = 0

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if in_string:
            if char == "\\" and next_char:
                sanitized.append(" ")
                index += 1
                sanitized.append("\n" if text[index] == "\n" else " ")
            else:
                sanitized.append("\n" if char == "\n" else " ")
                if char == '"':
                    in_string = False
        elif in_line_comment:
            sanitized.append("\n" if char == "\n" else " ")
            if char == "\n":
                in_line_comment = False
        elif in_block_comment:
            sanitized.append("\n" if char == "\n" else " ")
            if char == "*" and next_char == "/":
                index += 1
                sanitized.append(" ")
                in_block_comment = False
        else:
            if char == "/" and next_char == "/":
                sanitized.append(" ")
                index += 1
                sanitized.append(" ")
                in_line_comment = True
            elif char == "/" and next_char == "*":
                sanitized.append(" ")
                index += 1
                sanitized.append(" ")
                in_block_comment = True
            elif char == '"':
                sanitized.append(" ")
                in_string = True
            else:
                sanitized.append(char)

        index += 1

    return "".join(sanitized)


def get_namespace_path(lines, index):
    namespace_stack = []
    pending_namespaces = []
    brace_depth = 0

    for i in range(index + 1):
        line = lines[i]
        namespace_matches = list(namespace_pattern.finditer(line))
        next_namespace_index = 0
        position = 0

        while position < len(line):
            if next_namespace_index < len(namespace_matches) and position == namespace_matches[next_namespace_index].start():
                pending_namespaces.append(namespace_matches[next_namespace_index].group(1))
                position = namespace_matches[next_namespace_index].end()
                next_namespace_index += 1
                continue

            char = line[position]

            if char == "{":
                brace_depth += 1
                if pending_namespaces:
                    namespace_stack.append((pending_namespaces.pop(0), brace_depth))
            elif char == "}":
                while namespace_stack and namespace_stack[-1][1] == brace_depth:
                    namespace_stack.pop()
                brace_depth = max(0, brace_depth - 1)

            position += 1

    return [name for name, _ in namespace_stack]


def get_function_name(lines, index):
    for i in range(index, -1, -1):
        match = function_pattern.search(lines[i])
        if match:
            namespace_path = get_namespace_path(lines, i)
            function_name = match.group(2)
            if namespace_path:
                return "::".join(namespace_path + [function_name])
            return function_name
    return "UnknownFunction"


def skip_whitespace(text, index):
    while index < len(text) and text[index].isspace():
        index += 1
    return index


def skip_whitespace_and_comments(text, index):
    while index < len(text):
        if text[index].isspace():
            index += 1
            continue

        if text.startswith("//", index):
            newline_index = text.find("\n", index)
            if newline_index == -1:
                return len(text)
            index = newline_index + 1
            continue

        if text.startswith("/*", index):
            comment_end = text.find("*/", index + 2)
            if comment_end == -1:
                raise ValueError("Unterminated block comment.")
            index = comment_end + 2
            continue

        break

    return index


def build_line_starts(text):
    line_starts = [0]
    for index, char in enumerate(text):
        if char == "\n":
            line_starts.append(index + 1)
    return line_starts


def line_number_from_position(position, line_starts):
    return bisect.bisect_right(line_starts, position)


def get_line_indentation(text, position):
    line_start = text.rfind("\n", 0, position) + 1
    indent_end = line_start
    while indent_end < len(text) and text[indent_end] in (" ", "\t"):
        indent_end += 1
    return text[line_start:indent_end]


def find_matching_paren(text, open_paren_index):
    nested_level = 1
    in_string = False
    in_line_comment = False
    in_block_comment = False
    index = open_paren_index + 1

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if in_string:
            if char == "\\" and next_char:
                index += 2
                continue
            if char == '"':
                in_string = False
        elif in_line_comment:
            if char == "\n":
                in_line_comment = False
        elif in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
                continue
        else:
            if char == "/" and next_char == "/":
                in_line_comment = True
                index += 2
                continue
            if char == "/" and next_char == "*":
                in_block_comment = True
                index += 2
                continue
            if char == '"':
                in_string = True
            elif char == "(":
                nested_level += 1
            elif char == ")":
                nested_level -= 1
                if nested_level == 0:
                    return index

        index += 1

    raise ValueError("Invalid log syntax.")


def find_log_statements(text):
    statements = []
    errors = []
    in_string = False
    in_line_comment = False
    in_block_comment = False
    index = 0

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if in_string:
            if char == "\\" and next_char:
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
            index += 1
            continue

        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
                continue
            index += 1
            continue

        if char == "/" and next_char == "/":
            in_line_comment = True
            index += 2
            continue

        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue

        if char == '"':
            in_string = True
            index += 1
            continue

        if text.startswith("log", index):
            prev_char = text[index - 1] if index > 0 else ""
            if prev_char.isalnum() or prev_char in ("_", ".", ":"):
                index += 1
                continue

            open_paren_index = skip_whitespace(text, index + 3)
            if open_paren_index >= len(text) or text[open_paren_index] != "(":
                index += 1
                continue

            try:
                close_paren_index = find_matching_paren(text, open_paren_index)
                next_token_index = skip_whitespace_and_comments(text, close_paren_index + 1)

                if next_token_index < len(text) and text[next_token_index] == ";":
                    statements.append((index, open_paren_index, close_paren_index, next_token_index))
                    index = next_token_index + 1
                    continue

                if next_token_index < len(text) and text[next_token_index] == "{":
                    index = close_paren_index + 1
                    continue

                raise ValueError("Invalid log syntax.")
            except ValueError as error:
                errors.append((index, str(error)))

        index += 1

    return statements, errors


def parse_params(log_content):
    params = []
    temp = []
    nested_parens = 0
    nested_brackets = 0
    nested_braces = 0
    in_string = False
    in_line_comment = False
    in_block_comment = False
    index = 0

    while index < len(log_content):
        char = log_content[index]
        next_char = log_content[index + 1] if index + 1 < len(log_content) else ""

        if in_string:
            temp.append(char)
            if char == "\\" and next_char:
                index += 1
                temp.append(log_content[index])
            elif char == '"':
                in_string = False
        elif in_line_comment:
            temp.append(char)
            if char == "\n":
                in_line_comment = False
        elif in_block_comment:
            temp.append(char)
            if char == "*" and next_char == "/":
                index += 1
                temp.append(log_content[index])
                in_block_comment = False
        else:
            if char == "/" and next_char == "/":
                temp.append(char)
                index += 1
                temp.append(log_content[index])
                in_line_comment = True
            elif char == "/" and next_char == "*":
                temp.append(char)
                index += 1
                temp.append(log_content[index])
                in_block_comment = True
            elif char == '"':
                in_string = True
                temp.append(char)
            elif char == "(":
                nested_parens += 1
                temp.append(char)
            elif char == ")":
                nested_parens -= 1
                temp.append(char)
            elif char == "[":
                nested_brackets += 1
                temp.append(char)
            elif char == "]":
                nested_brackets -= 1
                temp.append(char)
            elif char == "{":
                nested_braces += 1
                temp.append(char)
            elif char == "}":
                nested_braces -= 1
                temp.append(char)
            elif char == "," and nested_parens == 0 and nested_brackets == 0 and nested_braces == 0:
                params.append("".join(temp).strip())
                temp = []
            else:
                temp.append(char)

        index += 1

    final_param = "".join(temp).strip()
    if final_param:
        params.append(final_param)

    if in_string or in_line_comment or in_block_comment or nested_parens != 0 or nested_brackets != 0 or nested_braces != 0:
        raise ValueError("Malformed statement detected in log parameters.")

    return params


def clean_and_update_params(params, line_number, analysis_lines):
    while len(params) < 4:
        params.append(default_params[len(params)])

    params[2] = str(line_number)
    params[3] = f'"{get_function_name(analysis_lines, line_number - 1)}"'

    if "LogLevel::" not in params[1]:
        params[1] = "LogLevel::Info"

    return params


def format_log_statement(params, original_statement, text, start_index):
    if "\n" not in original_statement:
        return f'log({", ".join(params)});'

    indent = get_line_indentation(text, start_index)
    inner_indent = indent + "    "
    joined_params = ",\n".join(f"{inner_indent}{param}" for param in params)
    return f"log(\n{joined_params}\n{indent});"


def modify_log_statements(file_path, verbose):
    with open(file_path, "r", encoding="utf-8") as file:
        content = file.read()

    analysis_lines = sanitize_code(content).splitlines()
    line_starts = build_line_starts(content)
    statements, errors = find_log_statements(content)

    for position, error in errors:
        line_number = line_number_from_position(position, line_starts)
        print(f"\033[31mError in {file_path} on line {line_number}: {error}\033[0m")

    if not statements:
        return False

    updated_chunks = []
    last_index = 0
    modified = False

    for start_index, open_paren_index, close_paren_index, semicolon_index in statements:
        line_number = line_number_from_position(start_index, line_starts)
        original_statement = content[start_index:semicolon_index + 1]

        try:
            params = parse_params(content[open_paren_index + 1:close_paren_index])
            updated_params = clean_and_update_params(params, line_number, analysis_lines)
            new_statement = format_log_statement(updated_params, original_statement, content, start_index)
        except ValueError as error:
            print(f"\033[31mError in {file_path} on line {line_number}: {error}\033[0m")
            continue

        updated_chunks.append(content[last_index:start_index])
        updated_chunks.append(new_statement)
        last_index = semicolon_index + 1

        if new_statement != original_statement:
            modified = True
            if verbose:
                print(f"Updated log call in {file_path} on line {line_number}: {new_statement}")

    if not updated_chunks:
        return False

    updated_chunks.append(content[last_index:])
    updated_content = "".join(updated_chunks)

    if modified:
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(updated_content)

    return modified


def should_skip(file_path):
    rel_path = Path(os.path.relpath(file_path, Path.cwd())).as_posix().lower()
    return rel_path in skip_files or Path(file_path).name.lower() in skip_file_names


def process_directory(directory, verbose):
    include_extensions = {".as"}
    exclude_extensions = {".dll", ".exe", ".bin"}

    for root, _, files in os.walk(directory):
        for file in files:
            ext = os.path.splitext(file)[1]
            file_path = os.path.join(root, file)

            if should_skip(file_path):
                if verbose:
                    print(f"Skipping file: {file_path}")
                continue

            if ext in include_extensions and ext not in exclude_extensions:
                if modify_log_statements(file_path, verbose):
                    if verbose:
                        print(f"Found and updated instances in: {file_path}")
            elif verbose:
                print(f"Skipping file: {file_path}")


if __name__ == "__main__":
    process_directory("./src", args.verbose)
