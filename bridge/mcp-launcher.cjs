#!/usr/bin/env node
'use strict';

/**
 * Cross-platform MCP launcher for the omk plugin.
 *
 * Kimi Code starts this instead of bridge/mcp-server.cjs directly so that the
 * optional native dependency (better-sqlite3) is resolvable regardless of
 * where it was installed:
 *
 *   - <pluginRoot>/node_modules        (manual `npm install --prefix <pluginRoot>`)
 *   - <pluginRoot>/.omc-deps/node_modules  (scripts/auto-install-deps.mjs, the default)
 *
 * The server itself degrades gracefully when the dependency is absent (see the
 * try/catch around its better-sqlite3 require); this launcher only widens the
 * resolution paths so an install in either location is picked up.
 */

const { existsSync } = require('fs');
const path = require('path');
const Module = require('module');

const pluginRoot = path.resolve(__dirname, '..');

const candidateDirs = [
  path.join(pluginRoot, 'node_modules'),
  path.join(pluginRoot, '.omc-deps', 'node_modules'),
];

const foundDirs = candidateDirs.filter((dir) => {
  try {
    return existsSync(dir);
  } catch {
    return false;
  }
});

if (foundDirs.length > 0) {
  const existing = (process.env.NODE_PATH || '')
    .split(path.delimiter)
    .filter(Boolean);
  const merged = [...new Set([...foundDirs, ...existing])].join(path.delimiter);
  process.env.NODE_PATH = merged;
  // Rebuild Node's global resolution paths from the new NODE_PATH value.
  Module._initPaths();
}

require('./mcp-server.cjs');
