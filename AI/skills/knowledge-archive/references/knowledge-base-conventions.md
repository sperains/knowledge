# Knowledge-base conventions

This reference is a portable default, not a replacement for repository-local rules.

## Suggested mapping

| Information | Preferred destination |
| --- | --- |
| Long-term architecture choice or trade-off | `ADR/` |
| Stable design, schema, or workflow | Project design or global conventions document |
| Completed work on a specific date | `Daily/YYYY/MM/` or the host's daily-record location |
| Reusable AI prompt | `AI/prompts/` |
| Reusable agent procedure | `AI/skills/<skill-name>/` |
| Unresolved decision | Existing pending-decisions section or issue tracker |

## Portable path rules

- Prefer paths relative to the knowledge-base root in prose and links.
- Use the repository's established link syntax; do not assume Markdown or a particular note application.
- When moving a document, search for references to its old path and repair only the affected links.
- Preserve the language, date format, naming style, and heading structure already used by the knowledge base.

## Minimal decision shape

When no local template exists, use:

```markdown
# Decision title

## Context

## Decision

## Reasons

## Consequences

## Status

## Open questions
```
