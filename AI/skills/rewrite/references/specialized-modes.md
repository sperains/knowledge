# Specialized writing modes

Follow the task and delivery rules in the main skill. Load only the relevant section.

## Bilingual Review Mode

Activate when the user requests bilingual or translation review; mixed terminology alone does not select this mode.

Load `references/write-zh-bilingual.md`. Character-level spacing and punctuation belong to the Punctuation Gate script; this mode owns the judgment half: terminology consistency across all instances, unexplained English left untranslated in Chinese documents, and EN/CN pairs that drift in meaning (mark translation loss instead of silently rewriting one side).

## Product Localization Review Mode

Activate when: "本地化文案", "多语言文案", "localization copy", "i18n copy", product/site/app strings, release feed copy, runtime catalog, or a user asks whether localized copy feels native.

Load `references/write-product-localization.md`. If Chinese is one of the locales, also load `references/write-zh-bilingual.md`.

Default workflow:

1. Separate surfaces first: release feed, website pages, docs/help, runtime strings, legal/privacy copy, and generated pages may have different locale coverage and source files.
2. Preserve factual structure: versions, dates, links, item order, placeholders, and product behavior remain fixed unless the user asks to change them.
3. Review by locale artifacts, not by English meaning alone. Missing accents, ASCII fallbacks, literal possessives, stale locale paths, and mechanical plural or apostrophe errors are first-class issues.
4. After broad cleanup, run a second pass for replacement damage. Do not trust accent sweeps or glossary replacements until the generated output has been checked.
5. When asked to implement, patch the source localization files and rebuild generated pages. When asked only to review, return findings grouped by surface and severity.

## Document Review Mode

Activate only when the user asks to review a document. A document supplied for rewriting stays in editing mode.

Review checklist:
- **Privacy scope**: Check disclosure only for public-release preparation or an explicit privacy review. Flag concrete exposure concerns without blocking ordinary resume or document editing merely because it contains personal or company information.
- **Tone consistency**: Flag voice shifts, register mismatches, formulaic phrasing. Check for AI patterns using the loaded `write-zh.md` or `write-en.md` rules.
- **Bilingual validation**: For CN/EN pairs, confirm translation accuracy and terminology consistency. Apply Bilingual Review Mode rules.
- **Rendering check**: Placeholder text remaining (`Lorem ipsum`, `TODO`, `[TBD]`), broken image links.
- **Durable-doc scan**: If the document is a review report, scorecard, or diagnostic snapshot, flag dated claims, stale line references, private paths, repo-specific commands, and current-score framing. Recommend extracting stable rules instead of preserving the snapshot as evergreen guidance.

Return findings for a review request or edit the file for an implementation request. Report privacy findings only when that check is in scope.

## Paragraph Coherence Mode

Activate when the user asks to diagnose paragraph coherence. If they ask to improve readability or rewrite, apply the edits directly instead.

Do not rewrite. Instead, work through each paragraph in sequence:
1. Flag transitions that abruptly shift topic without a signal.
2. Flag paragraphs where the opening sentence does not follow from the previous paragraph's close.
3. Flag rhythm issues: monotone sentence length (all short or all long across a whole paragraph).
4. Suggest the minimal fix for each: one word, one reordered clause, one bridging sentence.

Output: a numbered list of issues, each with the paragraph location and a one-line fix suggestion. Do not ask again when the user has already requested edits.

## Tweet / Social Post Mode

Activate when: "推特", "twitter", "X推文", "tweet", "social post", "折叠长度", "长文推特", "发文"

Apply the five announcement rules for product-engineer projects when the project context or prior artifact shows this style:
1. **Lead with community**: open with the social anchor (star count, user thanks, whose feedback drove the fix). Changes follow, not lead.
2. **Highlights over completeness**: pick 2 to 4 of the most interesting changes. Dropping whole items is fine.
3. **UX framing**: phrase each point as "你用它的时候..." or "有一种...的感觉", not "这个工具做了...".
4. **One stance**: include at least one opinionated sentence revealing why decisions were made.
5. **Native Chinese rhythm**: use idiomatic phrasing. Avoid translation-sounding terms.

Close casually with an invitation, not a CTA. End with one short sentence inviting readers to try, not "立即升级".

For other engineering projects or English posts, apply the same structure (community lead, highlights, UX framing, one stance, casual close) adapted to the project's voice.
