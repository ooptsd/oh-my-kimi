# Oh My Kimi (omk)

Kimi Code CLI plugin that ports the oh-my-claudecode (omc) multi-agent orchestration
system to the Kimi runtime. Rebranded as **omk** (Oh My Kimi), with marketplace
name **omk-plugins**.

This is the third parallel distribution alongside `omz` (ZCode) and `omb`
(CodeBuddy). The source remains `https://github.com/Yeachan-Heo/oh-my-claudecode`.

## Why Kimi

Kimi Code CLI has the broadest hook-event coverage of any of the three target
platforms — all 11 OMC hook events are native, including `SubagentStart`,
`SubagentStop`, `PreCompact`, and `SessionEnd` (which ZCode drops). Kimi also
fully supports plugin `mcpServers` (ZCode does not), so we ship the OMC MCP
server's 57 tools enabled by default.

## Installation

### 1. Install the plugin

Add the marketplace and install omk:

```bash
# From a public GitHub release (after this repo is published)
/plugins marketplace add https://raw.githubusercontent.com/ooptsd/oh-my-kimi/main/marketplace.json
/plugins install omk@omk-plugins
/plugins enable omk
/plugins reload
```

Or install from a local clone (developer testing):

```bash
git clone https://github.com/ooptsd/oh-my-kimi.git
kimi --plugin-dir ./oh-my-kimi
```

### 2. Install npm dependencies for the MCP server (REQUIRED for full functionality)

The OMC MCP server (`bridge/mcp-server.cjs`) bundles `ajv`, `zod`, `chalk`, and
`@modelcontextprotocol/sdk` inline, but it dynamically requires several
optional native + JS deps for full tool coverage. Install them into the plugin
directory:

```bash
# Find your install path (after /plugins install)
/plugins info omk
# → installPath listed under details, typically:
#    ~/.kimi-code/plugins/managed/omk/5.4.0/

PLUGIN_INSTALL=~/.kimi-code/plugins/managed/omk/5.4.0/

# Required (JS deps)
npm install --prefix "$PLUGIN_INSTALL" ajv chalk zod commander jsonc-parser \
  safe-regex vscode-languageserver-protocol @modelcontextprotocol/sdk

# Optional native (skip on systems where build fails)
npm install --prefix "$PLUGIN_INSTALL" @ast-grep/nabi better-sqlite3
```

If you skip Step 2, the MCP server starts but registers a reduced tool set.
Hooks work either way — they only use Node.js stdlib.

### 3. Verify

```bash
plugins info omk       # should show: 39 skills, 21 commands, 19 agents, 11 hooks
mcp                     # should show: mcp__omk__* tools (~57)
```

## What's Included

| Component | Count | Path |
|---|---:|---|
| Skills | 39 | `skills/<name>/SKILL.md` |
| Slash commands | 21 | `commands/<name>.md` (registered as `/omk:<name>`) |
| Subagents | 19 | `agents/<name>.md` |
| Hook events | 11 | `hooks/hooks.json` |
| Hook commands | 25 | flat-array form for Kimi |
| MCP tools | 57 | `bridge/mcp-server.cjs` (default enabled) |
| Marketplace | 1 entry | `omk-plugins` |

## Feature Diff vs Claude Code OMC

- **Slash command namespace**: OMC commands register as `/omc:<name>`; omk
  uses `/omk:<name>`. Use `/omk:plan`, `/omk:execute`, `/omk:review`, etc.
- **MCP server key**: OMC's MCP server is `t`; omk's is `omk`. Tools are
  referenced as `mcp__omk__<tool>` (vs `mcp__t__<tool>` upstream).
- **Agent model field**: OMC's 19 agents declare `model: opus|sonnet|haiku`.
  Kimi's agent schema does not support this field, so the `model:` line is
  removed in omk. All agents run on Kimi's default model.
- **Env var**: OMC reads `CLAUDE_PLUGIN_ROOT`; omk reads `KIMI_PLUGIN_ROOT`
  (Kimi does not inject the legacy alias).
- **Hook config shape**: OMC `hooks/hooks.json` is `{event: [{matcher, hooks}]}`;
  Kimi requires a flat `[{event, matcher, command, timeout}]` array.
- **MCP enabled by default**: omk keeps `mcpServers.omk.enabled=true`. omz/omb
  exclude MCP because ZCode/CodeBuddy have weaker MCP support.

## Hook Events Covered

| Event | matcher | # commands |
|---|---|---:|
| UserPromptSubmit | (empty) | 2 |
| SessionStart | `startup` | 3 |
| SessionStart | `init` | 1 (dead-code on Kimi — matcher not emitted) |
| SessionStart | `maintenance` | 1 (dead-code on Kimi) |
| PreToolUse | (empty) | 1 |
| PermissionRequest | `Bash` | 1 |
| PostToolUse | (empty) | 3 |
| PostToolUseFailure | (empty) | 1 |
| SubagentStart | (empty) | 1 |
| SubagentStop | (empty) | 2 |
| PreCompact | (empty) | 3 |
| Stop | (empty) | 4 |
| SessionEnd | `exit` | 2 |
| **Total** | | **25** |

## Persistence

OMC state files live under the plugin installation path:
- `${KIMI_PLUGIN_ROOT}/.omc/state/` — workflow state machines
- `${KIMI_PLUGIN_ROOT}/.omc/notepad.md` — cross-turn working memory
- `${KIMI_PLUGIN_ROOT}/.omc/project-memory.json` — project-level directives

The MCP server uses `OMC_STATE_DIR=${KIMI_PLUGIN_ROOT}/.omc` for this. If your
plugin directory is read-only after install, edit `kimi.plugin.json`'s
`mcpServers.omk.env.OMC_STATE_DIR` to point to a writable path
(e.g. `$HOME/.omk/`).

## Limitations

- No Kimi-specific hook events (`PostCompact`, `Notification`,
  `PermissionResult`, `SessionHeartbeat`, `TaskStarted`, `StopFailure`,
  `Interrupt`, `TurnStarted`, `UserPromptQueued`) are wired up — they have
  no OMC source scripts to bind.
- No LSP server auto-start (`mcp-server.cjs` will start any LSP that
  `@ast-grep/napi` or `vscode-languageserver-protocol` can locate at request
  time).
- No CI/publish workflow — manual packaging for now.

## License

MIT — same as upstream oh-my-claudecode.