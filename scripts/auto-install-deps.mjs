#!/usr/bin/env node

/**
 * SessionStart hook: keep the omk MCP server fully functional without asking
 * the user to read the README.
 *
 * bridge/mcp-server.cjs boots and serves state READS with zero npm deps, but
 * state WRITES go through a sqlite-backed mutation lock and need the optional
 * native package better-sqlite3. On the first session start this hook spawns
 * a detached `npm install` into <pluginRoot>/.omc-deps so the next session
 * has full capability. bridge/mcp-launcher.cjs resolves that directory.
 *
 * Constraints honored here:
 *   - never block the hook: the npm child is detached, unref'd, and runs in
 *     its own process group so the run.cjs hook reaper cannot kill it;
 *   - never write into the plugin root itself (verify.sh forbids root-level
 *     package.json / package-lock.json / node_modules);
 *   - never retry-spam offline machines: a marker file backs off retries.
 */

import { spawn } from 'child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { createRequire } from 'module';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pluginRoot = process.env.KIMI_PLUGIN_ROOT || join(__dirname, '..');
const depsDir = join(pluginRoot, '.omc-deps');
const markerPath = join(depsDir, '.auto-install-state.json');
const RETRY_BACKOFF_MS = 6 * 60 * 60 * 1000; // retry at most every 6h while failing
const DEPENDENCIES = ['better-sqlite3'];

function depAvailable() {
  const requireFromHere = createRequire(import.meta.url);
  try {
    requireFromHere.resolve('better-sqlite3', {
      paths: [join(depsDir, 'node_modules'), join(pluginRoot, 'node_modules')],
    });
    return true;
  } catch {
    return false;
  }
}

function readMarker() {
  try {
    const parsed = JSON.parse(readFileSync(markerPath, 'utf8'));
    return Number.isFinite(parsed?.lastAttemptAt) ? parsed : null;
  } catch {
    return null;
  }
}

function writeMarker() {
  try {
    mkdirSync(depsDir, { recursive: true });
    writeFileSync(markerPath, JSON.stringify({ lastAttemptAt: Date.now() }, null, 2));
  } catch {
    // Marker is best-effort; the spawn below still proceeds once per session.
  }
}

function main() {
  if (process.env.OMK_AUTO_INSTALL_DEPS === '0') return;
  if (depAvailable()) return;

  const marker = readMarker();
  if (marker && Date.now() - marker.lastAttemptAt < RETRY_BACKOFF_MS) return;

  writeMarker();

  const npmCommand = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  try {
    const child = spawn(
      npmCommand,
      ['install', '--prefix', depsDir, '--no-audit', '--no-fund', '--loglevel=error', ...DEPENDENCIES],
      {
        detached: true, // own process group: survives the hook reaper
        stdio: 'ignore',
        windowsHide: true,
        env: { ...process.env, OMK_DEPS_INSTALL_CHILD: '1' },
      },
    );
    child.unref();
    process.stderr.write(
      `[omk] Installing MCP server dependency (${DEPENDENCIES.join(', ')}) in the background; ` +
        'full state-write capability is available from the next session. ' +
        'Disable with OMK_AUTO_INSTALL_DEPS=0.\n',
    );
  } catch {
    // Offline or npm-less machines keep the degraded-but-working server.
  }
}

main();
