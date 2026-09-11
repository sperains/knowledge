---
name: rewrite
description: Rewrites and polishes prose in Chinese or English, removes AI-like wording, and reviews product localization copy while preserving intent for drafts, docs, release notes, launch copy, and social posts. Use when users ask in any language to draft, rewrite, proofread, localize, polish release notes, remove AI-like wording, or prepare launch and social copy. Not for code comments, commit messages, or inline docs.
metadata:
  version: "1.0.1"
  when_to_use: "帮我写, 改稿, 润色, 去 AI 味, 写一段, 审稿, 文档审校, 本地化文案, 多语言文案, 推特, 社交文案, 段落连贯, 草稿, 文本编辑, 校对, 自然表达, 润色, 改写"
  dispatch_intent: "Writing, editing prose, polish, release notes, launch/social copy, remove AI tone"
  description_zh: "去除文本中的 AI 味，把稿件改写得更自然、像人写的。支持中英文润色、去 AI 味、发布说明、社交文案、产品本地化审校与长文结构打磨，保留原意与作者语气，不做过度修饰。"
  description_en: "Strip AI patterns from prose and rewrite it to sound human. Supports Chinese/English polishing, de-AI rewriting, release notes, social copy, product localization review, and long-form structural editing while preserving meaning and author voice without over-editing."
  visibility: "public"
---

# Rewrite prose

## Task and source

Follow the requested action: rewrite or improve means edit; review means report findings. Words such as “document” or “readability” do not turn an editing request into a review.

Use text supplied in the message, an identified file, earlier conversation, or a draft produced by the main task. Read an identified source before asking for it. Ask only when the target cannot be located or a missing audience or constraint would materially change the result. Drafting may proceed from sufficient facts; never invent personal experience or product claims.

When paired with another skill, that task owns factual scope, document structure, file operations, and delivery. Rewrite improves expression within those boundaries. For report, do not expand the date range, gather extra work, or insert implementation and verification details.

## Editing principles

- Preserve meaning, facts, the author's voice, and deliberate genre choices. Leave natural sentences alone; cut repetition before replacing wording. Pattern lists are examples, not mandatory substitutions.
- Keep headings, order, metadata, links, placeholders, and examples unless structural editing is requested. A request to shorten permits removing redundant prose, not silently dropping independent facts or structural assets. Explain material structural removals when applicable.
- Ground new factual claims in supplied material or current artifacts. Do not invent first-person experiences, examples, or release capabilities. Consult an available writing sample when matching a specific author's voice; its absence alone does not block a draft from sufficient material.
- Match length to the request and surface. Do not add summaries, promotional framing, or fixed emoji prefixes. Avoid em and en dashes in edited prose; preserve literal code and link targets.

## References

Load only what the task needs. Reference examples and format advice remain subordinate to the user's requested action and the delivery rules below.

| Task | Reference |
| --- | --- |
| Ordinary Chinese prose | `references/write-zh-prose.md`; consult `references/write-zh.md` only for a specific unresolved style problem |
| English prose | `references/write-en.md` |
| Release notes | `references/mode-release-notes.md`; add `references/write-zh-release-notes.md` for Chinese |
| Public issue or PR reply | `references/mode-public-reply.md` |
| Long text requiring structural editing | `references/mode-long-form.md` |
| Bilingual review | Bilingual section of `references/specialized-modes.md` and `references/write-zh-bilingual.md` |
| Product localization | Localization section of `references/specialized-modes.md` and `references/write-product-localization.md`; add the bilingual guide for Chinese |
| Document review, coherence diagnosis, or social copy | Relevant section of `references/specialized-modes.md` |

## Punctuation check

Check the edited prose with `scripts/check-punctuation.sh --lang <zh|en|ja|auto> <file>` from this skill directory. The script also accepts stdin. In an inlined package, resolve it under `skills/rewrite/scripts/` instead. If unavailable, inspect punctuation manually and report that automated checking was unavailable rather than claiming it passed.

For a file rewrite, check the target text. For append-only logs or a narrow edit, check the changed fragment; do not clean up unrelated historical content to satisfy the checker. It exempts code, URLs, and Markdown or wiki link targets while checking explicit visible labels. Preserve link targets and verify their validity separately when editing files. Use an explicit language for mixed-language prose. `--fix` prints conservative fixes to stdout; inspect them before applying.

## Delivery

- Chat rewrite: return the edited prose, with notes only when requested or needed to disclose a material limitation or structural removal.
- File edit: write the requested changes and briefly report the result and file location. Preserve unrelated work and follow repository logging and verification rules.
- Review: return actionable findings, without silently editing files.
- Combined task: follow the main task's delivery format; do not replace a file-editing workflow with a prose-only response.

## Source and installed copy

The Knowledge skill is the maintained source. After an authorized skill update, synchronize its changed files to the installed copy before relying on the new behavior. This does not authorize commits or publication.
