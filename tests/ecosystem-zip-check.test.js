/**
 * Install zip completeness check.
 *
 * ecosystem-zip-check.sh downloads every repo's published install zip (the
 * `install_zip` asset on its skill-latest release), unzips it and checks that
 * what is inside is complete: one top-level folder named after the skill with
 * SKILL.md in it; every relative path SKILL.md references present in the zip;
 * the shared disclaimer stamped and current; frontmatter within the claude.ai
 * upload rules. These tests replace `gh` with tests/helpers/fake-gh.js, which
 * serves fixture directories and streams release assets, so they need no
 * network.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SCRIPT = path.join(ROOT, '.github/scripts/ecosystem-zip-check.sh');
const SYNC = path.join(ROOT, '.github/scripts/sync-disclaimer.sh');
const FAKE_GH = path.join(__dirname, 'helpers/fake-gh.js');

jest.setTimeout(30000);

let tmp;
let fixtures;

beforeEach(() => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zipcheck-'));
  fixtures = path.join(tmp, 'fixtures');
  fs.mkdirSync(path.join(tmp, 'bin'), { recursive: true });
  fs.mkdirSync(fixtures);
  fs.symlinkSync(FAKE_GH, path.join(tmp, 'bin', 'gh'));
});
afterEach(() => fs.rmSync(tmp, { recursive: true, force: true }));

const SKILL = (body = '') => `---\nname: access-to-jobs\ndescription: Missouri jobs navigator.\n---\n\n# Access to Jobs\n\n${body}`;

/**
 * Build an install zip the way skill-package.yml does: every entry under one
 * top-level folder (`folder`, default the repo name), SKILL.md stamped with
 * the shared disclaimer unless `stamp` is false, and DISCLAIMER.md kept
 * unless `disclaimer` is false. files: { pathInsideFolder: content }.
 * Returns the fixture repo directory.
 */
function zipRepo(name, { files = {}, folder = name, stamp = true, disclaimer = true, flat = false, asset = `${name}.zip`, priv = false } = {}) {
  const repoDir = path.join(fixtures, name);
  const src = fs.mkdtempSync(path.join(tmp, 'zipsrc-'));
  const top = flat ? src : path.join(src, folder);
  fs.mkdirSync(top, { recursive: true });
  Object.entries(files).forEach(([rel, content]) => {
    fs.mkdirSync(path.dirname(path.join(top, rel)), { recursive: true });
    fs.writeFileSync(path.join(top, rel), content);
  });
  if (stamp) {
    const r = spawnSync(SYNC, [name, top], { encoding: 'utf-8' });
    if (r.status !== 0) throw new Error(r.stdout + r.stderr);
  }
  if (!disclaimer) fs.rmSync(path.join(top, 'DISCLAIMER.md'), { force: true });
  fs.mkdirSync(path.join(repoDir, 'files'), { recursive: true });
  fs.mkdirSync(path.join(repoDir, 'assets'), { recursive: true });
  const entries = fs.readdirSync(src);
  const z = spawnSync('zip', ['-qr', path.join(repoDir, 'assets', asset), ...entries], { cwd: src, encoding: 'utf-8' });
  if (z.status !== 0) throw new Error(z.stderr);
  fs.writeFileSync(path.join(repoDir, 'meta.json'), JSON.stringify({
    private: priv,
    commits: {},
    releases: { 'skill-latest': { assets: [asset], date: '2026-10-18T12:00:00Z' } },
  }));
  return repoDir;
}

function registry(repos) {
  const f = path.join(tmp, 'repos.json');
  fs.writeFileSync(f, JSON.stringify({ owner: 'dougdevitre', repos }));
  return f;
}

function run(repos, env = {}) {
  const report = path.join(tmp, 'report.md');
  const r = spawnSync(SCRIPT, ['--report', report, registry(repos)], {
    encoding: 'utf-8',
    env: { ...process.env, PATH: `${path.join(tmp, 'bin')}:${process.env.PATH}`, FAKE_GH_ROOT: fixtures, LOG_FORMAT: 'json', GITHUB_STEP_SUMMARY: '', ...env },
  });
  const rows = r.stdout.split('\n')
    .filter((l) => l.startsWith('{'))
    .map((l) => JSON.parse(l))
    .filter((o) => o.repo);
  return { ...r, rows: Object.fromEntries(rows.map((o) => [o.repo, o])), report: fs.existsSync(report) ? fs.readFileSync(report, 'utf-8') : '' };
}

const JOBS = { name: 'access-to-jobs', install_zip: 'access-to-jobs.zip' };

describe('ecosystem-zip-check.sh', () => {
  test('exists and sources the shared logging library', () => {
    expect(fs.existsSync(SCRIPT)).toBe(true);
    expect(fs.readFileSync(SCRIPT, 'utf-8')).toMatch(/source "\$SCRIPT_DIR\/lib-log\.sh"/);
  });

  test('the frontmatter checker is vendored next to it', () => {
    expect(fs.existsSync(path.join(ROOT, '.github/scripts/check-skill-frontmatter.py'))).toBe(true);
  });

  test('a complete zip is ok: exit 0, every column clean, marker in the report', () => {
    zipRepo('access-to-jobs', {
      files: {
        'SKILL.md': SKILL('Load `references/state-programs.md` first. See [the FAQ](references/faq.md) and [GitHub](https://github.com/x#top).\n'),
        'references/state-programs.md': 'x\n',
        'references/faq.md': 'x\n',
      },
    });
    const r = run([JOBS]);
    expect(r.status).toBe(0);
    expect(r.rows['access-to-jobs']).toMatchObject({ status: 'ok', layout: 'ok', disclaimer: 'in sync', frontmatter: 'ok' });
    expect(r.rows['access-to-jobs'].references).toMatchObject({ checked: 2, missing: [], exempt: 0 });
    expect(r.report.split('\n')[0]).toBe('<!-- ecosystem-zip-check findings=0 errors=0 skipped=0 -->');
  });

  describe('references', () => {
    test('a backticked path missing from the zip is a finding, with its line (as stamped), and the run exits 1', () => {
      zipRepo('access-to-jobs', {
        files: { 'SKILL.md': SKILL('Route to `references/state-programs.md` and `references/missing.md`.\n'), 'references/state-programs.md': 'x\n' },
      });
      const r = run([JOBS]);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-jobs'].status).toBe('findings');
      expect(r.rows['access-to-jobs'].references.missing).toEqual([{ path: 'references/missing.md', kind: 'code', line: 18 }]);
      expect(r.report).toContain('`references/missing.md` (SKILL.md line 18');
      expect(r.report).toContain('skill-package.yml -R dougdevitre/<repo>');
    });

    test('a markdown link target missing from the zip is a finding; URLs and anchors are not references', () => {
      zipRepo('access-to-jobs', {
        files: { 'SKILL.md': SKILL('See [templates](templates/resume.md), [site](https://example.org/a.md), [below](#section) and [mail](mailto:a@b.md).\n') },
      });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs'].references.missing.map((m) => m.path)).toEqual(['templates/resume.md']);
      expect(r.rows['access-to-jobs'].references.checked).toBe(1);
    });

    test('a routing-table cell resolves relative to any folder of the zip; a bare filename by name', () => {
      zipRepo('access-to-jobs', {
        files: {
          'SKILL.md': SKILL('| Topic | Load |\n|---|---|\n| Rights | roles/students.md §1 |\n| Jobs | `state-programs.md` (Missouri only) |\n| Gone | roles/nobody.md |\n'),
          'references/roles/students.md': 'x\n',
          'references/state-programs.md': 'x\n',
        },
      });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs'].references.missing.map((m) => m.path)).toEqual(['roles/nobody.md']);
    });

    test('a folder reference and a glob resolve when anything matches', () => {
      zipRepo('access-to-jobs', {
        files: {
          'SKILL.md': SKILL('Playbooks live in `references/playbooks/` as `references/playbooks/*.md`; schemas as `schemas/*.json`.\n'),
          'references/playbooks/one.md': 'x\n',
        },
      });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs'].references.missing.map((m) => m.path)).toEqual(['schemas/*.json']);
    });

    test('a line that says its paths are not shipped is exempt and counted; so is a section whose heading says so', () => {
      zipRepo('access-to-jobs', {
        files: {
          'SKILL.md': SKILL([
            '- Maintainer files: `CHANGELOG.md` and `MANIFEST.json` live in the GitHub repository. They are not part of the installed skill.',
            '',
            '## Repo file map (only in a clone of the repo)',
            '',
            '- Spec: `docs/product-spec.md`',
            '- Types: `packages/shared-types/src/*.ts`',
            '',
            '## Still checked',
            '',
            '- `references/real.md` and `references/gone.md`',
            '',
          ].join('\n')),
          'references/real.md': 'x\n',
        },
      });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs'].references.missing.map((m) => m.path)).toEqual(['references/gone.md']);
      expect(r.rows['access-to-jobs'].references.exempt).toBe(4);
      expect(r.report).toContain('exempt line(s)');
    });

    test('the exempt phrases come from .github/config/zip-check.json', () => {
      const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, '.github/config/zip-check.json'), 'utf-8'));
      expect(cfg.not_shipped_phrases).toEqual(expect.arrayContaining(['not part of the installed skill', 'only in a clone']));
      expect(cfg.path_extensions).toEqual(expect.arrayContaining(['md', 'json']));
      const custom = path.join(tmp, 'cfg.json');
      fs.writeFileSync(custom, JSON.stringify({ not_shipped_phrases: ['repo-only'], path_extensions: ['md'] }));
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL('`docs/a.md` (repo-only)\n`docs/b.md` (not part of the installed skill)\n') } });
      const r = run([JOBS], { ZIP_CHECK_CONFIG: custom });
      expect(r.rows['access-to-jobs'].references.missing.map((m) => m.path)).toEqual(['docs/b.md']);
    });
  });

  describe('disclaimer', () => {
    test('a SKILL.md without the shared notice is drifted', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() }, stamp: false });
      fs.writeFileSync(path.join(fixtures, 'access-to-jobs', 'dummy'), '');
      // DISCLAIMER.md was never stamped either, so it is missing.
      const r = run([JOBS]);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-jobs'].disclaimer).toBe('missing');
    });

    test('an edited notice is drifted and names SKILL.md', () => {
      const dir = zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() } });
      // Rebuild the zip with an edited notice.
      const src = fs.mkdtempSync(path.join(tmp, 'edit-'));
      spawnSync('unzip', ['-q', path.join(dir, 'assets', 'access-to-jobs.zip'), '-d', src]);
      const f = path.join(src, 'access-to-jobs', 'SKILL.md');
      fs.writeFileSync(f, fs.readFileSync(f, 'utf-8').replace('Call 911', 'Call someone'));
      fs.rmSync(path.join(dir, 'assets', 'access-to-jobs.zip'));
      spawnSync('zip', ['-qr', path.join(dir, 'assets', 'access-to-jobs.zip'), 'access-to-jobs'], { cwd: src });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs']).toMatchObject({ disclaimer: 'drifted', drifted_files: ['SKILL.md'] });
      expect(r.report).toContain('sync-disclaimer.sh access-to-jobs');
    });

    test('a zip without DISCLAIMER.md is missing', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() }, disclaimer: false });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs']).toMatchObject({ disclaimer: 'missing', drifted_files: ['DISCLAIMER.md'] });
      expect(r.report).toContain('no DISCLAIMER.md');
    });
  });

  describe('frontmatter and layout', () => {
    test('a description over 1024 characters is invalid, with the checker\'s message', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': `---\nname: access-to-jobs\ndescription: ${'x'.repeat(1030)}\n---\n\n# T\n` } });
      const r = run([JOBS]);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-jobs'].frontmatter).toBe('invalid');
      expect(r.rows['access-to-jobs'].frontmatter_errors).toEqual(['description is 1030 chars (max 1024)']);
      expect(r.report).toContain('Frontmatter: description is 1030 chars');
    });

    test('a top-level folder that does not match the skill name is invalid', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() }, folder: 'jobs' });
      const r = run([JOBS]);
      expect(r.rows['access-to-jobs'].frontmatter_errors).toEqual(['skill folder "jobs" must match name "access-to-jobs"']);
    });

    test('a zip with SKILL.md at its root (no folder) has a bad layout', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL(), 'references/a.md': 'x\n' }, flat: true });
      const r = run([JOBS]);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-jobs'].layout).toBe('bad');
      expect(r.report).toContain('claude.ai expects `<skill-name>/SKILL.md`');
    });
  });

  describe('releases and the registry', () => {
    test('only repos with install_zip are checked', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() } });
      const r = run([JOBS, { name: 'access-to-food' }]);
      expect(Object.keys(r.rows)).toEqual(['access-to-jobs']);
      expect(r.status).toBe(0);
    });

    test('a missing skill-latest release or asset is a finding with the republish command', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() } });
      fs.writeFileSync(path.join(fixtures, 'access-to-jobs', 'meta.json'), JSON.stringify({ commits: {}, releases: {} }));
      zipRepo('access-to-peace', { files: { 'SKILL.md': SKILL() }, asset: 'other.zip' });
      const r = run([JOBS, { name: 'access-to-peace', install_zip: 'access-to-peace.zip' }]);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-jobs'].status).toBe('missing release');
      expect(r.rows['access-to-peace'].status).toBe('missing asset');
      expect(r.report).toContain('gh workflow run skill-package.yml -R dougdevitre/access-to-jobs');
    });

    test('a full release URL is checked like a filename; a URL elsewhere is external', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() } });
      const r = run([
        { name: 'access-to-jobs', install_zip: 'https://github.com/dougdevitre/access-to-jobs/releases/download/skill-latest/access-to-jobs.zip' },
        { name: 'access-to-peace', install_zip: 'https://example.org/peace.zip' },
      ]);
      expect(r.rows['access-to-jobs'].status).toBe('ok');
      expect(r.rows['access-to-peace'].status).toBe('external');
      expect(r.status).toBe(0);
    });

    test('a private repo the token cannot read is skipped with a warning, not a failure', () => {
      zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL() } });
      const r = run([JOBS, { name: 'access-to-energy', install_zip: 'access-to-energy.zip' }]);
      expect(r.status).toBe(0);
      expect(r.rows['access-to-energy'].status).toBe('skipped');
      expect(r.stdout).toMatch(/::warning::.*access-to-energy/);
      expect(r.report).toContain('Not checked');
    });

    test('never writes to the fixture (read-only)', () => {
      const dir = zipRepo('access-to-jobs', { files: { 'SKILL.md': SKILL('`references/gone.md`\n') } });
      const before = JSON.stringify(fs.readdirSync(dir, { recursive: true }).sort());
      run([JOBS]);
      expect(JSON.stringify(fs.readdirSync(dir, { recursive: true }).sort())).toBe(before);
    });
  });
});
