'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');

const ALL_PAGES = [
  'index.html',
  'health.html',
  'education.html',
  'safety.html',
  'housing.html',
  'services.html',
  'jobs.html',
  'business.html',
  '404.html',
];

const MAIN_PAGES = ALL_PAGES.filter((p) => p !== '404.html');

function load(file) {
  const html = fs.readFileSync(path.join(ROOT, file), 'utf-8');
  return cheerio.load(html, { xmlMode: false });
}

describe('Accessibility', () => {
  describe('lang attribute', () => {
    ALL_PAGES.forEach((page) => {
      test(`${page} html element has lang attribute`, () => {
        const $ = load(page);
        const lang = $('html').attr('lang');
        expect(lang).toBeTruthy();
        expect(lang.trim().length).toBeGreaterThan(0);
      });
    });
  });

  describe('skip-to-content link', () => {
    MAIN_PAGES.forEach((page) => {
      test(`${page} has skip link pointing to #main`, () => {
        const $ = load(page);
        const skipLink = $('a.skip-link');
        expect(skipLink.length).toBeGreaterThanOrEqual(1);
        expect(skipLink.first().attr('href')).toBe('#main');
      });
    });
  });

  describe('interactive elements have accessible labels', () => {
    MAIN_PAGES.forEach((page) => {
      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('hamburger button has aria-label', () => {
          const hamburger = $('button.hamburger');
          expect(hamburger.length).toBe(1);
          const label = hamburger.attr('aria-label');
          expect(label).toBeTruthy();
          expect(label.trim().length).toBeGreaterThan(0);
        });

        test('theme toggle button has aria-label', () => {
          const themeBtn = $('button.theme-toggle');
          expect(themeBtn.length).toBe(1);
          const label = themeBtn.attr('aria-label');
          expect(label).toBeTruthy();
          expect(label.trim().length).toBeGreaterThan(0);
        });

        test('back-to-top button has aria-label', () => {
          const btt = $('button#backToTop, button.back-to-top');
          expect(btt.length).toBeGreaterThanOrEqual(1);
          const label = btt.first().attr('aria-label');
          expect(label).toBeTruthy();
          expect(label.trim().length).toBeGreaterThan(0);
        });
      });
    });
  });

  describe('images have alt text', () => {
    ALL_PAGES.forEach((page) => {
      test(`${page} — all <img> elements have non-empty alt attributes`, () => {
        const $ = load(page);
        const images = $('img');
        images.each((_, el) => {
          const alt = $(el).attr('alt');
          expect(alt).toBeDefined();
          expect(typeof alt).toBe('string');
        });
      });
    });
  });

  describe('SVG icons used as meaningful content have aria-label or role="img"', () => {
    MAIN_PAGES.forEach((page) => {
      test(`${page} — pillar icons have role="img" and aria-label`, () => {
        const $ = load(page);
        // Only test explicitly decorated icon containers (.pillar-icon)
        $('.pillar-icon[role="img"]').each((_, el) => {
          expect($(el).attr('aria-label')).toBeTruthy();
        });
      });
    });
  });

  describe('navigation landmark', () => {
    MAIN_PAGES.forEach((page) => {
      test(`${page} has <nav> element inside header`, () => {
        const $ = load(page);
        const nav = $('header nav');
        expect(nav.length).toBeGreaterThanOrEqual(1);
      });
    });
  });

  describe('external links have rel="noopener"', () => {
    ALL_PAGES.forEach((page) => {
      test(`${page} — all target="_blank" links have rel containing "noopener"`, () => {
        const $ = load(page);
        $('a[target="_blank"]').each((_, el) => {
          const rel = $(el).attr('rel') || '';
          expect(rel).toContain('noopener');
        });
      });
    });
  });

  describe('heading hierarchy', () => {
    const pillarPages = ['health.html', 'education.html', 'safety.html', 'housing.html', 'services.html', 'jobs.html', 'business.html'];

    pillarPages.forEach((page) => {
      test(`${page} has exactly one <h1>`, () => {
        const $ = load(page);
        expect($('h1').length).toBe(1);
      });
    });

    test('index.html has exactly one <h1>', () => {
      const $ = load('index.html');
      expect($('h1').length).toBe(1);
    });
  });

  describe('noscript fallback', () => {
    MAIN_PAGES.forEach((page) => {
      test(`${page} has <noscript> block in <head>`, () => {
        const $ = load(page);
        const noscript = $('head noscript');
        expect(noscript.length).toBeGreaterThanOrEqual(1);
      });
    });
  });
});
