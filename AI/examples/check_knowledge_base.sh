#!/bin/sh
# Select an available interpreter; preserve the checker's exit status.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v python3 >/dev/null 2>&1; then
    exec python3 "$script_dir/check_knowledge_base.py"
elif command -v ruby >/dev/null 2>&1; then
    exec ruby "$script_dir/check_knowledge_base.rb"
fi

printf '%s\n' '无法运行知识库检查：未找到 Python 3（python3）或 Ruby（ruby）。' >&2
exit 127
