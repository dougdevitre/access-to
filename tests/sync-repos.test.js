/**
 * sync-repos.sh retry logging.
 *
 * gh_retry wraps every gh call and is captured through $(...) or a pipe into
 * jq, so whatever it prints on stdout becomes the captured value. Its "Retry"
 * log line must go to stderr, or a retried call corrupts the project id (jq
 * fails on the log line) and the per-repo failure detail. These tests replace
 * `gh` with tests/helpers/fake-gh.js, which serves `gh project` from a
 * fixture file and can fail a call transiently, so they never touch GitHub.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const SCRIPT = path.join(ROOT, '.github/scripts/sync-repos.sh');
const FAKE_GH = path.join(__dirname, 'helpers/fake-gh.js');
const OWNER = 'dougdevitre';
const url = (name) => `https://github.com/${OWNER}/${name}`;

jest.setTimeout(30000);

let tmp;

beforeEach(() => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-repos-'));
  fs.mkdirSync(path.join(tmp, 'bin'));
  fs.mkdirSync(path.join(tmp, 'fixtures'));
  fs.symlinkSync(FAKE_GH, path.join(tmp, 'bin', 'gh'));
});
afterEach(() => fs.rmSync(tmp, { recursive: true, force: true }));

/** Run sync-repos.sh against a fake project. fail: { list | <url>: n } */
function runSync(names, { items = [], fail = {}, env = {} } = {}) {
  const config = path.join(tmp, 'repos.json');
  fs.writeFileSync(config, JSON.stringify({ owner: OWNER, project_number: 1, repos: names.map((name) => ({ name })) }));
  fs.writeFileSync(path.join(tmp, 'fixtures', 'project.json'), JSON.stringify({
    projects: [{ number: 2, id: 'PVT_other' }, { number: 1, id: 'PVT_kwHOAccessTo' }],
    items,
    fail,
  }));
  const summary = path.join(tmp, 'summary.md');
  const r = spawnSync(SCRIPT, [config], {
    encoding: 'utf-8',
    env: {
      ...process.env,
      PATH: `${path.join(tmp, 'bin')}:${process.env.PATH}`,
      FAKE_GH_ROOT: path.join(tmp, 'fixtures'),
      LOG_FORMAT: 'json',
      RETRY_DELAY: '0',
      GITHUB_STEP_SUMMARY: summary,
      ...env,
    },
  });
  const json = r.stdout.split('\n').filter((l) => l.startsWith('{')).map((l) => JSON.parse(l));
  return {
    ...r,
    json,
    actions: Object.fromEntries(json.filter((o) => o.action).map((o) => [o.target, o])),
    summary: fs.existsSync(summary) ? fs.readFileSync(summary, 'utf-8') : '',
  };
}

const all = (r) => r.stdout + r.stderr;

describe('sync-repos.sh', () => {
  test('a retried project list still yields a clean project id (JSON mode)', () => {
    const r = runSync(['access-to-jobs'], { fail: { list: 1 } });
    expect(r.stderr).toMatch(/Retry 1\/3/);
    expect(r.json.map((o) => o.msg)).toContain('Found project ID: PVT_kwHOAccessTo');
    expect(r.actions['access-to-jobs'].status).toBe('added');
    expect(r.status).toBe(0);
  });

  test('the same holds in text mode', () => {
    const r = runSync(['access-to-jobs'], { fail: { list: 2 }, env: { LOG_FORMAT: 'text' } });
    expect(r.stderr).toMatch(/Retry 2\/3/);
    expect(r.stdout).toMatch(/\[INFO\] sync-repos: Found project ID: PVT_kwHOAccessTo\n/);
    expect(r.stdout).toMatch(/sync-repo access-to-jobs -> added/);
    expect(r.stdout).not.toMatch(/Retry/);
    expect(r.status).toBe(0);
  });

  test('a retried item-add is still sorted into added / skipped by its real output', () => {
    const r = runSync(['access-to-jobs', 'access-to-food'], {
      items: [url('access-to-food')],
      fail: { [url('access-to-jobs')]: 1, [url('access-to-food')]: 1 },
    });
    expect(r.actions['access-to-jobs'].status).toBe('added');
    expect(r.actions['access-to-food']).toMatchObject({ status: 'skipped', detail: 'already in project' });
    expect(r.status).toBe(0);
  });

  test('a call that fails every retry is counted as failed, with only gh output as its detail', () => {
    const r = runSync(['access-to-jobs', 'access-to-food'], { fail: { [url('access-to-food')]: 3 } });
    expect(r.stderr).toMatch(/Retry 2\/3/);
    expect(r.actions['access-to-jobs'].status).toBe('added');
    expect(r.actions['access-to-food']).toMatchObject({ status: 'failed', detail: 'gh: Bad Gateway (HTTP 502)' });
    expect(r.summary).toContain('| Added | 1 |');
    expect(r.summary).toContain('| Failed | 1 |');
    expect(r.summary).toContain('| access-to-food | **Failed**: gh: Bad Gateway (HTTP 502) |');
    expect(r.summary).not.toMatch(/Retry/);
    expect(all(r)).toMatch(/::error::1 repo\(s\) failed to sync/);
    expect(r.json.filter((o) => o.level === 'error').map((o) => o.msg)).toEqual(['1 repo(s) failed to sync']);
    expect(r.status).toBe(1);
  });

  test('a warning and an error logged after a retried call are still counted in the summary', () => {
    // The retry line goes to stderr, but lib-log's counters must still see
    // every log_warn / log_error the script makes. Probe: the same script with
    // one warning and one error logged right after the retried project list.
    const src = fs.readFileSync(SCRIPT, 'utf-8');
    const probe = path.join(tmp, 'probe.sh');
    fs.writeFileSync(probe, src
      .replace('SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"', `SCRIPT_DIR="${path.dirname(SCRIPT)}"`)
      .replace('log_info "Found project ID: $PROJECT_ID"', 'log_info "Found project ID: $PROJECT_ID"\nlog_warn "probe warning"\nlog_error "probe error"'), { mode: 0o755 });
    const config = path.join(tmp, 'repos.json');
    fs.writeFileSync(config, JSON.stringify({ owner: OWNER, project_number: 1, repos: [{ name: 'access-to-jobs' }] }));
    fs.writeFileSync(path.join(tmp, 'fixtures', 'project.json'), JSON.stringify({ projects: [{ number: 1, id: 'PVT_kwHOAccessTo' }], items: [], fail: { list: 1 } }));
    const p = spawnSync(probe, [config], {
      encoding: 'utf-8',
      env: { ...process.env, PATH: `${path.join(tmp, 'bin')}:${process.env.PATH}`, FAKE_GH_ROOT: path.join(tmp, 'fixtures'), LOG_FORMAT: 'json', RETRY_DELAY: '0', GITHUB_STEP_SUMMARY: '' },
    });
    const done = p.stdout.split('\n').filter((l) => l.startsWith('{')).map((l) => JSON.parse(l)).find((o) => o.msg === 'Run complete');
    expect(p.stderr).toMatch(/Retry 1\/3/);
    expect(done).toMatchObject({ warnings: 1, errors: 1 });
    expect(p.status).toBe(0);
  });

  test('gh_retry logs only to stderr', () => {
    const src = fs.readFileSync(SCRIPT, 'utf-8');
    const body = src.match(/^gh_retry\(\) \{\n([\s\S]*?)^\}/m);
    expect(body).not.toBeNull();
    const calls = body[1].split('\n').filter((l) => /^\s*(log_\w+|sub_\w+)/.test(l));
    expect(calls.length).toBeGreaterThan(0);
    calls.forEach((l) => expect(l).toMatch(/^\s*sub_\w+ |>&2\s*$/));
  });
});
