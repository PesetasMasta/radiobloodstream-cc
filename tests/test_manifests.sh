#!/usr/bin/env bash
# Validates the plugin manifests are well-formed JSON with the required fields.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"

node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const p = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
if (m.name !== "radiobloodstream-cc") throw new Error("marketplace name wrong: " + m.name);
if (!Array.isArray(m.plugins) || m.plugins.length !== 1) throw new Error("expected 1 plugin");
const entry = m.plugins[0];
if (entry.name !== "bloodstream-radio") throw new Error("plugin entry name wrong: " + entry.name);
if (entry.source !== "./plugins/bloodstream-radio") throw new Error("plugin source wrong: " + entry.source);
if (p.name !== "bloodstream-radio") throw new Error("plugin.json name wrong: " + p.name);
if (p.version !== "0.2.0") throw new Error("plugin.json version wrong: " + p.version);
if (!p.description) throw new Error("plugin.json missing description");
console.log("manifests OK");
' "$root/.claude-plugin/marketplace.json" "$root/plugins/bloodstream-radio/.claude-plugin/plugin.json"
