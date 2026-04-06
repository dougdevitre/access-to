'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');

const PILLARS = ['justice', 'education', 'housing', 'services', 'peace', 'safety'];
const PILLAR_PAGES = PILLARS.map((p) => `${p}.html`);

function load(file) {
  const html = fs.readFileSync(path.join(ROOT, file), 'utf-8');
  return cheerio.load(html, { xmlMode: false });
}

describe('Navigation', () => {
  describe('header navigation on pillar pages', () => {
    PILLAR_PAGES.forEach((page) => {
      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('logo links back to index.html', () => {
          const logoLink = $('.topbar-logo a').first();
          expect(logoLink.attr('href')).toBe('index.html');
        });

        test('nav contains link to index.html#pillars', () => {
          const pillarsLink = $('nav.topbar-links a[href="index.html#pillars"]');
          expect(pillarsLink.length).toBe(1);
        });

        test('nav contains link to index.html#how-it-works', () => {
          const link = $('nav.topbar-links a[href="index.html#how-it-works"]');
          expect(link.length).toBe(1);
        });

        test('nav contains link to index.html#updates', () => {
          const link = $('nav.topbar-links a[href="index.html#updates"]');
          expect(link.length).toBe(1);
        });

        test('nav contains link to index.html#about', () => {
          const link = $('nav.topbar-links a[href="index.html#about"]');
          expect(link.length).toBe(1);
        });

        test('nav contains GitHub link opening in new tab', () => {
          const ghLink = $('nav.topbar-links a[href*="github.com"][target="_blank"]');
          expect(ghLink.length).toBe(1);
        });

        test('nav contains donate link', () => {
          const donateLink = $('nav.topbar-links a.nav-donate');
          expect(donateLink.length).toBe(1);
        });
      });
    });
  });

  describe('index.html navigation', () => {
    let $;
    beforeAll(() => { $ = load('index.html'); });

    test('logo links to # (top of page)', () => {
      const logoLink = $('.topbar-logo a').first();
      expect(logoLink.attr('href')).toBe('#');
    });

    test('nav has Pillars anchor link', () => {
      const link = $('nav.topbar-links a[href="#pillars"]');
      expect(link.length).toBe(1);
    });

    test('nav has How It Works anchor link', () => {
      const link = $('nav.topbar-links a[href="#how-it-works"]');
      expect(link.length).toBe(1);
    });

    test('nav has Updates anchor link', () => {
      const link = $('nav.topbar-links a[href="#updates"]');
      expect(link.length).toBe(1);
    });

    test('nav has About anchor link', () => {
      const link = $('nav.topbar-links a[href="#about"]');
      expect(link.length).toBe(1);
    });

    test('pillar cards link to correct pillar pages', () => {
      PILLARS.forEach((pillar) => {
        const link = $(`.pillar-card[data-pillar="${pillar}"] a.pillar-link`);
        expect(link.length).toBe(1);
        expect(link.attr('href')).toBe(`${pillar}.html`);
      });
    });
  });

  describe('cross-pillar navigation on pillar pages', () => {
    PILLAR_PAGES.forEach((page) => {
      const currentPillar = page.replace('.html', '');

      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('cross-links grid has 6 items (one per pillar)', () => {
          const grid = $('.cross-links-grid');
          expect(grid.find('a').length).toBe(6);
        });

        PILLARS.forEach((pillar) => {
          test(`has cross-link to ${pillar}.html`, () => {
            const link = $(`.cross-links-grid a[href="${pillar}.html"]`);
            expect(link.length).toBe(1);
          });
        });

        test(`current pillar link (${currentPillar}) has class "current"`, () => {
          const currentLink = $(`.cross-links-grid a[href="${currentPillar}.html"]`);
          expect(currentLink.hasClass('current')).toBe(true);
        });

        test('no other cross-link has class "current"', () => {
          const otherPillars = PILLARS.filter((p) => p !== currentPillar);
          otherPillars.forEach((pillar) => {
            const link = $(`.cross-links-grid a[href="${pillar}.html"]`);
            expect(link.hasClass('current')).toBe(false);
          });
        });
      });
    });
  });

  describe('footer navigation', () => {
    const allMainPages = ['index.html', ...PILLAR_PAGES];

    allMainPages.forEach((page) => {
      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('footer contains links to all 6 pillar pages', () => {
          PILLARS.forEach((pillar) => {
            const link = $(`footer a[href="${pillar}.html"]`);
            expect(link.length).toBeGreaterThanOrEqual(1);
          });
        });

        test('footer has GitHub link', () => {
          const ghLink = $('footer a[href*="github.com"]');
          expect(ghLink.length).toBeGreaterThanOrEqual(1);
        });

        test('footer has LinkedIn link', () => {
          const liLink = $('footer a[href*="linkedin.com"]');
          expect(liLink.length).toBeGreaterThanOrEqual(1);
        });

        test('footer has email link', () => {
          const emailLink = $('footer a[href^="mailto:"]');
          expect(emailLink.length).toBeGreaterThanOrEqual(1);
        });

        test('footer contains copyright notice', () => {
          const footerText = $('footer').text();
          expect(footerText).toContain('Doug Devitre');
          expect(footerText).toContain('MIT');
        });
      });
    });
  });

  describe('internal links reference pages that exist', () => {
    const existingFiles = new Set(
      fs.readdirSync(ROOT).filter((f) => f.endsWith('.html'))
    );

    const allMainPages = ['index.html', ...PILLAR_PAGES, '404.html'];

    allMainPages.forEach((page) => {
      test(`${page} — all internal .html links resolve to existing files`, () => {
        const $ = load(page);
        $('a[href]').each((_, el) => {
          const href = $(el).attr('href');
          // Only check relative .html links (no anchors, no external, no mailto)
          if (href && !href.startsWith('http') && !href.startsWith('#') && !href.startsWith('mailto:') && href.includes('.html')) {
            const filePart = href.split('#')[0];
            expect(existingFiles.has(filePart)).toBe(true);
          }
        });
      });
    });
  });
});
