#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
PROJECTS = ROOT.join("Projects")
ADR_STATUSES = %w[Draft Accepted Deprecated Superseded].freeze
DOCUMENT_STATUSES = %w[draft current archived superseded].freeze
DOCUMENT_TYPES = %w[design plan investigation reference].freeze
REQUIRED_DOCUMENT_FIELDS = %w[title type status date updated project owner related].freeze
REQUIRED_ADR_SECTIONS = [
  "背景（Context）",
  "考虑方案（Options）",
  "决策（Decision）",
  "后果（Consequences）",
  "相关文档",
  "AI 指导原则"
].freeze

errors = []
warnings = []

def without_code(text)
  text.gsub(/```.*?```/m, "").gsub(/`[^`\n]*`/, "")
end

def frontmatter(text)
  match = text.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  match && match[1]
end

def field_value(metadata, field)
  metadata[/^#{Regexp.escape(field)}:\s*(.*)$/, 1]&.strip
end

theme_documents = PROJECTS.glob("*/*.md").reject { |path| path.basename.to_s == "MOC.md" }

theme_documents.each do |path|
  text = path.read
  metadata = frontmatter(text)
  unless metadata
    errors << "主题文档缺少 YAML 元信息：#{path.relative_path_from(ROOT)}"
    next
  end

  REQUIRED_DOCUMENT_FIELDS.each do |field|
    errors << "主题文档缺少 #{field}：#{path.relative_path_from(ROOT)}" unless metadata.match?(/^#{Regexp.escape(field)}:/)
  end

  type = field_value(metadata, "type")
  status = field_value(metadata, "status")
  errors << "主题文档 type 非法：#{path.relative_path_from(ROOT)}（#{type}）" unless DOCUMENT_TYPES.include?(type)
  errors << "主题文档 status 非法：#{path.relative_path_from(ROOT)}（#{status}）" unless DOCUMENT_STATUSES.include?(status)

  %w[source_repo source_ref].each do |field|
    value = field_value(metadata, field)
    warnings << "主题文档 #{field} 待补充：#{path.relative_path_from(ROOT)}" if value.nil? || value.empty? || value == '""'
  end
end

PROJECTS.glob("*/ADR/ADR-*.md").each do |path|
  text = path.read
  relative = path.relative_path_from(ROOT)
  status = text[/^- 状态：(\S+)$/, 1]

  errors << "ADR 状态非法：#{relative}（#{status || '缺失'}）" unless ADR_STATUSES.include?(status)
  errors << "ADR 缺少日期：#{relative}" unless text.match?(/^- 日期：\d{4}-\d{2}-\d{2}$/)
  errors << "ADR 缺少作者：#{relative}" unless text.match?(/^- 作者：\S.+$/)
  errors << "ADR 缺少相关领域：#{relative}" unless text.match?(/^- 相关领域：\S.+$/)
  errors << "ADR 缺少所属项目：#{relative}" unless text.match?(/^- 所属项目：\S.+$/)

  REQUIRED_ADR_SECTIONS.each do |section|
    errors << "ADR 缺少章节“#{section}”：#{relative}" unless text.match?(/^## #{Regexp.escape(section)}$/)
  end
end

ROOT.glob("**/*.md").reject { |path| path.to_s.include?("/.git/") || path.to_s.include?("/Templates/") }.each do |path|
  text = without_code(path.read)
  text.scan(/\[\[([^\]]+)\]\]/).flatten.each do |raw|
    target = raw.split("|", 2).first.split("#", 2).first
    next if target.empty?

    resolved = path.dirname.join(target).cleanpath
    next if resolved.file? || Pathname.new("#{resolved}.md").file? || resolved.directory?

    errors << "失效链接：#{path.relative_path_from(ROOT)} -> #{raw}"
  end
end

PROJECTS.children.select(&:directory?).each do |project_dir|
  moc = project_dir.join("MOC.md")
  unless moc.file?
    errors << "项目缺少 MOC：#{project_dir.relative_path_from(ROOT)}"
    next
  end

  moc_text = moc.read
  project_dir.glob("*.md").reject { |path| path.basename.to_s == "MOC.md" }.each do |path|
    name = path.basename(".md").to_s
    errors << "项目 MOC 未收录：#{path.relative_path_from(ROOT)}" unless moc_text.include?("[[#{name}")
  end

  adr_dir = project_dir.join("ADR")
  next unless adr_dir.directory?

  adr_moc = adr_dir.join("MOC.md")
  unless adr_moc.file?
    errors << "ADR 目录缺少 MOC：#{adr_dir.relative_path_from(ROOT)}"
    next
  end

  adr_moc_text = adr_moc.read
  adr_dir.glob("ADR-*.md").each do |path|
    name = path.basename(".md").to_s
    errors << "ADR MOC 未收录：#{path.relative_path_from(ROOT)}" unless adr_moc_text.include?("[[#{name}")
  end
end

puts "知识库检查：#{theme_documents.length} 篇主题文档，#{PROJECTS.glob('*/ADR/ADR-*.md').length} 篇 ADR"

warnings.uniq.sort.each { |message| puts "警告：#{message}" }
errors.uniq.sort.each { |message| puts "错误：#{message}" }

if errors.empty?
  puts "检查通过：未发现结构、ADR、导航或链接错误。"
  exit 0
end

puts "检查失败：#{errors.uniq.length} 个错误，#{warnings.uniq.length} 个警告。"
exit 1
