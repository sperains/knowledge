#!/usr/bin/env python3
"""Check knowledge base documents with the same rules as the Ruby version."""

import glob
import os
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
PROJECTS = ROOT / "Projects"
ADR_STATUSES = {"Draft", "Accepted", "Deprecated", "Superseded"}
DOCUMENT_STATUSES = {"draft", "current", "archived", "superseded"}
DOCUMENT_TYPES = {"design", "plan", "investigation", "reference"}
REQUIRED_DOCUMENT_FIELDS = (
    "title", "type", "status", "date", "updated", "project", "owner", "related"
)
REQUIRED_ADR_SECTIONS = (
    "背景（Context）", "考虑方案（Options）", "决策（Decision）",
    "后果（Consequences）", "相关文档", "AI 指导原则"
)


def matching_paths(directory, pattern):
    return [Path(path) for path in glob.glob(str(directory / pattern), recursive=True)]


def read_text(path):
    return path.read_bytes().decode("utf-8")


def field_value(metadata, field):
    match = re.search(rf"^{re.escape(field)}:\s*(.*)$", metadata, re.MULTILINE)
    return match.group(1).strip() if match else None


def without_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    return re.sub(r"`[^`\n]*`", "", text)


def main():
    errors = []
    warnings = []
    theme_documents = [
        path for path in matching_paths(PROJECTS, "*/*.md") if path.name != "MOC.md"
    ]
    adr_documents = matching_paths(PROJECTS, "*/ADR/ADR-*.md")

    for path in theme_documents:
        text = read_text(path)
        relative = path.relative_to(ROOT)
        match = re.search(r"\A---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
        if not match:
            errors.append(f"主题文档缺少 YAML 元信息：{relative}")
            continue
        metadata = match.group(1)

        for field in REQUIRED_DOCUMENT_FIELDS:
            if not re.search(rf"^{re.escape(field)}:", metadata, re.MULTILINE):
                errors.append(f"主题文档缺少 {field}：{relative}")

        document_type = field_value(metadata, "type")
        status = field_value(metadata, "status")
        if document_type not in DOCUMENT_TYPES:
            errors.append(f"主题文档 type 非法：{relative}（{document_type or ''}）")
        if status not in DOCUMENT_STATUSES:
            errors.append(f"主题文档 status 非法：{relative}（{status or ''}）")

        for field in ("source_repo", "source_ref"):
            if field_value(metadata, field) in (None, "", '""'):
                warnings.append(f"主题文档 {field} 待补充：{relative}")

    for path in adr_documents:
        text = read_text(path)
        relative = path.relative_to(ROOT)
        match = re.search(r"^- 状态：(\S+)$", text, re.MULTILINE)
        status = match.group(1) if match else None
        if status not in ADR_STATUSES:
            errors.append(f"ADR 状态非法：{relative}（{status or '缺失'}）")

        required_patterns = (
            ("日期", r"^- 日期：\d{4}-\d{2}-\d{2}$"),
            ("作者", r"^- 作者：\S.+$"),
            ("相关领域", r"^- 相关领域：\S.+$"),
            ("所属项目", r"^- 所属项目：\S.+$"),
        )
        for field, pattern in required_patterns:
            if not re.search(pattern, text, re.MULTILINE):
                errors.append(f"ADR 缺少{field}：{relative}")
        for section in REQUIRED_ADR_SECTIONS:
            if not re.search(rf"^## {re.escape(section)}$", text, re.MULTILINE):
                errors.append(f"ADR 缺少章节“{section}”：{relative}")

    for path in matching_paths(ROOT, "**/*.md"):
        if "/.git/" in path.as_posix() or "/Templates/" in path.as_posix():
            continue
        for raw in re.findall(r"\[\[([^\]]+)\]\]", without_code(read_text(path))):
            target = raw.split("|", 1)[0].split("#", 1)[0]
            if not target:
                continue
            resolved = Path(os.path.normpath(path.parent / target))
            if resolved.is_file() or Path(f"{resolved}.md").is_file() or resolved.is_dir():
                continue
            errors.append(f"失效链接：{path.relative_to(ROOT)} -> {raw}")

    for project_dir in PROJECTS.iterdir():
        if not project_dir.is_dir():
            continue
        moc = project_dir / "MOC.md"
        if not moc.is_file():
            errors.append(f"项目缺少 MOC：{project_dir.relative_to(ROOT)}")
            continue
        moc_text = read_text(moc)
        for path in matching_paths(project_dir, "*.md"):
            if path.name != "MOC.md" and f"[[{path.stem}" not in moc_text:
                errors.append(f"项目 MOC 未收录：{path.relative_to(ROOT)}")

        adr_dir = project_dir / "ADR"
        if not adr_dir.is_dir():
            continue
        adr_moc = adr_dir / "MOC.md"
        if not adr_moc.is_file():
            errors.append(f"ADR 目录缺少 MOC：{adr_dir.relative_to(ROOT)}")
            continue
        adr_moc_text = read_text(adr_moc)
        for path in matching_paths(adr_dir, "ADR-*.md"):
            if f"[[{path.stem}" not in adr_moc_text:
                errors.append(f"ADR MOC 未收录：{path.relative_to(ROOT)}")

    print(f"知识库检查：{len(theme_documents)} 篇主题文档，{len(adr_documents)} 篇 ADR")
    for message in sorted(set(warnings)):
        print(f"警告：{message}")
    for message in sorted(set(errors)):
        print(f"错误：{message}")
    if not errors:
        print("检查通过：未发现结构、ADR、导航或链接错误。")
        return 0
    print(f"检查失败：{len(set(errors))} 个错误，{len(set(warnings))} 个警告。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
