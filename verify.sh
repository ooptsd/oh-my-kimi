#!/usr/bin/env bash
# Verification script for the Kimi omk plugin distribution.
# Resolves PLUGIN from the script's own location so it works regardless of
# where the plugin is cloned or what the user/host is named.
# Exit 0 = all checks pass; non-zero = first failing check.

set -e

PLUGIN="$(cd "$(dirname "$0")" && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

# === Check 1: Top-level structure ===
[ -d "$PLUGIN" ] || fail "plugin root $PLUGIN missing"
[ -f "$PLUGIN/kimi.plugin.json" ] || fail "kimi.plugin.json missing"
[ -f "$PLUGIN/marketplace.json" ] || fail "marketplace.json missing"
[ -d "$PLUGIN/commands" ] || fail "commands/ missing"
[ -d "$PLUGIN/skills" ] || fail "skills/ missing"
[ -d "$PLUGIN/agents" ] || fail "agents/ missing"
[ -d "$PLUGIN/hooks" ] || fail "hooks/ missing"
[ -d "$PLUGIN/scripts" ] || fail "scripts/ missing"
[ -d "$PLUGIN/bridge" ] || fail "bridge/ missing"
[ -f "$PLUGIN/README.md" ] || fail "README.md missing"
[ -f "$PLUGIN/LICENSE" ] || fail "LICENSE missing"
ok "directory skeleton present (check 1)"

# === Check 2: No forbidden runtime artifacts ===
[ -f "$PLUGIN/package.json" ] && fail "package.json should not exist (npm deps user-installed)"
[ -f "$PLUGIN/package-lock.json" ] && fail "package-lock.json should not exist"
[ -d "$PLUGIN/node_modules" ] && fail "node_modules should not exist"
[ -f "$PLUGIN/.gitignore" ] && fail ".gitignore should not exist (VCS artifacts)"
[ -d "$PLUGIN/.claude-plugin" ] && fail ".claude-plugin/ should not exist"
[ -d "$PLUGIN/.zcode-plugin" ] && fail ".zcode-plugin/ should not exist"
[ -d "$PLUGIN/.codebuddy-plugin" ] && fail ".codebuddy-plugin/ should not exist"
ok "no forbidden runtime artifacts (check 2)"

# === Check 3: JSON manifests parse ===
for f in "$PLUGIN/kimi.plugin.json" "$PLUGIN/marketplace.json" "$PLUGIN/hooks/hooks.json"; do
    [ -f "$f" ] || continue
    node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" \
        || fail "$f is not valid JSON"
done
ok "JSON manifests parse (check 3)"

# === Check 4: Component counts ===
skill_count=$(find "$PLUGIN/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
[ "$skill_count" -ne 39 ] && fail "skill count $skill_count != 39"
cmd_count=$(find "$PLUGIN/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$cmd_count" -ne 21 ] && fail "command count $cmd_count != 21"
agent_count=$(find "$PLUGIN/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "$agent_count" -ne 19 ] && fail "agent count $agent_count != 19"
bridge_count=$(find "$PLUGIN/bridge" -maxdepth 1 \( -name '*.cjs' -o -name '*.js' -o -name '*.py' -o -name '*.sh' \) 2>/dev/null | wc -l | tr -d ' ')
[ "$bridge_count" -lt 9 ] && fail "bridge file count $bridge_count < 9"
ok "component counts (check 4): 39 skills / 21 commands / 19 agents / $bridge_count bridge files"

# === Check 5: Hook cross-references ===
node -e "
    const fs = require('fs');
    const path = require('path');
    const hooks = JSON.parse(fs.readFileSync('$PLUGIN/hooks/hooks.json','utf8')).hooks;
    const supported = ['SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','PostToolUse','PostToolUseFailure','Stop','SubagentStart','SubagentStop','PreCompact','SessionEnd'];
    const events = new Set();
    let total = 0;
    for (const h of hooks) {
        if (!supported.includes(h.event)) { console.error('FAIL: unsupported event ' + h.event); process.exit(1); }
        events.add(h.event);
        total++;
        const re = /scripts\/[a-zA-Z0-9_.-]+\.(mjs|cjs)/g;
        const matches = (h.command || '').match(re) || [];
        if (matches.length === 0) { console.error('FAIL: no script path in ' + h.event); process.exit(1); }
        for (const m of matches) {
            const p = path.join('$PLUGIN', m);
            if (!fs.existsSync(p)) { console.error('FAIL: missing script ' + p); process.exit(1); }
        }
        if (h.command.includes('CLAUDE_PLUGIN_ROOT')) { console.error('FAIL: hook command still has CLAUDE_PLUGIN_ROOT'); process.exit(1); }
    }
    if (total !== 25) { console.error('FAIL: hook command total ' + total + ' != 25'); process.exit(1); }
    if (events.size !== 11) { console.error('FAIL: distinct events ' + events.size + ' != 11'); process.exit(1); }
    console.log('ok: ' + total + ' hook commands across ' + events.size + ' events; all scripts exist; no CLAUDE_PLUGIN_ROOT residue');
" || fail "hook cross-reference failed (check 5)"
ok "hook cross-references valid (check 5)"

# === Check 6: Env bridge — no CLAUDE_PLUGIN_ROOT in scripts or bridge ===
remaining=$(grep -rE 'process\.env\.CLAUDE_PLUGIN_ROOT' "$PLUGIN/scripts" "$PLUGIN/bridge" 2>/dev/null | wc -l | tr -d ' ')
[ "$remaining" -eq 0 ] || fail "$remaining CLAUDE_PLUGIN_ROOT references remain in scripts/ or bridge/ (check 6)"
ok "env bridge complete (check 6): 0 CLAUDE_PLUGIN_ROOT in scripts/ + bridge/"

# === Check 7: Agent model field stripped ===
remaining=$(grep -rE '^model: (opus|sonnet|haiku)\s*$' "$PLUGIN/agents" 2>/dev/null | wc -l | tr -d ' ')
[ "$remaining" -eq 0 ] || fail "$remaining model: lines remain in agents/ (check 7)"
ok "agent model fields stripped (check 7): 0 model: opus|sonnet|haiku in agents/"

# === Check 8: MCP bridge integrity ===
[ -f "$PLUGIN/bridge/mcp-server.cjs" ] || fail "bridge/mcp-server.cjs missing"
mcp_args=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$PLUGIN/kimi.plugin.json','utf8')).mcpServers.omk.args[0])")
[ "$mcp_args" = '${KIMI_PLUGIN_ROOT}/bridge/mcp-server.cjs' ] \
    || fail "mcpServers.omk.args[0] = '$mcp_args' (expected \${KIMI_PLUGIN_ROOT}/bridge/mcp-server.cjs) (check 8)"
mcp_env=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$PLUGIN/kimi.plugin.json','utf8')).mcpServers.omk.env.OMC_STATE_DIR)")
[ "$mcp_env" = '${KIMI_PLUGIN_ROOT}/.omc' ] \
    || fail "OMC_STATE_DIR = '$mcp_env' (expected \${KIMI_PLUGIN_ROOT}/.omc) (check 8)"
ok "MCP bridge integrity (check 8): mcp-server.cjs + KIMI_PLUGIN_ROOT substitution + OMC_STATE_DIR"

# === Check 9: Brand residue audit ===
# Functional patterns that MUST still appear (preservation):
for pat in 'OMC_STATE_DIR' 'omcRoot' '<!-- OMC:START' 'omcLspClientManager' 'omc-teams-state.json' 'OMC_PLUGIN_ROOT' '.omc/' 'Yeachan-Heo/oh-my-claudecode'; do
    n=$(grep -rE "$pat" "$PLUGIN/skills" "$PLUGIN/commands" "$PLUGIN/agents" "$PLUGIN/scripts" "$PLUGIN/bridge" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] || fail "lost functional pattern '$pat' (check 9)"
done

# Brand-only patterns that MUST NOT appear (active CLI command keys, no -state suffix).
# Note: omc-teams/omc-help/sciomc are LEGACY retired workflow names preserved per spec §10.1.
for pat in '\bomc-doctor\b' '\bomc-setup\b' '\bomc-plan\b'; do
    n=$(grep -rE "$pat" "$PLUGIN/skills" "$PLUGIN/commands" "$PLUGIN/agents" "$PLUGIN/scripts" "$PLUGIN/bridge" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -eq 0 ] || fail "$n '$pat' (brand key) references remain (check 9)"
done
ok "brand residue audit (check 9): functional identifiers preserved + brand keys removed"

echo "PASS: all 9 verification checks"