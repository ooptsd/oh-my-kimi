---
description: ""
---

# omk-setup (Kimified)

This command keeps `/oh-my-kimi:omk-setup` available without loading the full `omk-setup` skill description in every session.

## Dispatch

1. Read the full bundled skill instructions from the active OMC plugin/install: `skills/omk-setup/SKILL.md`.
2. Follow that SKILL.md exactly, treating the user's arguments as:

```text
$ARGUMENTS
```

If the file is not directly readable from the current working directory, locate it under the active `CLAUDE_PLUGIN_ROOT`/`OMC_PLUGIN_ROOT`, package root, or installed OMC plugin directory, then continue.
