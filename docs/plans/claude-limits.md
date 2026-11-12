# Claude Code limits that can be adjusted

Collected on 2026-11-11 by a docs lookup of Anthropic's official pages (code.claude.com/docs: sub-agents, env-vars, workflows, model-config, settings-reference, claude-code-on-the-web, cloud-environments). "env" means a shell variable or the `env` block of `settings.json`. "None stated" means the page gives no maximum. The settings-reference page was read only in part, so some settings keys may be missing. Check a value against the page before relying on it.

## Subagents

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | subagents running at once | 20 | any positive whole number; none stated | env |
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` | nesting layers below the main conversation | 3 | positive whole number; 1 turns nesting off | env |
| `maxTurns` | turns per subagent | none stated | none stated | agent definition |
| `autoCompactWindow` | where a subagent compacts | none stated | 100,000 to 1,000,000 | agent definition |
| `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` | subagent stall timeout | 600,000 ms | none stated | env |

There is no limit on the total number of subagents in a session.

## Workflows

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` | agents running at once per run | 16 (fewer on few CPUs) | 1 to 256 | env |
| `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` | wait for cache-sharing siblings | 5,000 ms | 0 turns it off | env |
| `workflowSizeGuideline` | agent count Claude aims for (advisory) | medium | unrestricted, small (<5), medium (<10), large (<50) | settings, `/config` |
| `MAX_STRUCTURED_OUTPUT_RETRIES` | attempts for schema-valid output | 5 | none stated | env |

Fixed: 1,000 agents per run; 4,096 items per `parallel()` or `pipeline()` call.

## Tools, MCP and timeouts

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| `BASH_DEFAULT_TIMEOUT_MS` | foreground shell command timeout | 120,000 ms | none stated | env |
| `BASH_MAX_TIMEOUT_MS` | longest timeout the model may ask for | 600,000 ms | none stated | env |
| `BASH_MAX_OUTPUT_LENGTH` | shell output characters read back | 30,000 | at most 150,000 | env |
| `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | file read size | 25,000 tokens | none stated | env |
| `CLAUDE_CODE_GLOB_TIMEOUT_SECONDS` | file search timeout | 20 s | none stated | env |
| `MCP_TIMEOUT` | MCP server start-up | 30,000 ms | none stated | env |
| `MCP_TOOL_TIMEOUT` | MCP tool run time | 100,000,000 ms | none stated | env |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` | MCP tool idle time | 300,000 ms network, 1,800,000 ms local | 0 turns it off; at least 1,000 | env |
| `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS` | when an MCP call moves to the background | 120,000 ms | 0 turns it off | env |
| `MAX_MCP_OUTPUT_TOKENS` | MCP tool response size | 25,000 tokens | none stated | env |
| `CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH` | MCP descriptions sent to the model | 4,096 characters | none stated | env |
| `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` | web searches per session | 200 | none stated | env |
| `CLAUDE_CODE_WEBFETCH_DEADLINE_MS` | web fetch download deadline | 300,000 ms | none stated | env |

## Model output, thinking and compaction

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | output tokens per request | per model | per-model caps | env |
| `MAX_THINKING_TOKENS` | fixed thinking budget | not stated | at least 1,024; below the output cap | env |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | auto-compact window | about 967,000 on 1M models | 100,000 to 1,000,000 | env, `/autocompact`, settings |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | compact trigger, % of window | model default | 1 to 100; can only lower it | env |
| `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` | context size for idle compaction | 200,000 | at least 100,000 | env |
| `fallbackModel` | backup models | unset | at most 3 | settings, `--fallback-model` |
| `promptCacheTtl`, `subagentPromptCacheTtl` | cache lifetime | unset | 5m or 1h | settings |

## Retries and API timeouts

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| `CLAUDE_CODE_MAX_RETRIES` | API retries | 10 | 15 | env |
| `API_TIMEOUT_MS` | wait per attempt | 600,000 ms | 0 means none | env |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | stalled stream watchdog | not stated | at least 300,000 when set | env |
| `CLAUDE_CODE_MAX_TURNS` | agent turns when `--max-turns` is absent | none stated | positive whole number | env |

## Hooks and clean-up

| Setting | Limits | Default | Range | Set in |
|---|---|---|---|---|
| hook `timeout` | run time per hook | 600 s for session-start command hooks | none stated | the hook's entry in settings |
| `cleanupPeriodDays` | transcript retention | not stated | none stated | settings |

## Not adjustable

- Plan usage limits and rate limits: set by the plan; subagents, workflows and cloud sessions all draw on them.
- Context window: 1M or 200K by model. It can be forced down to 200K, never raised.
- Cloud machine: 4 vCPUs, 16 GB memory, 30 GB disk.
- Cloud setup script: its result is cached only if it finishes in about 5 minutes.
- No documented cap on cloud sessions per account, and none in the usage policy on parallel agents.
