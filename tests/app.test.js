/**
 * Homepage app (index.html + app.css + app.js).
 *
 * The app is generated from config: render-hub.sh writes one door per listed
 * project and embeds the data app.js reads. These tests pin the promises the
 * page makes: every door works without JavaScript, the data matches the
 * registry, the transcripts match what the narration generator speaks, touch
 * targets stay large, and the disclaimer and crisis lines are always present.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const repos = JSON.parse(read('.github/config/repos.json'));
const journey = JSON.parse(read('.github/config/journey.json'));
const narration = JSON.parse(read('.github/config/narration.json'));
const listed = repos.repos.filter((r) => r.role !== 'hub' && (r.listed ?? true));

const $ = cheerio.load(read('index.html'));
const data = JSON.parse($('#app-data').text());
const css = read('app.css');

describe('Homepage app', () => {
  describe('doors (the table of contents)', () => {
    const doors = $('a.door');

    test('one door per listed project in repos.json', () => {
      expect(doors.length).toBe(listed.length);
      const ids = doors.map((_, d) => $(d).attr('data-id')).get().sort();
      expect(ids).toEqual(listed.map((r) => r.name).sort());
    });

    test('every door is a real link, so it works without JavaScript', () => {
      doors.each((_, d) => {
        const href = $(d).attr('href');
        expect(href).toBeTruthy();
        expect(href).not.toBe('#');
      });
    });

    test('private projects never link to their (private) repository', () => {
      listed.filter((r) => r.visibility === 'private').forEach((r) => {
        const href = $(`a.door[data-id="${r.name}"]`).attr('href');
        expect(href).not.toContain(`github.com/${repos.owner}/${r.name}`);
      });
    });

    test('external doors open safely in a new tab', () => {
      $('a[target="_blank"]').each((_, a) => {
        expect($(a).attr('rel') || '').toContain('noopener');
      });
    });

    test('each door carries its project color and a name', () => {
      doors.each((_, d) => {
        expect($(d).attr('style')).toMatch(/--c:#[0-9A-Fa-f]{6}/);
        expect($(d).find('.door-name').text().trim().length).toBeGreaterThan(0);
      });
    });
  });

  describe('embedded data', () => {
    test('lists every project with its connections limited to listed projects', () => {
      expect(data.projects.length).toBe(listed.length);
      const names = new Set(listed.map((r) => r.name));
      data.projects.forEach((p) => p.connects.forEach((c) => expect(names.has(c)).toBe(true)));
    });

    test('the JSON cannot close its own <script> element', () => {
      const raw = read('index.html');
      const block = raw.slice(raw.indexOf('id="app-data">'), raw.indexOf('</script>', raw.indexOf('id="app-data">')));
      expect(block).not.toMatch(/<\/(?!script)/i);
    });

    test('transcripts match exactly what the narration generator speaks', () => {
      const clips = JSON.parse(execFileSync(path.join(ROOT, '.github/scripts/narration-clips.sh'), { encoding: 'utf-8' }));
      const expected = Object.fromEntries(clips.filter((c) => c.lang === 'en').map((c) => [c.id, c.text]));
      expect(data.clips).toEqual(expected);
    });

    test('there is a clip for the welcome, the practice, the guide, the gates and every project', () => {
      ['welcome', 'distribute', 'finder', 'gates', ...listed.map((r) => r.name)].forEach((id) => {
        expect(typeof data.clips[id]).toBe('string');
        expect(data.clips[id].length).toBeGreaterThan(20);
      });
    });
  });

  describe('find my door', () => {
    const F = journey.finder;
    const names = new Set(listed.map((r) => r.name));

    test('three questions: roles, needs and places all have options', () => {
      expect(F.roles.length).toBeGreaterThanOrEqual(3);
      expect(F.needs.length).toBeGreaterThanOrEqual(5);
      expect(F.places.map((p) => p.id)).toContain('missouri');
    });

    test('every need points only at listed projects, and at least one', () => {
      F.needs.forEach((n) => {
        expect(n.doors.length).toBeGreaterThanOrEqual(1);
        n.doors.forEach((d) => expect(names.has(d)).toBe(true));
      });
    });

    test('every role says whether it adopts tools or is seeking help', () => {
      F.roles.forEach((r) => expect(['adopt', 'help']).toContain(r.lens));
      expect(F.roles.some((r) => r.lens === 'help')).toBe(true);
    });

    test('a safety need exists and shows 911, a DV hotline and 988 first', () => {
      expect(F.needs.some((n) => n.crisis)).toBe(true);
      expect(F.crisis_note).toContain('911');
      expect(F.crisis_note).toContain('1-800-799-7233');
      expect(F.crisis_note).toContain('988');
    });

    test('the page intro matches the narrated intro', () => {
      expect($('#finder .section-lead').text().trim()).toBe(F.intro);
    });

    test('the guide degrades to the doors without JavaScript', () => {
      expect($('#finder-start').attr('hidden')).toBeDefined();
      expect($('#finder-flow').attr('hidden')).toBeDefined();
      expect($('#finder noscript').length).toBe(1);
    });
  });

  describe('journey content (Distributed Virtue)', () => {
    test('BEACON is six steps in order', () => {
      expect(journey.beacon.map((s) => s.letter).join('')).toBe('BEACON');
    });

    test('nine virtues, each with a question and a mindful practice', () => {
      expect(journey.virtues).toHaveLength(9);
      journey.virtues.forEach((v) => {
        expect(v.question).toMatch(/\?$/);
        expect(v.practice.length).toBeGreaterThan(10);
      });
    });

    test('four gates', () => {
      expect(journey.gates).toHaveLength(4);
    });

    test('every listed project has an adopter and a first pilot', () => {
      listed.forEach((r) => {
        expect(journey.adoption[r.name]).toBeDefined();
        expect(journey.adoption[r.name].adopter).toBeTruthy();
        expect(journey.adoption[r.name].pilot).toBeTruthy();
      });
    });
  });

  describe('narration', () => {
    test('voice is a 20-character ElevenLabs id and no key is stored in config', () => {
      expect(narration.voice_id).toMatch(/^[A-Za-z0-9]{20}$/);
      const { _readme, ...settings } = narration;
      expect(Object.keys(settings).join(' ')).not.toMatch(/key|token|secret/i);
      expect(JSON.stringify(settings)).not.toMatch(/sk_[A-Za-z0-9]{10,}|[a-f0-9]{32}/);
    });

    test('audio manifest is valid JSON and every listed file exists', () => {
      const manifest = JSON.parse(read('audio/manifest.json'));
      Object.values(manifest.clips || {}).forEach((c) => {
        expect(fs.existsSync(path.join(ROOT, c.file))).toBe(true);
      });
    });

    test('play buttons start hidden and only appear when a clip exists', () => {
      $('[data-clip]').each((_, b) => expect($(b).attr('hidden')).toBeDefined());
      expect(css).toMatch(/\[hidden\]\s*\{\s*display:\s*none\s*!important/);
    });

    test('every play button has a readable transcript', () => {
      expect($('details.transcript[data-transcript="welcome"]').length).toBe(1);
      expect($('.sheet-transcript').length).toBe(1);
    });
  });

  describe('mobile first and accessible', () => {
    test('primary touch targets are at least 56px; doors at least 120px tall', () => {
      expect(Number(css.match(/--tap:\s*(\d+)px/)[1])).toBeGreaterThanOrEqual(56);
      const doorRule = css.match(/\.door\s*\{[^}]*min-height:\s*(\d+)px/);
      expect(Number(doorRule[1])).toBeGreaterThanOrEqual(120);
    });

    test('sound and theme toggles are labelled; sound exposes its state', () => {
      expect($('#sound-toggle').attr('aria-pressed')).toBeDefined();
      expect($('#sound-toggle').attr('aria-label')).toBeTruthy();
      expect($('#theme-toggle').attr('aria-label')).toBeTruthy();
    });

    test('has a nav landmark and a labelled dialog for project details', () => {
      expect($('nav').length).toBeGreaterThanOrEqual(1);
      expect($('dialog#sheet').attr('aria-labelledby')).toBe('sheet-title');
    });

    test('dark mode and reduced motion are both handled', () => {
      expect(css).toContain('[data-theme="dark"]');
      expect(css).toContain('prefers-reduced-motion: reduce');
    });
  });

  describe('safety', () => {
    test('disclaimer with emergency and crisis lines is on the page', () => {
      const notice = $('#disclaimer').text();
      expect(notice).toContain('911');
      expect(notice).toContain('988');
      expect(notice).toMatch(/not legal, medical/i);
    });

    test('every project sheet repeats the short disclaimer', () => {
      expect($('.sheet-fine').text()).toMatch(/not legal, medical or safety advice/);
    });
  });
});
