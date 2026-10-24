/**
 * Crisis conformance scan.
 *
 * crisis-conformance.sh fetches every repo's SKILL.md (read-only) and reports
 * whether it carries the shared disclaimer block, "911" and "988" in its own
 * text, a location check, a language rule, and a Missouri label on every
 * line with a Missouri-area-code phone number. The phrases live in
 * .github/config/crisis-conformance.json. These tests replace `gh` with
 * tests/helpers/fake-gh.js, which serves fixture directories, so they need no
 * network.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SCRIPT = path.join(ROOT, '.github/scripts/crisis-conformance.sh');
const SYNC = path.join(ROOT, '.github/scripts/sync-disclaimer.sh');
const CONFIG = path.join(ROOT, '.github/config/crisis-conformance.json');
const FAKE_GH = path.join(__dirname, 'helpers/fake-gh.js');
const WORKFLOW = path.join(ROOT, '.github/workflows/ecosystem-drift.yml');

jest.setTimeout(30000);

let tmp;
let fixtures;

beforeEach(() => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'crisis-'));
  fixtures = path.join(tmp, 'fixtures');
  fs.mkdirSync(path.join(tmp, 'bin'), { recursive: true });
  fs.mkdirSync(fixtures);
  fs.symlinkSync(FAKE_GH, path.join(tmp, 'bin', 'gh'));
});
afterEach(() => fs.rmSync(tmp, { recursive: true, force: true }));

const GOOD_BODY = [
  'If someone is in danger now, give 911 first; for a crisis, 988 (call or text).',
  'Ask what state the person is in once. Outside Missouri, give the national line.',
  'Reply in the language the person writes in.',
  '',
].join('\n');

const skillMd = (body = GOOD_BODY) => `---\nname: access-to-safety\ndescription: Safety navigator.\n---\n\n# Access to Safety\n\n${body}`;

/** Create a fixture repo. files: { relPath: content }. With stamp, the shared disclaimer is stamped in. */
function repo(name, { files = {}, stamp = true, priv = false } = {}) {
  const dir = path.join(fixtures, name, 'files');
  fs.mkdirSync(dir, { recursive: true });
  Object.entries(files).forEach(([rel, content]) => {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), content);
  });
  if (stamp) {
    const r = spawnSync(SYNC, [name, dir], { encoding: 'utf-8' });
    if (r.status !== 0) throw new Error(r.stdout + r.stderr);
  }
  fs.writeFileSync(path.join(fixtures, name, 'meta.json'), JSON.stringify({ private: priv, commits: {} }));
  return dir;
}

function registry(repos) {
  const f = path.join(tmp, 'repos.json');
  fs.writeFileSync(f, JSON.stringify({ owner: 'dougdevitre', repos: repos.map((r) => (typeof r === 'string' ? { name: r } : r)) }));
  return f;
}

function run(repos, env = {}) {
  const report = path.join(tmp, 'report.md');
  const r = spawnSync(SCRIPT, ['--report', report, registry(repos)], {
    encoding: 'utf-8',
    env: { ...process.env, PATH: `${path.join(tmp, 'bin')}:${process.env.PATH}`, FAKE_GH_ROOT: fixtures, LOG_FORMAT: 'json', GITHUB_STEP_SUMMARY: '', ...env },
  });
  const rows = r.stdout.split('\n').filter((l) => l.startsWith('{')).map((l) => JSON.parse(l)).filter((o) => o.repo);
  return { ...r, rows: Object.fromEntries(rows.map((o) => [o.repo, o])), report: fs.existsSync(report) ? fs.readFileSync(report, 'utf-8') : '' };
}

function customConfig(overrides) {
  const f = path.join(tmp, 'config.json');
  fs.writeFileSync(f, JSON.stringify({ ...JSON.parse(fs.readFileSync(CONFIG, 'utf-8')), ...overrides }));
  return { CRISIS_CONFORMANCE_CONFIG: f };
}

describe('crisis-conformance.sh', () => {
  test('exists and sources the shared logging library', () => {
    expect(fs.existsSync(SCRIPT)).toBe(true);
    expect(fs.readFileSync(SCRIPT, 'utf-8')).toMatch(/source "\$SCRIPT_DIR\/lib-log\.sh"/);
  });

  test('the config lists every rule the scan reads', () => {
    const cfg = JSON.parse(fs.readFileSync(CONFIG, 'utf-8'));
    expect(cfg.required_numbers).toEqual(['911', '988']);
    expect(cfg.location_phrases).toEqual(expect.arrayContaining(['what state', 'outside Missouri', 'Missouri only']));
    expect(cfg.language_phrases).toEqual(expect.arrayContaining(['language the person writes in', 'respond in Spanish', 'en español']));
    expect(cfg.missouri_area_codes).toEqual(['314', '573', '636', '660', '816']);
    expect(cfg.missouri_labels).toEqual(expect.arrayContaining(['Missouri', 'MO', 'St. Louis']));
  });

  test('an invalid config stops the scan with exit 1 instead of passing every repo', () => {
    repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
    const r = run(['access-to-safety'], customConfig({ location_phrases: [] }));
    expect(r.status).toBe(1);
    expect(r.stdout + r.stderr).toMatch(/Invalid config/);
    const r2 = run(['access-to-safety'], customConfig({ missouri_area_codes: ['31'] }));
    expect(r2.status).toBe(1);
    expect(r2.stdout + r2.stderr).toMatch(/Invalid config/);
  });

  test('a conforming SKILL.md is ok on every column, and the run exits 0', () => {
    repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
    const r = run(['access-to-safety']);
    expect(r.status).toBe(0);
    expect(r.rows['access-to-safety']).toMatchObject({
      status: 'ok', source: 'SKILL.md', disclaimer: 'present', numbers: { 911: 'yes', 988: 'yes' },
      location_check: { status: 'yes', phrase: 'what state' }, language_rule: { status: 'yes', phrase: 'language the person writes in' },
      unlabelled_missouri_numbers: [],
    });
    expect(r.report.split('\n')[0]).toBe('<!-- crisis-conformance findings=0 errors=0 skipped=0 -->');
    expect(r.report).toContain('| access-to-safety | `SKILL.md` | present | yes | yes | yes ("what state"');
  });

  describe('disclaimer and crisis numbers', () => {
    test('a SKILL.md without the shared block is missing: exit 1, stamp command in the report', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd() }, stamp: false });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety']).toMatchObject({ status: 'findings', disclaimer: 'missing' });
      expect(r.report).toContain('sync-disclaimer.sh access-to-safety');
    });

    test('a number that appears only inside the notice is "notice only", a finding', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace('give 911 first', 'get help first')) } });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].numbers).toEqual({ 911: 'notice only', 988: 'yes' });
      expect(r.report).toContain('"911" appears only inside the disclaimer notice');
    });

    test('with required_numbers_outside_notice false, the notice counts', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace('give 911 first', 'get help first')) } });
      const r = run(['access-to-safety'], customConfig({ required_numbers_outside_notice: false }));
      expect(r.status).toBe(0);
      expect(r.rows['access-to-safety'].numbers).toEqual({ 911: 'yes', 988: 'yes' });
    });

    test('a number absent from the whole file is "no"', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace('988', 'the crisis line')) }, stamp: false });
      const r = run(['access-to-safety']);
      expect(r.rows['access-to-safety'].numbers).toEqual({ 911: 'yes', 988: 'no' });
      expect(r.report).toContain('"988" does not appear anywhere');
    });
  });

  describe('location check and language rule', () => {
    test('no location phrase is a finding; the match is case-insensitive and reported with its line', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace(/what state.*national line\./, 'Missouri resources follow.')) } });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].location_check).toEqual({ status: 'no' });
      expect(r.report).toContain('No location check');

      repo('access-to-peace', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace('what state', 'WHICH STATE')) } });
      const r2 = run(['access-to-peace']);
      expect(r2.rows['access-to-peace'].location_check).toMatchObject({ status: 'yes', phrase: 'which state', line: expect.any(Number) });
    });

    test('no language phrase is a finding', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace(/Reply in the language.*\n/, '')) } });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].language_rule).toEqual({ status: 'no' });
      expect(r.report).toContain('No language rule');
    });

    test('the stamped notice never satisfies a phrase rule', () => {
      // "read before use" is in the shared notice and nowhere else.
      repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
      const r = run(['access-to-safety'], customConfig({ location_phrases: ['read before use'], language_phrases: ['read before use'] }));
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].location_check).toEqual({ status: 'no' });
      expect(r.rows['access-to-safety'].language_rule).toEqual({ status: 'no' });
    });

    test('loose wording that is not an instruction does not pass (the live Business false pass)', () => {
      const body = GOOD_BODY.replace(/Ask what state.*national line\./, "To deploy elsewhere, replace Missouri-specific data with your state's ecosystem.")
        .replace('Reply in the language the person writes in.', 'The intake brochure is also available in Spanish.');
      repo('access-to-business', { files: { 'SKILL.md': skillMd(body) } });
      const r = run(['access-to-business']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-business'].location_check).toEqual({ status: 'no' });
      expect(r.rows['access-to-business'].language_rule).toEqual({ status: 'no' });
    });

    test('line numbers are SKILL.md line numbers, counting the disclaimer block', () => {
      const dir = repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
      const lines = fs.readFileSync(path.join(dir, 'SKILL.md'), 'utf-8').split('\n');
      const r = run(['access-to-safety']);
      const n = r.rows['access-to-safety'].location_check.line;
      expect(lines.findIndex((l) => l.includes('BEGIN DISCLAIMER'))).toBeLessThan(n - 1);
      expect(lines[n - 1]).toContain('what state');
    });

    test('the phrases come from the config file, not the script', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(GOOD_BODY.replace('what state', 'where you live').replace('language the person writes in', 'idioma del usuario')) } });
      expect(run(['access-to-safety']).status).toBe(1);
      const r = run(['access-to-safety'], customConfig({ location_phrases: ['where you live'], language_phrases: ['idioma del usuario'] }));
      expect(r.status).toBe(0);
      expect(r.rows['access-to-safety'].location_check.phrase).toBe('where you live');
    });
  });

  describe('Missouri-area-code numbers', () => {
    test('a line with a 314/573/636/660/816 number and no Missouri label is a finding, with the line and number', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(`${GOOD_BODY}| Crisis line | 314-819-8811 | 24/7 |\n| Police | (636) 529-8210 | non-emergency |\n`) } });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(1);
      expect(r.rows['access-to-safety'].unlabelled_missouri_numbers).toEqual([
        { line: 21, number: '314-819-8811' },
        { line: 22, number: '(636) 529-8210' },
      ]);
      expect(r.report).toContain('Line 21: `314-819-8811` has a Missouri area code');
    });

    test('a line that says Missouri, MO or St. Louis passes; MO must be a whole word', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(`${GOOD_BODY}- Missouri APS: 573-751-3350\n- Adult abuse (MO): 816-555-0100\n- St. Louis legal aid: 314-534-4200\n- MOBILE crisis team: 660-555-0100\n`) } });
      const r = run(['access-to-safety']);
      expect(r.rows['access-to-safety'].unlabelled_missouri_numbers).toEqual([{ line: 24, number: '660-555-0100' }]);
    });

    test('toll-free numbers and other digit strings are not Missouri numbers', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd(`${GOOD_BODY}- Childhelp 1-800-422-4453; Eldercare 1-800-677-1116; text 741741; budget $3,145,000; RSMo 573.010\n`) } });
      const r = run(['access-to-safety']);
      expect(r.status).toBe(0);
      expect(r.rows['access-to-safety'].unlabelled_missouri_numbers).toEqual([]);
    });
  });

  describe('where SKILL.md lives', () => {
    test('skill/SKILL.md is scanned when there is no root SKILL.md', () => {
      repo('access-to-experts', { files: { 'README.md': '# T\n', 'skill/SKILL.md': skillMd() } });
      const r = run(['access-to-experts']);
      expect(r.rows['access-to-experts']).toMatchObject({ status: 'ok', source: 'skill/SKILL.md' });
    });

    test('a SKILL.md inside a root *.skill tarball is scanned and named by package', () => {
      const dir = repo('access-to-services', { files: { 'README.md': '# T\n' } });
      const src = fs.mkdtempSync(path.join(tmp, 'pkg-'));
      fs.mkdirSync(path.join(src, 'access-to-services'));
      fs.writeFileSync(path.join(src, 'access-to-services', 'SKILL.md'), skillMd().replace('name: access-to-safety', 'name: access-to-services'));
      spawnSync(SYNC, ['access-to-services', path.join(src, 'access-to-services')]);
      spawnSync('tar', ['-czf', path.join(dir, 'access-to-services.skill'), '-C', src, 'access-to-services']);
      const r = run(['access-to-services']);
      expect(r.rows['access-to-services']).toMatchObject({ status: 'ok', source: 'access-to-services.skill:access-to-services/SKILL.md' });
    });

    test('a repo with no SKILL.md anywhere is n/a, not a finding; the hub is never scanned', () => {
      repo('access-to-food', { files: { 'README.md': '# App\n' } });
      repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
      const r = run([{ name: 'access-to', role: 'hub' }, 'access-to-food', 'access-to-safety']);
      expect(r.status).toBe(0);
      expect(r.rows['access-to-food'].status).toBe('n/a');
      expect(r.rows['access-to']).toBeUndefined();
      expect(r.report).toContain('| access-to-food | none (n/a) |');
    });

    test('a private repo the token cannot read is skipped with a warning, not a failure', () => {
      repo('access-to-safety', { files: { 'SKILL.md': skillMd() } });
      const r = run(['access-to-safety', 'access-to-energy']);
      expect(r.status).toBe(0);
      expect(r.rows['access-to-energy'].status).toBe('skipped');
      expect(r.stdout).toMatch(/::warning::.*access-to-energy/);
      expect(r.report).toContain('ECOSYSTEM_READ_TOKEN');
    });

    test('never writes to a child repo: the script has no write call to the GitHub API', () => {
      const src = fs.readFileSync(SCRIPT, 'utf-8');
      expect(src).not.toMatch(/gh api[^\n]*(-X|--method)\s*(POST|PUT|PATCH|DELETE)/);
      expect(src).not.toMatch(/\bgit (push|commit)\b/);
      expect(src).not.toMatch(/graphql/i);
    });

    test('never writes to the fixture (read-only)', () => {
      const dir = repo('access-to-safety', { files: { 'SKILL.md': skillMd('No numbers here.\n') } });
      const before = fs.readFileSync(path.join(dir, 'SKILL.md'), 'utf-8');
      run(['access-to-safety']);
      expect(fs.readdirSync(dir).sort()).toEqual(['DISCLAIMER.md', 'SKILL.md']);
      expect(fs.readFileSync(path.join(dir, 'SKILL.md'), 'utf-8')).toBe(before);
    });
  });
});

describe('ecosystem-drift.yml runs the scan', () => {
  const wf = () => fs.readFileSync(WORKFLOW, 'utf-8');

  test('a step runs crisis-conformance.sh with --report, on the read token', () => {
    expect(wf()).toMatch(/id: crisis\n\s+env:\n\s+GH_TOKEN: \$\{\{ secrets\.ECOSYSTEM_READ_TOKEN \|\| github\.token \}\}\n\s+run: \|\n\s+set \+e\n\s+\.github\/scripts\/crisis-conformance\.sh --report "\$RUNNER_TEMP\/crisis\.md"/);
  });

  test('its report goes into the one tracking issue, counted with the others', () => {
    const w = wf();
    expect(w).toContain('CRISIS_RC: ${{ steps.crisis.outputs.rc }}');
    expect(w).toMatch(/FINDINGS=\$\(\(.*\$\(count findings "\$CRISIS_REPORT"\)/);
    expect(w).toMatch(/ERRORS=\$\(\(.*\$\(count errors "\$CRISIS_REPORT"\)/);
    expect(w).toMatch(/for EXTRA in "\$ZIP_REPORT" "\$CRISIS_REPORT"/);
    expect(w).toContain('ISSUE_TITLE: Ecosystem drift (monthly check)');
  });

  test('a missing report fails the job, and a non-conforming scan keeps the run red', () => {
    const w = wf();
    expect(w).toMatch(/if \[ ! -s "\$CRISIS_REPORT" \]; then[\s\S]*?exit 1/);
    expect(w).toMatch(/\[ "\$CRISIS_RC" -ne 0 \]; then exit 1; fi/);
  });

  test('it still does not run on pull requests', () => {
    expect(wf()).not.toMatch(/^\s*pull_request/m);
  });
});
