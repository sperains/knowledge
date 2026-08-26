---
name: open-source-readme
description: Design, rewrite, or review professional README files for open-source repositories. Use when a user asks to beautify a README, improve a GitHub project page, clarify project positioning, add credible badges, create a quick start, organize installation and usage documentation, synchronize multilingual READMEs, or evaluate whether repository documentation supports adoption without overstating capabilities.
---

# Open Source README

Treat the README as a product landing page backed by repository evidence. Optimize for comprehension and adoption before decoration.

## Audit the repository

Read the current README completely. Inspect the license, release workflow, package metadata, commands, examples, contribution guide, security policy, screenshots, and linked documentation that support public claims.

Record these facts before editing:

- Primary user and job to be done
- One-sentence product category and differentiator
- Supported platforms and installation channels
- Smallest successful user journey
- Proven capabilities and explicit limitations
- Project maturity, license, CI, release, and localization state
- Existing visual assets and documentation destinations

Never infer a feature from a plan, issue, changelog proposal, or unused code path. Use current behavior and published artifacts as evidence.

## Design the information hierarchy

Prefer this order, adapting it to the project rather than forcing every section:

1. Project name, one-line promise, and one concise explanation
2. Essential badges only
3. Product demonstration when a real visual asset exists
4. The problem solved and key reasons to use the project
5. Installation and a three-to-five-step quick start
6. How the core workflow behaves and stays safe
7. Requirements, supported scope, and important limitations
8. Documentation, contributing, security, language, and license links

Make the first screen answer: what is this, who is it for, why should I trust it, and what do I do next?

## Write for scanning

- Lead sections with the outcome, then add necessary explanation.
- Keep paragraphs short and convert repeated constraints or comparisons into compact lists or tables.
- Show copyable commands that form one coherent path; do not scatter unrelated examples.
- Link detailed operational guidance instead of duplicating it in the README.
- Keep headings concrete and user-oriented.
- Preserve the project's established voice and vocabulary.
- Avoid generic marketing claims such as “powerful,” “blazing fast,” or “enterprise-ready” unless measured or substantiated.
- Avoid excessive emoji, centered HTML, decorative separators, and badge walls.

## Use badges responsibly

Include only badges that answer a real adoption question, usually CI status, latest release, license, or supported language/runtime. Link badges to their relevant page. Verify repository owner, workflow name, default branch, and license before generating badge URLs. Do not add social-count or quality-score badges by default.

## Handle visuals

Reuse an existing current screenshot or recording when it materially explains the product. Do not fabricate terminal output or present a mockup as proof of current behavior. If no durable asset exists, leave a clear visual opportunity for later instead of embedding temporary local files.

## Maintain multilingual READMEs

Keep positioning, quick-start steps, commands, limitations, links, and feature claims semantically aligned across languages. Write naturally in each language rather than translating word for word. Put the language switch near the top and make it reciprocal.

## Validate before finishing

Check all of the following:

- Every relative link resolves to a tracked file.
- Every badge URL targets the correct repository and workflow.
- Commands and flags exist in the current CLI or package.
- Installation examples match published asset names and supported platforms.
- No secret, private host, local absolute path, or personal configuration is exposed.
- Capabilities and maturity claims match repository evidence.
- Multilingual READMEs contain the same critical facts.
- Markdown headings, blank lines, fences, tables, and anchors render correctly on GitHub.
- The README remains useful without images or badges.

Summarize the new information architecture, important omitted claims, and any missing visual asset that would materially improve adoption.
