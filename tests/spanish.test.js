/**
 * Spanish homepage (es/index.html).
 *
 * render-hub.sh builds es/index.html from index.html and the Spanish config:
 * .github/config/i18n/es.json (page strings, UI words, labels, joining phrases,
 * project copy) and .github/config/journey.es.json (the journey content). These
 * tests pin the promises: nothing on the English page goes untranslated, every
 * listed project has Spanish copy, the transcripts are exactly what will be
 * spoken, the crisis lines are present in Spanish, the language switch and
 * hreflang links are on both homepages, and the page works before audio exists.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const json = (f) => JSON.parse(read(f));
const repos = json('.github/config/repos.json');
const journey = json('.github/config/journey.json');
const journeyEs = json('.github/config/journey.es.json');
const en = json('.github/config/i18n/en.json');
const es = json('.github/config/i18n/es.json');
const listed = repos.repos.filter((r) => r.role !== 'hub' && (r.listed ?? true));

const enHtml = read('index.html');
const esHtml = read('es/index.html');
const $en = cheerio.load(enHtml);
const $es = cheerio.load(esHtml);
const esData = JSON.parse($es('#app-data').text());
const pageMap = Object.assign({}, ...Object.values(es.page));

// The hand-written English on index.html: text between tags and the labels and
// meta text people read or hear (generated blocks and scripts excluded).
function englishStrings(html) {
  const src = html
    .replace(/<!-- BEGIN GENERATED:([\w-]+) -->[\s\S]*?<!-- END GENERATED:\1 -->/g, '')
    .replace(/<script(?![^>]*ld\+json)[\s\S]*?<\/script>/g, '')
    .replace(/<style[\s\S]*?<\/style>/g, '');
  const out = new Set();
  const body = src.replace(/<script[^>]*ld\+json[\s\S]*?<\/script>/g, '');
  for (const m of body.matchAll(/>([^<>]*)</g)) out.add(m[1].trim());
  for (const m of src.matchAll(/\s(?:aria-label|title|alt|placeholder)="([^"]*)"/g)) out.add(m[1]);
  for (const m of src.matchAll(/<meta (?:name|property)="(?:description|og:title|og:description|twitter:title|twitter:description)" content="([^"]*)"/g)) out.add(m[1]);
  for (const m of src.matchAll(/"description": "([^"]*)"/g)) out.add(m[1]);
  return [...out].filter((s) => /[A-Za-z]/.test(s));
}

describe('Spanish homepage', () => {
  describe('every English string has Spanish', () => {
    const strings = englishStrings(enHtml);

    test('the extractor finds the page text', () => {
      expect(strings).toContain('Find the door your community needs.');
      expect(strings).toContain('Please read before use');
      expect(strings.length).toBeGreaterThan(40);
    });

    test('each string on index.html is in i18n/es.json page (or keep)', () => {
      const missing = strings.filter((s) => !(s in pageMap) && !es.keep.includes(s));
      expect(missing).toEqual([]);
    });

    test('es/index.html shows the Spanish, not the English', () => {
      const leftover = englishStrings(esHtml)
        .filter((s) => s in pageMap && pageMap[s] !== s);
      expect(leftover).toEqual([]);
    });

    test('ui, labels and narration have exactly the English keys', () => {
      expect(Object.keys(es.ui).sort()).toEqual(Object.keys(en.ui).sort());
      expect(Object.keys(es.narration).sort()).toEqual(Object.keys(en.narration).sort());
      expect(Object.keys(es.labels).sort()).toEqual(Object.keys(en.labels).sort());
      expect(Object.keys(es.labels.status).sort()).toEqual(Object.keys(en.labels.status).sort());
      expect(Object.keys(es.labels.scope).sort()).toEqual(Object.keys(en.labels.scope).sort());
      Object.entries(es.ui).forEach(([k, v]) => {
        const holes = (s) => (s.match(/\{\w+\}/g) || []).sort();
        expect(`${k}: ${holes(v)}`).toBe(`${k}: ${holes(en.ui[k])}`);
      });
    });

    test('is marked as a draft for a fluent reviewer', () => {
      expect(es.review).toMatch(/fluent/);
      expect(journeyEs._readme.join(' ')).toMatch(/fluent/);
    });
  });

  describe('projects', () => {
    test.each(listed.map((r) => r.name))('%s has a Spanish description, call to action and audience', (name) => {
      const c = es.projects[name];
      expect(c).toBeDefined();
      expect(c.description.length).toBeGreaterThan(20);
      expect(c.cta.length).toBeGreaterThan(3);
      expect(c.audience.length).toBe(listed.find((r) => r.name === name).audience.length);
    });

    test.each(listed.map((r) => r.name))('%s has a Spanish adopter and first pilot', (name) => {
      expect(journeyEs.adoption[name].adopter).toBeTruthy();
      expect(journeyEs.adoption[name].pilot).toBeTruthy();
    });

    test('no Spanish copy for projects that are not listed', () => {
      const names = new Set(listed.map((r) => r.name));
      Object.keys(es.projects).forEach((n) => expect(names.has(n)).toBe(true));
      Object.keys(journeyEs.adoption).forEach((n) => expect(names.has(n)).toBe(true));
    });

    test('project names stay as proper nouns; one Spanish door per project', () => {
      const doors = $es('a.door');
      expect(doors.length).toBe(listed.length);
      doors.each((_, d) => {
        const r = listed.find((x) => x.name === $es(d).attr('data-id'));
        expect($es(d).find('.door-name').text()).toBe(r.title || r.name);
      });
      esData.projects.forEach((p) => expect(p.description).toBe(es.projects[p.id].description));
    });
  });

  describe('journey (same structure as journey.json)', () => {
    test('same ids, counts and order', () => {
      expect(journeyEs.beacon.map((b) => b.letter)).toEqual(journey.beacon.map((b) => b.letter));
      expect(journeyEs.virtues).toHaveLength(journey.virtues.length);
      expect(journeyEs.gates).toHaveLength(journey.gates.length);
      ['roles', 'needs', 'places'].forEach((k) => {
        expect(journeyEs.finder[k].map((x) => x.id)).toEqual(journey.finder[k].map((x) => x.id));
      });
    });

    test('structure comes from journey.json: finder doors, crisis flags and lenses', () => {
      ['roles', 'needs', 'places'].forEach((k) => journeyEs.finder[k].forEach((x) => {
        expect(Object.keys(x).sort()).toEqual(['id', 'label']);
      }));
      expect(esData.journey.finder.needs).toEqual(journey.finder.needs.map((n) => ({ ...n, label: journeyEs.finder.needs.find((x) => x.id === n.id).label })));
      expect(esData.journey.finder.roles.map((r) => r.lens)).toEqual(journey.finder.roles.map((r) => r.lens));
    });

    test('every virtue question is a Spanish question', () => {
      journeyEs.virtues.forEach((v) => expect(v.question).toMatch(/^¿.*\?$/));
    });
  });

  describe('narration', () => {
    const clips = JSON.parse(execFileSync(path.join(ROOT, '.github/scripts/narration-clips.sh'), { encoding: 'utf-8' }));
    const esClips = clips.filter((c) => c.lang === 'es');

    test('a Spanish clip, suffixed -es, for every English clip', () => {
      const enIds = clips.filter((c) => c.lang === 'en').map((c) => c.id);
      expect(esClips.map((c) => c.id)).toEqual(enIds.map((id) => `${id}-es`));
    });

    test('Spanish transcripts match exactly what the narration generator speaks', () => {
      const expected = Object.fromEntries(esClips.map((c) => [c.id.replace(/-es$/, ''), c.text]));
      expect(esData.clips).toEqual(expected);
    });

    test('Spanish clips are spoken from Spanish words', () => {
      expect(esData.clips.welcome).toBe(`${journeyEs.catalyst.welcome} ${journeyEs.catalyst.blend}`);
      expect(esData.clips.finder).toBe(journeyEs.finder.intro);
      expect(esData.clips['access-to-food']).toContain(es.projects['access-to-food'].description);
      expect(esData.clips['access-to-food']).toContain(journeyEs.adoption['access-to-food'].pilot);
    });

    test('the page intro matches the narrated intro', () => {
      expect($es('#finder .section-lead').text().trim()).toBe(journeyEs.finder.intro);
    });

    test('play buttons start hidden and look up the -es clip, so the page works before audio exists', () => {
      $es('[data-clip]').each((_, b) => expect($es(b).attr('hidden')).toBeDefined());
      const app = read('app.js');
      expect(app).toMatch(/CLIPS\[b\.getAttribute\('data-clip'\) \+ SUFFIX\]/);
      expect(app).toMatch(/CLIPS\[p\.id \+ SUFFIX\]/);
      expect(app).toMatch(/fetch\(ROOT \+ 'audio\/manifest\.json'/);
      expect(esData.lang).toBe('es');
      expect(esData.root).toBe('../');
    });

    test('one voice and a multilingual model for both languages', () => {
      const narration = json('.github/config/narration.json');
      expect(narration.model_id).toMatch(/multilingual/);
      expect(read('.github/scripts/generate-narration.sh')).toMatch(/is not multilingual/);
    });
  });

  describe('crisis lines and disclaimer, in Spanish', () => {
    const notice = $es('#disclaimer').text();

    test('the notice says educational only and no professional advice', () => {
      expect(notice).toMatch(/solo información educativa/);
      expect(notice).toMatch(/No son asesoramiento legal, médico/);
      expect(notice).toMatch(/sin garantía/);
      expect(notice).toMatch(/No incluya nombres, números de caso/);
    });

    test.each([
      ['911', /Llame al 911/],
      ['988, press 2 for Spanish', /988 y marque 2 para español/],
      ['988, text AYUDA', /envíe AYUDA por mensaje de texto al 988/],
      ['National Domestic Violence Hotline', /1-800-799-7233/],
    ])('the notice gives %s', (_, re) => expect(notice).toMatch(re));

    test('the safety result in Find my door shows the same lines', () => {
      const note = esData.journey.finder.crisis_note;
      expect(note).toMatch(/911/);
      expect(note).toMatch(/988 y marque 2 para español/);
      expect(note).toMatch(/AYUDA/);
      expect(note).toMatch(/1-800-799-7233/);
      expect(esData.journey.finder.needs.find((n) => n.crisis)).toBeDefined();
    });

    test('every project sheet repeats the short disclaimer', () => {
      expect($es('.sheet-fine').text()).toMatch(/no es asesoramiento legal, médico ni de seguridad/);
      expect($es('.sheet-fine').text()).toMatch(/911/);
    });
  });

  describe('language switch, lang and hreflang', () => {
    test.each([['index.html', $en, 'en'], ['es/index.html', $es, 'es']])('%s declares its language', (_, $, lang) => {
      expect($('html').attr('lang')).toBe(lang);
    });

    test.each([['index.html', $en], ['es/index.html', $es]])('%s lists both languages and x-default as alternates', (_, $) => {
      const alt = Object.fromEntries($('link[rel="alternate"][hreflang]').map((_, l) => [[$(l).attr('hreflang'), $(l).attr('href')]]).get());
      expect(alt).toEqual({ en: en.url, es: es.url, 'x-default': en.url });
    });

    test.each([['index.html', $en, 'en'], ['es/index.html', $es, 'es']])('%s has an EN | ES switch marking the current language', (page, $, cur) => {
      const links = $('nav.lang-switch a');
      expect($('nav.lang-switch').attr('aria-label')).toBeTruthy();
      expect(links.map((_, a) => $(a).text()).get()).toEqual(['EN', 'ES']);
      links.each((_, a) => {
        const lang = $(a).attr('lang');
        expect($(a).attr('hreflang')).toBe(lang);
        // label in name: the accessible name starts with the visible code
        expect($(a).attr('aria-label').startsWith($(a).text())).toBe(true);
        expect($(a).attr('aria-current')).toBe(lang === cur ? 'page' : undefined);
        const target = path.join(ROOT, path.dirname(page), $(a).attr('href'));
        expect(fs.existsSync(target)).toBe(true);
        expect(path.relative(ROOT, target)).toBe(lang === 'en' ? 'index.html' : 'es/index.html');
      });
    });

    test('canonical and og:url point at the Spanish page', () => {
      expect($es('link[rel="canonical"]').attr('href')).toBe(es.url);
      expect($es('meta[property="og:url"]').attr('content')).toBe(es.url);
    });

    test('the switch keeps 44px touch targets', () => {
      const css = read('app.css');
      const rule = css.match(/\.lang-switch a \{[^}]*\}/)[0];
      expect(Number(rule.match(/min-height:\s*(\d+)px/)[1])).toBeGreaterThanOrEqual(44);
      expect(Number(rule.match(/min-width:\s*(\d+)px/)[1])).toBeGreaterThanOrEqual(44);
    });
  });

  describe('the same app, one folder down', () => {
    test('same structure as the English page (ids app.js needs)', () => {
      const ids = (h) => [...h.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
      expect(ids(esHtml)).toEqual(ids(enHtml));
    });

    test('every relative link and asset resolves from es/', () => {
      $es('[href], [src]').each((_, el) => {
        const u = $es(el).attr('href') || $es(el).attr('src');
        if (/^(https?:|mailto:|#|data:)/.test(u)) return;
        const file = u.split('#')[0];
        expect(`${u} ${fs.existsSync(path.join(ROOT, 'es', file)) ? 'ok' : 'missing'}`).toBe(`${u} ok`);
      });
    });

    test('loads the shared stylesheet and script (no copy of either)', () => {
      expect($es('link[rel="stylesheet"][href="../app.css"]').length).toBe(1);
      expect($es('script[src="../app.js"]').length).toBe(1);
      expect(fs.existsSync(path.join(ROOT, 'es/app.js'))).toBe(false);
    });

    test('one h1, a skip link and the labelled dialog', () => {
      expect($es('h1').length).toBe(1);
      expect($es('a.skip-link').attr('href')).toBe('#main');
      expect($es('dialog#sheet').attr('aria-labelledby')).toBe('sheet-title');
    });

    test('links to English-only pages say so', () => {
      expect($es('a[href="../about.html"]').first().text()).toMatch(/\(en inglés\)/);
      expect(es.ui.links_note).toMatch(/en inglés/);
    });
  });
});
