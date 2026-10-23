/**
 * Ecosystem drift check.
 *
 * ecosystem-drift.sh reads every repo in repos.json (read-only) and reports
 * three kinds of silent rot: a child repo whose stamped disclaimer no longer
 * matches the shared wording, a packaged skill (*.skill) older than the
 * sources it contains, and an install zip (install_zip in repos.json) whose
 * skill-latest release or asset is missing or older than the skill sources. These tests replace `gh` with tests/helpers/fake-gh.js,
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
function repo(name, { files = {}, commits = {}, priv = false, releases = {} } = {}) {
  const dir = path.join(fixtures, name, 'files');
  fs.mkdirSync(dir, { recursive: true });
  Object.entries(files).forEach(([rel, content]) => {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), content);
  });
  fs.writeFileSync(path.join(fixtures, name, 'meta.json'), JSON.stringify({ private: priv, commits, releases }));
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

/**
 * Build a gzipped tarball package the way access-to-services does: every
 * entry under one top-level folder. files: { pathInsideFolder: content }.
 * With stampSkill, SKILL.md is stamped with the shared disclaimer first.
 */
function tarPackage(dest, top, files, { stampSkill = false } = {}) {
  const src = fs.mkdtempSync(path.join(tmp, 'pkgsrc-'));
  const folder = path.join(src, top);
  Object.entries(files).forEach(([rel, content]) => {
    fs.mkdirSync(path.dirname(path.join(folder, rel)), { recursive: true });
    fs.writeFileSync(path.join(folder, rel), content);
  });
  if (stampSkill) {
    stamp('access-to-services', folder);
    fs.rmSync(path.join(folder, 'DISCLAIMER.md'));
  }
  const r = spawnSync('tar', ['-czf', dest, '-C', src, top], { encoding: 'utf-8' });
  if (r.status !== 0) throw new Error(r.stderr);
}

function registry(names) {
  const f = path.join(tmp, 'repos.json');
  fs.writeFileSync(f, JSON.stringify({ owner: 'dougdevitre', repos: names.map((n) => (typeof n === 'string' ? { name: n } : n)) }));
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

    describe('SKILL.md that lives only inside a root *.skill package (access-to-services)', () => {
      const PKG = 'access-to-services.skill';
      function svc(pkgBuilder) {
        const dir = repo('access-to-services', { files: { 'README.md': README, 'eval-results.md': 'r\n' } });
        stamp('access-to-services', dir);
        pkgBuilder(path.join(dir, PKG));
        return dir;
      }

      test('an unstamped SKILL.md inside a gzipped tarball is drifted, named by package', () => {
        svc((f) => tarPackage(f, 'access-to-services', { 'SKILL.md': SKILL }));
        const r = runDrift(['access-to-services']);
        expect(r.rows['access-to-services'].disclaimer).toBe('drifted');
        expect(r.rows['access-to-services'].drifted_files).toEqual([`${PKG}:access-to-services/SKILL.md`]);
        expect(r.status).toBe(1);
        expect(r.report).toContain(`${PKG}:access-to-services/SKILL.md`);
        expect(r.report).toContain('rebuild');
      });

      test('an unstamped SKILL.md at the root of a zip package is drifted', () => {
        svc((f) => {
          const src = fs.mkdtempSync(path.join(tmp, 'zipsrc-'));
          fs.writeFileSync(path.join(src, 'SKILL.md'), SKILL);
          zip(f, src, ['SKILL.md']);
        });
        const r = runDrift(['access-to-services']);
        expect(r.rows['access-to-services'].disclaimer).toBe('drifted');
        expect(r.rows['access-to-services'].drifted_files).toEqual([`${PKG}:SKILL.md`]);
      });

      test('a stamped SKILL.md inside the package is in sync', () => {
        svc((f) => tarPackage(f, 'access-to-services', { 'SKILL.md': SKILL }, { stampSkill: true }));
        const r = runDrift(['access-to-services']);
        expect(r.rows['access-to-services'].disclaimer).toBe('in sync');
        expect(r.status).toBe(0);
      });

      test('a root SKILL.md is what gets checked; the package copy is not', () => {
        const dir = repo('access-to-jobs', { files: { 'README.md': README, 'SKILL.md': SKILL } });
        stamp('access-to-jobs', dir);
        tarPackage(path.join(dir, 'access-to-jobs.skill'), 'access-to-jobs', { 'SKILL.md': SKILL });
        const r = runDrift(['access-to-jobs']);
        expect(r.rows['access-to-jobs'].disclaimer).toBe('in sync');
      });
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

  describe('skill_package_sources (repos.json) names the paths that feed a package', () => {
    // Like access-to-services: the package carries its own README.md (meant to
    // differ from the repo's), and scripts/build-skill.sh copies only
    // mo-resources.json, SCHEMA.md and eval-results.md into it, two of them
    // under data/.
    const SOURCES = ['mo-resources.json', 'SCHEMA.md', 'eval-results.md'];
    const SVC = { name: 'access-to-services', skill_package_sources: SOURCES };
    const MID = '2026-07-01T00:00:00Z';

    function svcRepo(commits, files = {}) {
      const dir = repo('access-to-services', {
        files: { 'README.md': README, 'mo-resources.json': '{}\n', 'SCHEMA.md': 'S\n', 'eval-results.md': 'r\n', ...files },
        commits: { 'access-to-services.skill': MID, 'README.md': OLD, 'mo-resources.json': OLD, 'SCHEMA.md': OLD, 'eval-results.md': OLD, ...commits },
      });
      tarPackage(path.join(dir, 'access-to-services.skill'), 'access-to-services', {
        'SKILL.md': SKILL,
        'README.md': '# Skill readme\n',
        'eval-results.md': 'r\n',
        'data/mo-resources.json': '{}\n',
        'data/SCHEMA.md': 'S\n',
      }, { stampSkill: true });
      stamp('access-to-services', dir);
      return dir;
    }

    test('a repo-root README edit does not make the package stale', () => {
      svcRepo({ 'README.md': NEW });
      const r = runDrift([SVC]);
      expect(r.rows['access-to-services'].packages[0]).toMatchObject({ status: 'fresh', paths: SOURCES, content_date: OLD });
      expect(r.status).toBe(0);
    });

    test('a change to a configured source the package renames (mo-resources.json -> data/) is stale', () => {
      svcRepo({ 'mo-resources.json': NEW });
      const r = runDrift([SVC]);
      expect(r.rows['access-to-services'].packages[0]).toMatchObject({ status: 'stale', newest_path: 'mo-resources.json', content_date: NEW, package_date: MID });
      expect(r.status).toBe(1);
    });

    test('a configured source missing from the repo is a warning, and the rest still count', () => {
      const dir = svcRepo({ 'eval-results.md': NEW });
      fs.rmSync(path.join(dir, 'SCHEMA.md'));
      const r = runDrift([SVC]);
      expect(r.stdout).toMatch(/::warning::.*access-to-services.*SCHEMA\.md/);
      expect(r.rows['access-to-services'].packages[0]).toMatchObject({ status: 'stale', newest_path: 'eval-results.md' });
    });
  });

  describe('install zips (install_zip in repos.json)', () => {
    const MID = '2026-07-01T00:00:00Z';
    const JOBS = { name: 'access-to-jobs', install_zip: 'access-to-jobs.zip' };
    const ZIP_URL = 'https://github.com/dougdevitre/access-to-jobs/releases/download/skill-latest/access-to-jobs.zip';

    function installRepo({ releases, commits }) {
      const dir = repo('access-to-jobs', {
        files: { 'README.md': README, 'SKILL.md': SKILL, 'references/a.md': 'A\n', 'templates/t.md': 'T\n', 'docs/unrelated.md': 'x\n' },
        commits,
        releases,
      });
      stamp('access-to-jobs', dir);
      return dir;
    }
    const release = (date, assets = ['access-to-jobs.zip']) => ({ 'skill-latest': { assets, date } });

    test('a release built after the newest source change is fresh, and the run exits 0', () => {
      installRepo({ releases: release(NEW), commits: { 'SKILL.md': OLD, 'references/a.md': MID } });
      const r = runDrift([JOBS]);
      expect(r.rows['access-to-jobs'].install).toMatchObject({ status: 'fresh', asset: 'access-to-jobs.zip', release_date: NEW, content_date: MID, newest_path: 'references' });
      expect(r.status).toBe(0);
    });

    test('a release older than a change to references/ or templates/ is stale, with both dates and the republish command', () => {
      installRepo({ releases: release(OLD), commits: { 'SKILL.md': OLD, 'templates/t.md': NEW } });
      const r = runDrift([JOBS]);
      expect(r.rows['access-to-jobs'].install).toMatchObject({ status: 'stale', release_date: OLD, content_date: NEW, newest_path: 'templates' });
      expect(r.status).toBe(1);
      expect(r.report).toContain('gh workflow run skill-package.yml -R dougdevitre/access-to-jobs --ref main');
      expect(r.report).toContain(OLD.slice(0, 10));
      expect(r.report).toContain(NEW.slice(0, 10));
    });

    test('changes outside the skill sources (docs/, README.md) do not make it stale', () => {
      installRepo({ releases: release(MID), commits: { 'SKILL.md': OLD, 'docs/unrelated.md': NEW, 'README.md': NEW } });
      const r = runDrift([JOBS]);
      expect(r.rows['access-to-jobs'].install.status).toBe('fresh');
      expect(r.status).toBe(0);
    });

    test('skill/ and a root *.skill package count as sources (access-to-experts, access-to-services)', () => {
      const dir = repo('access-to-experts', {
        files: { 'README.md': README, 'skill/SKILL.md': SKILL },
        commits: { 'skill/SKILL.md': NEW },
        releases: { 'skill-latest': { assets: ['access-to-experts.zip'], date: OLD } },
      });
      stamp('access-to-experts', dir);
      const svc = repo('access-to-services', {
        files: { 'README.md': README },
        commits: { 'access-to-services.skill': NEW },
        releases: { 'skill-latest': { assets: ['access-to-services.zip'], date: OLD } },
      });
      const src = path.join(tmp, 'pkg-src');
      fs.mkdirSync(src);
      fs.writeFileSync(path.join(src, 'SKILL.md'), SKILL);
      zip(path.join(svc, 'access-to-services.skill'), src, ['SKILL.md']);
      stamp('access-to-services', svc);
      const r = runDrift([
        { name: 'access-to-experts', install_zip: 'access-to-experts.zip' },
        { name: 'access-to-services', install_zip: 'access-to-services.zip' },
      ]);
      expect(r.rows['access-to-experts'].install).toMatchObject({ status: 'stale', newest_path: 'skill' });
      expect(r.rows['access-to-services'].install).toMatchObject({ status: 'stale', newest_path: 'access-to-services.skill' });
    });

    test('locales/ counts as a source (access-to-peace ships locales/es/ in its zip)', () => {
      const dir = repo('access-to-peace', {
        files: { 'README.md': README, 'SKILL.md': SKILL, 'locales/es/SKILL.md': SKILL },
        commits: { 'SKILL.md': OLD, 'locales/es/SKILL.md': NEW },
        releases: { 'skill-latest': { assets: ['access-to-peace.zip'], date: MID } },
      });
      stamp('access-to-peace', dir);
      const r = runDrift([{ name: 'access-to-peace', install_zip: 'access-to-peace.zip' }]);
      expect(r.rows['access-to-peace'].install).toMatchObject({ status: 'stale', newest_path: 'locales', release_date: MID, content_date: NEW });
      expect(r.status).toBe(1);
    });

    test('a repo with none of the source paths is n/a, not fresh', () => {
      const dir = repo('access-to-peace', {
        files: { 'README.md': README },
        commits: { 'README.md': NEW },
        releases: { 'skill-latest': { assets: ['access-to-peace.zip'], date: OLD } },
      });
      stamp('access-to-peace', dir);
      const r = runDrift([{ name: 'access-to-peace', install_zip: 'access-to-peace.zip' }]);
      expect(r.rows['access-to-peace'].install.status).toBe('n/a');
      expect(r.status).toBe(0);
    });

    test('a repo with install_zip but no skill-latest release is flagged: exit 1, fix in the report', () => {
      installRepo({ releases: {}, commits: { 'SKILL.md': OLD } });
      const r = runDrift([JOBS]);
      expect(r.rows['access-to-jobs'].install).toMatchObject({ status: 'missing release', asset: 'access-to-jobs.zip' });
      expect(r.status).toBe(1);
      expect(r.report).toContain('No `skill-latest` release');
      expect(r.report).toContain('skill-package.yml -R dougdevitre/access-to-jobs');
    });

    test('a release without the named asset is flagged', () => {
      installRepo({ releases: release(NEW, ['something-else.zip']), commits: { 'SKILL.md': OLD } });
      const r = runDrift([JOBS]);
      expect(r.rows['access-to-jobs'].install).toMatchObject({ status: 'missing asset', asset: 'access-to-jobs.zip' });
      expect(r.status).toBe(1);
    });

    test('a full release URL is checked the same way as a filename', () => {
      installRepo({ releases: {}, commits: { 'SKILL.md': OLD } });
      const r = runDrift([{ name: 'access-to-jobs', install_zip: ZIP_URL }]);
      expect(r.rows['access-to-jobs'].install).toMatchObject({ status: 'missing release', asset: 'access-to-jobs.zip' });
    });

    test('a URL outside the skill-latest release is reported as external, not a finding', () => {
      installRepo({ releases: {}, commits: { 'SKILL.md': OLD } });
      const r = runDrift([{ name: 'access-to-jobs', install_zip: 'https://example.org/jobs.zip' }]);
      expect(r.rows['access-to-jobs'].install.status).toBe('external');
      expect(r.status).toBe(0);
    });

    test('a repo without install_zip is not checked for a release', () => {
      installRepo({ releases: {}, commits: { 'SKILL.md': NEW } });
      const r = runDrift(['access-to-jobs']);
      expect(r.rows['access-to-jobs'].install.status).toBe('none');
      expect(r.status).toBe(0);
    });

    test('text mode shows the install status column', () => {
      installRepo({ releases: release(OLD), commits: { 'SKILL.md': NEW } });
      const r = runDrift([JOBS], { LOG_FORMAT: 'text' });
      expect(r.stdout).toMatch(/access-to-jobs\s+in sync\s+stale/);
    });
  });

  test('text mode prints a table row per repo', () => {
    stamp('access-to-safety', repo('access-to-safety', { files: { 'README.md': README } }));
    const r = runDrift(['access-to-safety'], { LOG_FORMAT: 'text' });
    expect(r.stdout).toMatch(/access-to-safety\s+.*in sync/);
  });
});
