'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');

const HTML_PAGES = [
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

function load(file) {
  const html = fs.readFileSync(path.join(ROOT, file), 'utf-8');
  return cheerio.load(html, { xmlMode: false });
}

describe('HTML document structure', () => {
  HTML_PAGES.forEach((page) => {
    describe(page, () => {
      let $;
      beforeAll(() => { $ = load(page); });

      test('has DOCTYPE html declaration', () => {
        const raw = fs.readFileSync(path.join(ROOT, page), 'utf-8');
        expect(raw.toLowerCase().trimStart()).toMatch(/^<!doctype html>/);
      });

      test('html element has lang="en"', () => {
        expect($('html').attr('lang')).toBe('en');
      });

      test('has <meta charset="UTF-8">', () => {
        const charset = $('meta[charset]').attr('charset');
        expect(charset).toMatch(/^utf-8$/i);
      });

      test('has viewport meta tag', () => {
        const viewport = $('meta[name="viewport"]').attr('content');
        expect(viewport).toBeTruthy();
        expect(viewport).toContain('width=device-width');
      });

      test('has a non-empty <title>', () => {
        const title = $('title').text().trim();
        expect(title.length).toBeGreaterThan(0);
      });

      test('has <meta name="description"> with non-empty content', () => {
        // 404 is a minimal error page and intentionally omits the description meta
        if (page === '404.html') return;
        const desc = $('meta[name="description"]').attr('content');
        expect(desc).toBeTruthy();
        expect(desc.trim().length).toBeGreaterThan(0);
      });

      test('has <link rel="icon"> pointing to favicon.svg', () => {
        const icon = $('link[rel="icon"]').attr('href');
        expect(icon).toBe('favicon.svg');
      });

      test('has <link rel="stylesheet" href="styles.css">', () => {
        const stylesheet = $('link[rel="stylesheet"][href="styles.css"]');
        expect(stylesheet.length).toBe(1);
      });

      test('has a <header> element', () => {
        expect($('header').length).toBeGreaterThanOrEqual(1);
      });

      test('has a <footer> element', () => {
        expect($('footer').length).toBeGreaterThanOrEqual(1);
      });
    });
  });

  describe('main content pages (excluding 404)', () => {
    const mainPages = HTML_PAGES.filter((p) => p !== '404.html');

    mainPages.forEach((page) => {
      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('has <main id="main">', () => {
          expect($('main#main').length).toBe(1);
        });

        test('has skip-to-main-content link as first focusable element', () => {
          const skipLink = $('a.skip-link').first();
          expect(skipLink.length).toBe(1);
          expect(skipLink.attr('href')).toBe('#main');
        });

        test('has <link rel="manifest" href="manifest.json">', () => {
          const manifest = $('link[rel="manifest"]');
          expect(manifest.length).toBe(1);
          expect(manifest.attr('href')).toBe('manifest.json');
        });

        test('has <meta name="theme-color">', () => {
          const themeColor = $('meta[name="theme-color"]').attr('content');
          expect(themeColor).toBeTruthy();
        });

        test('has theme-initialization inline script in <head>', () => {
          const headScripts = $('head script:not([type="application/ld+json"])');
          let hasThemeInit = false;
          headScripts.each((_, el) => {
            const src = $(el).html() || '';
            if (src.includes('localStorage') && src.includes('data-theme')) {
              hasThemeInit = true;
            }
          });
          expect(hasThemeInit).toBe(true);
        });

        test('has back-to-top button with aria-label', () => {
          const btt = $('button#backToTop, button.back-to-top');
          expect(btt.length).toBeGreaterThanOrEqual(1);
          expect(btt.attr('aria-label')).toBeTruthy();
        });
      });
    });
  });

  describe('pillar pages (excluding index and 404)', () => {
    const pillarPages = ['health.html', 'education.html', 'safety.html', 'housing.html', 'services.html', 'jobs.html', 'business.html'];

    pillarPages.forEach((page) => {
      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('has a pillar hero section', () => {
          expect($('.pillar-hero').length).toBe(1);
        });

        test('has an <h1> in the pillar hero', () => {
          expect($('.pillar-hero h1').length).toBe(1);
        });

        test('has a breadcrumb with link back to index.html', () => {
          const breadcrumb = $('.breadcrumb');
          expect(breadcrumb.length).toBe(1);
          expect(breadcrumb.find('a[href="index.html"]').length).toBe(1);
        });

        test('has a project list section', () => {
          expect($('.project-list').length).toBe(1);
        });

        test('has at least one project card', () => {
          expect($('.project-card').length).toBeGreaterThanOrEqual(1);
        });

        test('has cross-links section with all 7 pillar links', () => {
          const crossLinks = $('.cross-links-grid');
          expect(crossLinks.length).toBe(1);
          expect(crossLinks.find('a').length).toBe(7);
        });

        test('has a donate section', () => {
          expect($('.donate-section').length).toBe(1);
        });

        test('has how-to-use section', () => {
          expect($('.how-to-use').length).toBe(1);
        });
      });
    });
  });
});
