#!/usr/bin/env node
/**
 * A stand-in for `gh api` (and `gh project`, below), so the ecosystem-drift
 * and sync-repos tests need no network.
 *
 * It serves the GitHub REST endpoints ecosystem-drift.sh reads (repo, git
 * trees, git blobs, commits by path, a commit by ref, a release by tag), from
 * fixture directories under $FAKE_GH_ROOT:
 *
 *   <root>/<repo>/files/...   the repo's default-branch tree (real files,
 *                             directories and symlinks)
 *   <root>/<repo>/meta.json   { "private": bool,
 *                               "commits": { "<path>": "<ISO date>" },
 *                               "releases": { "<tag>": { "assets": ["<name>"], "date": "<ISO date of the tagged commit>" } } }
 *
 * A tag without a release answers 404, like GitHub. A release given as
 * { "error": "<message>" } fails with that message instead (e.g. an HTTP 500).
 *
 * A repo without a fixture directory answers 404, like a private repo the
 * token cannot read. Tree and blob shas encode the fixture-relative path.
 *
 * For sync-repos.sh it also serves `gh project list --owner <o> --format json`
 * and `gh project item-add <n> --owner <o> --url <url>` from
 * <root>/project.json:
 *
 *   { "projects": [{ "number": 1, "id": "PVT_x" }],
 *     "items": ["<url already in the project>"],
 *     "fail": { "list": <n>, "<url>": <n> } }
 *
 * "fail" makes the next n calls of that command (list, or item-add of that
 * url) fail with "HTTP 502", as a transient error would; each failure is
 * counted down in project.json, so a retry can then succeed. An item already
 * in "items" fails with "already exists", like GitHub.
 */
const fs = require('fs');
const path = require('path');

const root = process.env.FAKE_GH_ROOT;
const [cmd, endpoint] = process.argv.slice(2);
const fail = (msg) => { process.stderr.write(`gh: ${msg}\n`); process.exit(1); };

if (cmd === 'project') {
  const file = path.join(root, 'project.json');
  const state = JSON.parse(fs.readFileSync(file, 'utf-8'));
  const args = process.argv.slice(3);
  const flag = (name) => args[args.indexOf(name) + 1];
  const key = endpoint === 'list' ? 'list' : endpoint === 'item-add' ? flag('--url') : null;
  if (!key) fail(`fake gh supports only "project list" and "project item-add", got: ${args.join(' ')}`);
  const fails = state.fail || {};
  if (fails[key] > 0) {
    fails[key] -= 1;
    fs.writeFileSync(file, JSON.stringify({ ...state, fail: fails }));
    fail('Bad Gateway (HTTP 502)');
  }
  if (key === 'list') {
    process.stdout.write(JSON.stringify(state.projects || []));
    process.exit(0);
  }
  const items = state.items || [];
  if (items.includes(key)) fail('Content already exists in this project');
  fs.writeFileSync(file, JSON.stringify({ ...state, items: [...items, key] }));
  process.stdout.write(JSON.stringify({ id: `PVTI_${items.length}` }));
  process.exit(0);
}

if (cmd !== 'api' || !endpoint) fail(`fake gh supports only "gh api <endpoint>", got: ${process.argv.slice(2).join(' ')}`);

const [route, query = ''] = endpoint.split('?');
const params = new URLSearchParams(query);
const m = route.match(/^repos\/[^/]+\/([^/]+)(?:\/(.*))?$/);
if (!m) fail(`unsupported endpoint: ${endpoint}`);
const [, repo, rest = ''] = m;
const repoDir = path.join(root, repo);
if (!fs.existsSync(repoDir)) fail('Not Found (HTTP 404)');
const files = path.join(repoDir, 'files');
const meta = JSON.parse(fs.readFileSync(path.join(repoDir, 'meta.json'), 'utf-8'));

const enc = (rel) => Buffer.from(rel).toString('base64url');
const dec = (sha) => Buffer.from(sha, 'base64url').toString();
const out = (obj) => process.stdout.write(JSON.stringify(obj));

if (rest === '') {
  out({ name: repo, default_branch: 'main', private: !!meta.private });
} else if (rest.startsWith('git/trees/')) {
  const ref = rest.slice('git/trees/'.length);
  const rel = ref === 'main' ? '' : dec(ref);
  const dir = path.join(files, rel);
  const tree = fs.readdirSync(dir, { withFileTypes: true }).map((d) => {
    const p = path.posix.join(rel, d.name);
    if (d.isSymbolicLink()) return { path: d.name, mode: '120000', type: 'blob', sha: enc(p) };
    if (d.isDirectory()) return { path: d.name, mode: '040000', type: 'tree', sha: enc(p) };
    return { path: d.name, mode: '100644', type: 'blob', sha: enc(p) };
  });
  out({ sha: ref, tree, truncated: false });
} else if (rest.startsWith('git/blobs/')) {
  const full = path.join(files, dec(rest.slice('git/blobs/'.length)));
  const st = fs.lstatSync(full);
  process.stdout.write(st.isSymbolicLink() ? fs.readlinkSync(full) : fs.readFileSync(full));
} else if (rest === 'commits') {
  const p = params.get('path');
  const dates = Object.entries(meta.commits || {})
    .filter(([k]) => k === p || k.startsWith(`${p}/`))
    .map(([, d]) => d)
    .sort();
  out(dates.length ? [{ commit: { committer: { date: dates[dates.length - 1] } } }] : []);
} else if (rest.startsWith('releases/tags/')) {
  const tag = rest.slice('releases/tags/'.length);
  const rel = (meta.releases || {})[tag];
  if (!rel) fail('Not Found (HTTP 404)');
  if (rel.error) fail(rel.error);
  out({ tag_name: tag, assets: rel.assets.map((name) => ({ name })) });
} else if (rest.startsWith('commits/')) {
  const ref = rest.slice('commits/'.length);
  const rel = (meta.releases || {})[ref];
  if (!rel) fail('No commit found for SHA: ' + ref + ' (HTTP 422)');
  out({ sha: Buffer.from(ref).toString('hex'), commit: { committer: { date: rel.date } } });
} else {
  fail(`unsupported endpoint: ${endpoint}`);
}
