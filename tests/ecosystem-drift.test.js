/**
 * Ecosystem drift check.
 *
 * ecosystem-drift.sh reads every repo in repos.json (read-only) and reports
 * two kinds of silent rot: a child repo whose stamped disclaimer no longer
 * matches the shared wording, and a packaged skill (*.skill) older than the
 * sources it contains. These tests replace `gh` with tests/helpers/fake-gh.js,
 * which serves fixture directories, so they need no network.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SCRIPT = path.join(ROOT, '.github/scripts/ecosystem-drift.sh');
const SYNC = path.join(ROOT, '.github/scripts/sync-disclaimer.sh');
const FAKE_GH = path.join(__dirname, 'helpers/fake-gh.js');

const OLD = '2026-04-09T16:30:00Z';
const NEW = '2026-10-18T12:00:00Z';

jest.setTimeout(30000);

let tmp;
let fixtures;

beforeEach(() => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'drift-'));
  fixtures = path.join(tmp, 'fixtures');
  fs.mkdirSync(path.join(tmp, 'bin'), { recursive: true });
  fs.mkdirSync(fixtures);
  fs.symlinkSync(FAKE_GH, path.join(tmp, 'bin', 'gh'));
});
afterEach(() => fs.rmSync(tmp, { recursive: true, force: true }));

/** Create a fixture repo. files: { relPath: content }, commits: { relPath: date } */
function repo(name, { files = {}, commits = {}, priv = false } = {}) {
  const dir = path.join(fixtures, name, 'files');
  fs.mkdirSync(dir, { recursive: true });
  Object.entries(files).forEach(([rel, content]) => {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), content);
  });
  fs.writeFileSync(path.join(fixtures, name, 'meta.json'), JSON.stringify({ private: priv, commits }));
  return dir;
}

/** Stamp the real shared disclaimer into a fixture, as sync-disclaimer.sh would. */
function stamp(name, dir) {
  const r = spawnSync(SYNC, [name, dir], { encoding: 'utf-8' });
  if (r.status !== 0) throw new Error(r.stdout + r.stderr);
}

/** Zip the given files (relative to src) into dest. */
function zip(dest, src, entries) {
  const r = spawnSync('zip', ['-qr', dest, ...entries], { cwd: src, encoding: 'utf-8' });
  if (r.status !== 0) throw new Error(r.stderr);
}

function registry(names) {
  const f = path.join(tmp, 'repos.json');
  fs.writeFileSync(f, JSON.stringify({ owner: 'dougdevitre', repos: names.map((name) => ({ name })) }));
  return f;
}

function runDrift(names, env = {}) {
  const report = path.join(tmp, 'report.md');
  const r = spawnSync(SCRIPT, ['--report', report, registry(names)], {
    encoding: 'utf-8',
    env: { ...process.env, PATH: `${path.join(tmp, 'bin')}:${process.env.PATH}`, FAKE_GH_ROOT: fixtures, LOG_FORMAT: 'json', GITHUB_STEP_SUMMARY: '', ...env },
  });
  const rows = r.stdout.split('\n')
    .filter((l) => l.startsWith('{'))
    .map((l) => JSON.parse(l))
    .filter((o) => o.repo);
  const byRepo = Object.fromEntries(rows.map((o) => [o.repo, o]));
  return { ...r, rows: byRepo, report: fs.existsSync(report) ? fs.readFileSync(report, 'utf-8') : '' };
}

const README = '# Sample Tool\n\nIntro.\n';
const SKILL = '---\nname: sample\n---\n\n# Sample Skill\n\nBody.\n';

describe('ecosystem-drift.sh', () => {
  test('exists and sources the shared logging library', () => {
    expect(fs.existsSync(SCRIPT)).toBe(true);
    expect(fs.readFileSync(SCRIPT, 'utf-8')).toMatch(/source "\$SCRIPT_DIR\/lib-log\.sh"/);
  });

  describe('disclaimer drift', () => {
    test('a freshly stamped repo is in sync, and the run exits 0', () => {
      stamp('access-to-safety', repo('access-to-safety', { files: { 'README.md': README, 'SKILL.md': SKILL } }));
      const r = runDrift(['access-to-safety']);
      expect(r.rows['access-to-safety'].disclaimer).toBe('in sync');
      expect(r.status).toBe(0);
    });

    test('checks skill/SKILL.md as well as the root files', () => {
      const dir = repo('access-to-safety', { files: { 'README.md': README, 'skill/SKILL.md': SKILL } });
      stamp('access-to-safety', dir);
      fs.writeFileSync(path.join(dir, 'skill/SKILL.md'), SKILL);
      const r = runDrift(['access-to-safety']);
      expect(r.rows['access-to-safety'].disclaimer).toBe('drifted');
      expect(r.rows['access-to-safety'].drifted_files).toEqual(['skill/SKILL.md']);
    });

    test('an edited notice is drifted: exit 1, files named, fix command in the report', () => {
      const dir = repo('access-to-safety', { files: { 'README.md': README, 'SKILL.md': SKILL } });
      stamp('access-to-safety', dir);
      const f = path.join(dir, 'README.md');
      fs.writeFileSync(f, fs.readFileSync(f, 'utf-8').replace('Educational information only.', 'Old wording.'));
      const r = runDrift(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].disclaimer).toBe('drifted');
      expect(r.rows['access-to-safety'].drifted_files).toEqual(['README.md']);
      expect(r.report).toContain('sync-disclaimer.sh access-to-safety');
    });

    test('a repo without DISCLAIMER.md is missing, and fails the run', () => {
      repo('access-to-peace', { files: { 'README.md': README } });
      const r = runDrift(['access-to-peace']);
      expect(r.rows['access-to-peace'].disclaimer).toBe('missing');
      expect(r.status).toBe(1);
      expect(r.report).toContain('access-to-peace');
    });

    test('a private repo the token cannot read is skipped with a warning, not a failure', () => {
      stamp('access-to-safety', repo('access-to-safety', { files: { 'README.md': README } }));
      const r = runDrift(['access-to-safety', 'access-to-energy']);
      expect(r.status).toBe(0);
      expect(r.rows['access-to-energy'].disclaimer).toBe('skipped');
      expect(r.stdout).toMatch(/::warning::.*access-to-energy/);
    });

    test('never writes to the fixture (read-only)', () => {
      const dir = repo('access-to-peace', { files: { 'README.md': README } });
      runDrift(['access-to-peace']);
      expect(fs.readdirSync(dir)).toEqual(['README.md']);
      expect(fs.readFileSync(path.join(dir, 'README.md'), 'utf-8')).toBe(README);
    });
  });

  describe('stale skill packages', () => {
    function skillRepo(pkgDate, skillDate) {
      const dir = repo('access-to-jobs', {
        files: { 'README.md': README, 'SKILL.md': SKILL, 'references/a.md': 'A\n', 'docs/unrelated.md': 'x\n' },
        commits: { 'access-to-jobs.skill': pkgDate, 'SKILL.md': skillDate, 'references/a.md': OLD, 'docs/unrelated.md': '2026-10-30T00:00:00Z' },
      });
      zip(path.join(dir, 'access-to-jobs.skill'), dir, ['SKILL.md', 'references']);
      stamp('access-to-jobs', dir);
      return dir;
    }

    test('a package older than the sources it contains is stale, with both dates', () => {
      skillRepo(OLD, NEW);
      const r = runDrift(['access-to-jobs']);
      const [pkg] = r.rows['access-to-jobs'].packages;
      expect(pkg).toMatchObject({ file: 'access-to-jobs.skill', status: 'stale', package_date: OLD, content_date: NEW, newest_path: 'SKILL.md' });
      expect(r.status).toBe(1);
      expect(r.report).toContain(OLD.slice(0, 10));
      expect(r.report).toContain(NEW.slice(0, 10));
    });

    test('a package at least as new as its sources is fresh; paths outside it do not count', () => {
      skillRepo(NEW, OLD);
      const r = runDrift(['access-to-jobs']);
      expect(r.rows['access-to-jobs'].packages[0]).toMatchObject({ status: 'fresh', package_date: NEW, content_date: OLD });
      expect(r.status).toBe(0);
    });

    test('reads a gzipped tarball package with a top-level folder', () => {
      // Like access-to-services: SKILL.md lives only inside the package, under
      // a folder named after the repo; eval-results.md is in both, and newer.
      const dir = repo('access-to-services', {
        files: { 'README.md': README, 'eval-results.md': 'r\n' },
        commits: { 'access-to-services.skill': OLD, 'eval-results.md': NEW },
      });
      const src = path.join(tmp, 'pkg', 'access-to-services');
      fs.mkdirSync(src, { recursive: true });
      fs.writeFileSync(path.join(src, 'SKILL.md'), SKILL);
      fs.writeFileSync(path.join(src, 'eval-results.md'), 'r\n');
      spawnSync('tar', ['-czf', path.join(dir, 'access-to-services.skill'), '-C', path.join(tmp, 'pkg'), 'access-to-services']);
      stamp('access-to-services', dir);
      const r = runDrift(['access-to-services']);
      expect(r.rows['access-to-services'].packages[0]).toMatchObject({ status: 'stale', newest_path: 'eval-results.md' });
    });
  });

  test('text mode prints a table row per repo', () => {
    stamp('access-to-safety', repo('access-to-safety', { files: { 'README.md': README } }));
    const r = runDrift(['access-to-safety'], { LOG_FORMAT: 'text' });
    expect(r.stdout).toMatch(/access-to-safety\s+.*in sync/);
  });
});
