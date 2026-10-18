'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');

const PILLARS = ['health', 'education', 'safety', 'housing', 'services', 'jobs', 'business'];
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

        test('nav contains link to about.html#pillars', () => {
          const pillarsLink = $('nav.topbar-links a[href="about.html#pillars"]');
          expect(pillarsLink.length).toBe(1);
        });

        test('nav contains link to about.html#how-it-works', () => {
          const link = $('nav.topbar-links a[href="about.html#how-it-works"]');
          expect(link.length).toBe(1);
        });

        test('nav contains link to about.html#updates', () => {
          const link = $('nav.topbar-links a[href="about.html#updates"]');
          expect(link.length).toBe(1);
        });

        test('nav contains link to about.html#about', () => {
          const link = $('nav.topbar-links a[href="about.html#about"]');
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

  describe('about.html navigation (the full hub page)', () => {
    let $;
    beforeAll(() => { $ = load('about.html'); });

    test('logo links home to the app (index.html)', () => {
      const logoLink = $('.topbar-logo a').first();
      expect(logoLink.attr('href')).toBe('index.html');
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

    describe('project cards (static, generated from repos.json by render-hub.sh)', () => {
      const registry = JSON.parse(
        fs.readFileSync(path.join(ROOT, '.github/config/repos.json'), 'utf-8')
      );
      const listed = registry.repos.filter((r) => r.role !== 'hub' && r.listed !== false);

      test('pillars section exists', () => {
        expect($('#pillars').length).toBe(1);
      });

      test('cards are in the HTML itself, not fetched at runtime', () => {
        const scripts = $('script').text();
        expect(scripts).not.toContain('renderPillars');
        expect(scripts).not.toContain("fetch('.github/config/repos.json')");
        expect($('#pillars .pillar-card').length).toBeGreaterThan(0);
      });

      test('one card per listed project in repos.json', () => {
        expect($('#pillars .pillar-card').length).toBe(listed.length);
      });

      test('every listed project has a card with its pillar and title', () => {
        const cards = $('#pillars .pillar-card').toArray().map((el) => ({
          pillar: $(el).attr('data-pillar'),
          title: $(el).find('h2').text(),
        }));
        listed.forEach((repo) => {
          const match = cards.find((c) => c.pillar === repo.pillar && c.title === (repo.title || c.title));
          expect(match).toBeDefined();
        });
      });

      test('public repos link to GitHub; private repos do not', () => {
        listed.forEach((repo) => {
          const url = `https://github.com/${registry.owner}/${repo.name}`;
          const linked = $(`#pillars a[href="${url}"]`).length > 0;
          expect(linked).toBe((repo.visibility || 'public') === 'public');
        });
      });

      test('external links open safely (rel=noopener)', () => {
        $('#pillars a[target="_blank"]').each((_, a) => {
          expect($(a).attr('rel')).toContain('noopener');
        });
      });

      test('stat counters show real numbers without JavaScript', () => {
        $('#stats .stat-number').each((_, el) => {
          expect($(el).text().trim()).not.toBe('0');
        });
        expect($('#stats .stat-number').eq(1).text().trim()).toBe(String(listed.length));
      });
    });
  });

  describe('cross-pillar navigation on pillar pages', () => {
    PILLAR_PAGES.forEach((page) => {
      const currentPillar = page.replace('.html', '');

      describe(page, () => {
        let $;
        beforeAll(() => { $ = load(page); });

        test('cross-links grid has 7 items (one per pillar)', () => {
          const grid = $('.cross-links-grid');
          expect(grid.find('a').length).toBe(7);
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
    const allMainPages = ['about.html', ...PILLAR_PAGES];

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

    const allMainPages = ['index.html', 'about.html', ...PILLAR_PAGES, '404.html'];

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
