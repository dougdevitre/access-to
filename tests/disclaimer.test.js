/**
 * Shared disclaimer.
 *
 * The wording lives once, in .github/disclaimer/, and sync-disclaimer.sh stamps
 * it into every repo (DISCLAIMER.md, a README notice, a SKILL.md notice). These
 * tests pin the promises the disclaimer makes, that the sync is idempotent and
 * leaves everything outside its markers alone, and that every hub page carries
 * the notice.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');
const SCRIPT = path.join(ROOT, '.github/scripts/sync-disclaimer.sh');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const run = (args) => spawnSync(SCRIPT, args, { encoding: 'utf-8' });

describe('Shared disclaimer', () => {
  describe('wording', () => {
    const full = read('.github/disclaimer/DISCLAIMER.md');
    const readme = read('.github/disclaimer/readme-notice.md');
    const skill = read('.github/disclaimer/skill-notice.md');

    test.each([
      ['educational only', /general educational information only/],
      ['not professional advice', /not legal, medical, mental health, financial or safety advice/],
      ['no professional relationship', /does not create an attorney-client, clinician-patient/],
      ['emergency line', /\*\*911\*\*/],
      ['crisis line', /\*\*988\*\*/],
      ['verify with official sources', /Confirm everything with the official source/],
      ['AI can be wrong', /AI output can be incorrect/],
      ['no identifying details', /Do not enter names, case numbers, addresses/],
      ['no endorsement', /Not affiliated with or endorsed by/],
      ['no warranty', /Provided "as is," without warranties/],
    ])('full text covers: %s', (_, re) => expect(full).toMatch(re));

    test('README and skill notices carry 911, 988 and the no-advice line', () => {
      [readme, skill].forEach((t) => {
        expect(t).toContain('911');
        expect(t).toContain('988');
        expect(t).toMatch(/not legal, medical, mental health, financial or safety advice/);
        expect(t).toContain('{{TITLE}}');
      });
    });

    test('every template names the project through the title placeholder', () => {
      expect(full).toContain('{{TITLE}}');
    });
  });

  describe('sync script', () => {
    let dir;
    const README = '# Sample Tool\n\nIntro paragraph.\n\n## Usage\n\nSteps.\n';
    const SKILL = '---\nname: sample\ndescription: A sample.\n---\n\n# Sample Skill\n\n## Disclaimer\n\nTopic-specific text.\n';

    beforeEach(() => {
      dir = fs.mkdtempSync(path.join(os.tmpdir(), 'disc-'));
      fs.writeFileSync(path.join(dir, 'README.md'), README);
      fs.writeFileSync(path.join(dir, 'SKILL.md'), SKILL);
    });
    afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

    test('stamps all three places with the registry title', () => {
      expect(run(['access-to-safety', dir]).status).toBe(0);
      const disc = fs.readFileSync(path.join(dir, 'DISCLAIMER.md'), 'utf-8');
      const readme = fs.readFileSync(path.join(dir, 'README.md'), 'utf-8');
      const skill = fs.readFileSync(path.join(dir, 'SKILL.md'), 'utf-8');
      expect(disc).toMatch(/^# Disclaimer — Access to Safety/);
      expect(readme.split('\n')[0]).toBe('# Sample Tool');
      expect(readme.indexOf('BEGIN DISCLAIMER')).toBeLessThan(readme.indexOf('Intro paragraph.'));
      expect(skill.startsWith('---\nname: sample\ndescription: A sample.\n---\n\n<!-- BEGIN DISCLAIMER')).toBe(true);
      expect(readme).not.toContain('{{TITLE}}');
    });

    test('keeps everything outside its markers, including topic disclaimers', () => {
      run(['access-to-safety', dir]);
      const strip = (s) => s.replace(/<!-- BEGIN DISCLAIMER[\s\S]*?<!-- END DISCLAIMER -->\n\n/, '');
      expect(strip(fs.readFileSync(path.join(dir, 'README.md'), 'utf-8'))).toBe(README);
      expect(strip(fs.readFileSync(path.join(dir, 'SKILL.md'), 'utf-8'))).toBe(SKILL);
    });

    test('is idempotent, and --check fails only when a repo is out of date', () => {
      expect(run(['--check', 'access-to-safety', dir]).status).toBe(1);
      run(['access-to-safety', dir]);
      const once = fs.readFileSync(path.join(dir, 'README.md'), 'utf-8');
      run(['access-to-safety', dir]);
      expect(fs.readFileSync(path.join(dir, 'README.md'), 'utf-8')).toBe(once);
      expect(run(['--check', 'access-to-safety', dir]).status).toBe(0);
    });

    test('replaces an outdated block in place instead of adding a second one', () => {
      run(['access-to-safety', dir]);
      const f = path.join(dir, 'README.md');
      fs.writeFileSync(f, fs.readFileSync(f, 'utf-8').replace('Educational information only.', 'Old wording.'));
      run(['access-to-safety', dir]);
      const s = fs.readFileSync(f, 'utf-8');
      expect(s).not.toContain('Old wording.');
      expect(s.match(/BEGIN DISCLAIMER/g)).toHaveLength(1);
    });

    test('refuses a repo that is not in the registry', () => {
      expect(run(['not-a-repo', dir]).status).toBe(1);
    });
  });

  describe('hub', () => {
    test('the hub README and DISCLAIMER.md are in sync with the shared wording', () => {
      expect(() => execFileSync(SCRIPT, ['--check', 'access-to', ROOT], { stdio: 'pipe' })).not.toThrow();
    });

    test('every hub page shows the notice with 911 and 988', () => {
      fs.readdirSync(ROOT).filter((f) => f.endsWith('.html')).forEach((f) => {
        const $ = cheerio.load(read(f));
        const notice = $('#disclaimer').text() || $('.footer-notice').text();
        expect(`${f}: ${notice}`).toMatch(/911/);
        expect(notice).toMatch(/988/);
        expect(notice).toMatch(/not legal, medical/i);
      });
    });

    test('footer notices link to the full disclaimer', () => {
      fs.readdirSync(ROOT).filter((f) => f.endsWith('.html') && f !== 'index.html').forEach((f) => {
        const $ = cheerio.load(read(f));
        expect($('.footer-notice a').attr('href')).toBe('index.html#disclaimer');
      });
    });
  });
});
