/**
 * Phone check: guards for the fixes from the 320/375px audit (axe-core,
 * tap targets, keyboard, headings, contrast) of every hub page.
 *
 * The audit itself runs in a real browser; these tests pin what it found in a
 * form CI can check without one: the CSS rules and markup each fix depends on.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const { JSDOM } = require('jsdom');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const PILLAR_PAGES = ['health', 'education', 'safety', 'housing', 'services', 'jobs', 'business', 'seniors', 'experts', 'peace'].map((p) => `${p}.html`);
const HUB_PAGES = ['about.html', ...PILLAR_PAGES, '404.html'];
const ALL_PAGES = ['index.html', ...HUB_PAGES];

// Innermost "selector { body }" pairs, so rules inside @media blocks are included.
function rules(css) {
  const out = [];
  const re = /([^{}]+)\{([^{}]*)\}/g;
  let m;
  const src = css.replace(/\/\*[\s\S]*?\*\//g, '');
  while ((m = re.exec(src))) {
    out.push({ selectors: m[1].split(',').map((s) => s.trim().replace(/\s+/g, ' ')), body: m[2] });
  }
  return out;
}
const STYLES = rules(read('styles.css'));
const APP = rules(read('app.css'));
const bodyOf = (list, selector) => list.filter((r) => r.selectors.includes(selector)).map((r) => r.body).join(';');
const px = (body, prop) => {
  const m = body.match(new RegExp(`(?:^|;|\\s)${prop}:\\s*(\\d+)px`));
  return m ? Number(m[1]) : 0;
};

// WCAG relative luminance and contrast ratio
const lum = (hex) => {
  const v = hex.replace('#', '').match(/../g).map((h) => parseInt(h, 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
};
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
function tokens(selector) {
  const body = bodyOf(STYLES, selector);
  const t = {};
  body.replace(/(--[\w-]+):\s*(#[0-9A-Fa-f]{6})/g, (_, k, v) => { t[k] = v; });
  return t;
}
const LIGHT = tokens(':root');
const DARK = { ...LIGHT, ...tokens('[data-theme="dark"]') };

describe('Phone check', () => {
  describe('headings: one h1 and no skipped levels', () => {
    test.each(ALL_PAGES)('%s', (page) => {
      const $ = cheerio.load(read(page));
      expect($('h1').length).toBe(1);
      let prev = 0;
      const skips = [];
      $('h1, h2, h3, h4, h5, h6').each((_, h) => {
        if ($(h).closest('dialog').length) return;          // the sheet has its own outline
        const level = Number(h.tagName[1]);
        if (prev && level > prev + 1) skips.push(`h${prev} -> h${level} "${$(h).text().trim()}"`);
        prev = level;
      });
      expect(skips).toEqual([]);
    });
  });

  describe('phone menu button exposes its state', () => {
    test.each(HUB_PAGES)('%s', (page) => {
      const html = read(page);
      const $ = cheerio.load(html);
      const btn = $('button.hamburger');
      expect(btn.length).toBe(1);
      expect(btn.attr('aria-expanded')).toBe('false');
      const nav = $(`#${btn.attr('aria-controls')}`);
      expect(nav.is('nav.topbar-links')).toBe(true);

      // Run the page's own handlers in a DOM built from its header.
      const { window } = new JSDOM(`<body>${$('header').html()}</body>`, { runScripts: 'outside-only' });
      const b = window.document.querySelector('.hamburger');
      const click = () => window.eval(`(function () { ${b.getAttribute('onclick')} }).call(document.querySelector('.hamburger'))`);
      click();
      expect(b.getAttribute('aria-expanded')).toBe('true');
      expect(window.document.querySelector('.topbar-links').classList.contains('open')).toBe(true);
      click();
      expect(b.getAttribute('aria-expanded')).toBe('false');

      const close = html.match(/function closeMobileNav\(\)\s*\{[\s\S]*?\}/);
      if (close) {                                         // pages whose nav links close the menu
        click();
        window.eval(`${close[0]}; closeMobileNav();`);
        expect(b.getAttribute('aria-expanded')).toBe('false');
        expect(b.classList.contains('open')).toBe(false);
      }
    });
  });

  describe('back-to-top is out of the tab order until it is shown', () => {
    test('hub pages (styles.css)', () => {
      expect(bodyOf(STYLES, '.back-to-top')).toMatch(/visibility:\s*hidden/);
      expect(bodyOf(STYLES, '.back-to-top.visible')).toMatch(/visibility:\s*visible/);
    });
    test('homepage app (app.css)', () => {
      expect(bodyOf(APP, '.back-to-top')).toMatch(/visibility:\s*hidden/);
      expect(bodyOf(APP, '.back-to-top.show')).toMatch(/visibility:\s*visible/);
    });
  });

  describe('contrast', () => {
    test('dark buttons use the page background for text, never a fixed white (1.2:1 in dark mode)', () => {
      const dark = STYLES.filter((r) => /background:\s*var\(--color-text\)/.test(r.body) && /(?:^|;)\s*color:/.test(r.body));
      expect(dark.length).toBeGreaterThan(0);
      dark.forEach((r) => {
        expect(`${r.selectors.join(', ')} { ${r.body.match(/(?:^|;)\s*color:[^;]*/)?.[0].trim()} }`)
          .toMatch(/color:\s*var\(--color-bg\)/);
      });
    });

    test('dark-button hover shades keep 4.5:1 text in both themes', () => {
      STYLES.filter((r) => /:hover/.test(r.selectors.join()) && /background:\s*#333/.test(r.body))
        .forEach((r) => expect(r.selectors.join()).toBe('no hard-coded #333 hover'));
      expect(ratio(LIGHT['--color-bg'], LIGHT['--color-btn-hover'])).toBeGreaterThanOrEqual(4.5);
      expect(ratio(DARK['--color-bg'], DARK['--color-btn-hover'])).toBeGreaterThanOrEqual(4.5);
    });

    test('the health link color is a text-safe shade in both themes', () => {
      expect(bodyOf(STYLES, '[data-pillar="health"] .pillar-link')).toContain('var(--color-accent-health-text)');
      expect(ratio(LIGHT['--color-accent-health-text'], LIGHT['--color-card-bg'])).toBeGreaterThanOrEqual(4.5);
      expect(ratio(DARK['--color-accent-health-text'], DARK['--color-card-bg'])).toBeGreaterThanOrEqual(4.5);
    });

    test('the current pillar card is muted with color, not opacity (2.9:1)', () => {
      const body = bodyOf(STYLES, '.cross-link-card.current');
      expect(body).not.toMatch(/opacity/);
      expect(body).toContain('var(--color-muted)');
      expect(ratio(LIGHT['--color-muted'], LIGHT['--color-card-bg'])).toBeGreaterThanOrEqual(4.5);
      expect(ratio(DARK['--color-muted'], DARK['--color-card-bg'])).toBeGreaterThanOrEqual(4.5);
    });

    test.each(PILLAR_PAGES)('%s marks its own card aria-current="page"', (page) => {
      const $ = cheerio.load(read(page));
      expect($('.cross-link-card.current').attr('aria-current')).toBe('page');
    });
  });

  describe('touch targets are at least 44px', () => {
    test.each([
      ['.skip-link', 'min-height'],
      ['.topbar-logo a', 'min-height'],
      ['.hamburger', 'min-height'], ['.hamburger', 'min-width'],
      ['.theme-toggle', 'min-height'], ['.theme-toggle', 'min-width'],
      ['.pillar-card .pillar-link', 'min-height'],
      ['.repo-list li a', 'min-height'],
      ['.copy-btn', 'min-height'], ['.copy-btn', 'min-width'],
      ['.email-form input', 'min-height'],
      ['.email-form button', 'min-height'],
      ['.pillar-hero .breadcrumb a', 'min-height'], ['.pillar-hero .breadcrumb a', 'min-width'],
      ['.project-card h3 a', 'min-height'],
      ['.project-card .btn-github', 'min-height'],
      ['.footer-col ul li a', 'min-height'],
      ['.footer-brand .footer-social a', 'min-height'],
    ])('%s %s', (selector, prop) => {
      expect(px(bodyOf(STYLES, selector), prop)).toBeGreaterThanOrEqual(44);
    });
  });

  describe('no horizontal scroll at 320/375px, even at 200% text', () => {
    test('the homepage beam is clipped to the welcome (it widened the page by 44px)', () => {
      expect(bodyOf(APP, '.lamp')).toMatch(/overflow-x:\s*(clip|hidden)/);
    });

    test.each([['styles.css', STYLES], ['app.css', APP]])('%s wraps a long word instead of widening the page', (_, list) => {
      expect(bodyOf(list, 'body')).toMatch(/overflow-wrap:\s*(break-word|anywhere)/);
    });

    test.each(['.capabilities-grid', '.audience-grid', '.project-card', '.footer-grid', '.contributor-inner'])(
      '%s lets its track shrink below its content on phones', (selector) => {
        const phone = STYLES.filter((r) => r.selectors.includes(selector) && /grid-template-columns:\s*(repeat\(\d+,\s*)?minmax\(0,/.test(r.body));
        expect(phone.length).toBeGreaterThan(0);
      });

    test('labels that never wrapped now can', () => {
      const last = (selector, prop) => {
        const hits = STYLES.filter((r) => r.selectors.includes(selector)).map((r) => r.body.match(new RegExp(`${prop}:\\s*([^;]+)`))).filter(Boolean);
        return hits.length ? hits[hits.length - 1][1].trim() : '';
      };
      expect(last('.social-proof-logos span', 'white-space')).toBe('normal');
      expect(last('.email-form button', 'white-space')).toBe('normal');
      expect(last('.tag', 'white-space')).toBe('normal');
      expect(bodyOf(STYLES, '.footer-brand .footer-social')).toMatch(/flex-wrap:\s*wrap/);
    });
  });

  describe('keyboard and names', () => {
    test('the email field shows a focus ring (its outline: none would otherwise hide it)', () => {
      expect(bodyOf(STYLES, '.email-form input')).toMatch(/outline:\s*none/);
      expect(bodyOf(STYLES, '.email-form input:focus-visible')).toMatch(/outline:\s*2px solid/);
    });

    test('the scrolling clone command can be reached by keyboard', () => {
      const $ = cheerio.load(read('about.html'));
      expect($('.copy-block code').attr('tabindex')).toBe('0');
    });

    test('the homepage name link is named by its visible text (label in name)', () => {
      const $ = cheerio.load(read('index.html'));
      const a = $('a.bar-name');
      const visible = a.text().replace(/\s+/g, ' ').trim();
      const label = a.attr('aria-label');
      if (label) expect(label.toLowerCase()).toContain(visible.toLowerCase());
      expect(visible).toContain('Doug Devitre');
    });
  });
});
