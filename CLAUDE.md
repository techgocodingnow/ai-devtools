<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **ai-devtools** (2204 symbols, 5090 relationships, 84 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/ai-devtools/context` | Codebase overview, check index freshness |
| `gitnexus://repo/ai-devtools/clusters` | All functional areas |
| `gitnexus://repo/ai-devtools/processes` | All execution flows |
| `gitnexus://repo/ai-devtools/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

<!-- PERPLEXITY-MCP-START -->
# Perplexity MCP Server

## Available Tools

- **perplexity_search** — Fast web search with source citations. Use for quick factual lookups. Works with or without authentication.
- **perplexity_reason** — Step-by-step reasoning with web context. Requires Pro account.
- **perplexity_research** — Deep multi-section research reports (30-120s). Requires Pro account.
- **perplexity_ask** — Flexible queries with explicit model/mode/follow-up control.
- **perplexity_compute** — ASI/Computer mode for complex multi-step tasks. Requires Max account.
- **perplexity_models** — List available models, account tier, and rate limits.
- **perplexity_retrieve** — Poll results from pending research/compute tasks.
- **perplexity_export** — Export a saved history entry as PDF, markdown, or DOCX. Uses Perplexity's native export when available.
- **perplexity_sync_cloud** — Sync Perplexity cloud history into the local history store.
- **perplexity_hydrate_cloud_entry** — Hydrate a single cloud-backed history entry by id.
- **perplexity_list_researches** — List saved research history with status.
- **perplexity_get_research** — Fetch full content of a saved research.
- **perplexity_login** — Open browser for Perplexity authentication.
- **perplexity_doctor** — Run diagnostic checks against your Perplexity MCP install. Returns a Markdown report; pass probe:true for a live search probe.

## Usage Guidelines

1. **Start with perplexity_search** for quick questions. Only escalate to research or reason when depth is needed.
2. **Check rate limits** with perplexity_models before batch operations.
3. **Always cite sources** from search results in your responses.
4. **For multi-turn conversations**, pass the follow_up_context JSON from perplexity_ask responses back in subsequent calls.
5. **Long-running research**: perplexity_compute may time out. Use perplexity_retrieve with the returned research_id to poll for results.
6. **Language parameter**: Defaults to en-US. Set explicitly for non-English queries.

## Model Selection

| Tool | Default Model | Best For |
|------|--------------|----------|
| perplexity_search | pplx_pro | General web search |
| perplexity_reason | claude46sonnetthinking | Step-by-step analysis |
| perplexity_research | pplx_alpha | Deep research reports |
| perplexity_compute | pplx_asi | Complex multi-step tasks |
<!-- PERPLEXITY-MCP-END -->
