# Agent Customization Skill

This SKILL documents repository-specific guidance for creating or updating chat customization files.

Principles:
- **Link, don't embed:** Reference existing docs in `docs/` or `AGENTS.md` instead of duplicating them.
- **Minimal by default:** Add only the information an agent cannot easily discover (commands, gotchas, verification steps).
- **Use repo tooling:** Apply changes with `apply_patch` and track multi-step work with `manage_todo_list`.

Workflow for creating/updating customization files:
1. Read `AGENTS.md` and relevant `CLAUDE.md` files.
2. Draft a minimal patch that adds or updates instructions.
3. Submit the patch via `apply_patch`.
4. Update the todo with `manage_todo_list` and mark the verification step `in-progress`.
5. Run containerized tests/commands to verify changes.

When to add files:
- `AGENTS.md` — preferred place for canonical guidance.
- `.github/copilot-instructions.md` — small pointer to `AGENTS.md` for GitHub-integrated agents.
- `.agents/skills/*/SKILL.md` — skill metadata; MUST be read before using that skill.

Keep entries short and focused. Ask for clarification if responsibilities or verification steps are ambiguous.
