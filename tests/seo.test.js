'use strict';

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');

const SEO_PAGES = [
  {
    file: 'index.html',
    expectedUrl: 'https://dougdevitre.org/',
    expectedTitle: 'Access To',
    hasJsonLd: true,
  },
  {
    file: 'health.html',
    expectedUrl: 'https://dougdevitre.org/health.html',
    expectedTitle: 'Access to Health',
    hasJsonLd: true,
  },
  {
    file: 'education.html',
    expectedUrl: 'https://dougdevitre.org/education.html',
    expectedTitle: 'Access to Education',
    hasJsonLd: true,
  },
  {
    file: 'safety.html',
    expectedUrl: 'https://dougdevitre.org/safety.html',
    expectedTitle: 'Access to Safety',
    hasJsonLd: true,
  },
  {
    file: 'housing.html',
    expectedUrl: 'https://dougdevitre.org/housing.html',
    expectedTitle: 'Access to Housing',
    hasJsonLd: true,
  },
  {
    file: 'services.html',
    expectedUrl: 'https://dougdevitre.org/services.html',
    expectedTitle: 'Access to Services',
    hasJsonLd: true,
  },
  {
    file: 'jobs.html',
    expectedUrl: 'https://dougdevitre.org/jobs.html',
    expectedTitle: 'Access to Jobs',
    hasJsonLd: true,
  },
  {
    file: 'business.html',
    expectedUrl: 'https://dougdevitre.org/business.html',
    expectedTitle: 'Access to Business',
    hasJsonLd: true,
  },
];

function load(file) {
  const html = fs.readFileSync(path.join(ROOT, file), 'utf-8');
  return cheerio.load(html, { xmlMode: false });
}

describe('SEO meta tags', () => {
  SEO_PAGES.forEach(({ file, expectedUrl, expectedTitle, hasJsonLd }) => {
    describe(file, () => {
      let $;
      beforeAll(() => { $ = load(file); });

      test('has og:title', () => {
        const ogTitle = $('meta[property="og:title"]').attr('content');
        expect(ogTitle).toBeTruthy();
        expect(ogTitle.trim().length).toBeGreaterThan(0);
      });

      test('og:title contains expected title', () => {
        const ogTitle = $('meta[property="og:title"]').attr('content');
        expect(ogTitle).toContain(expectedTitle);
      });

      test('has og:description', () => {
        const ogDesc = $('meta[property="og:description"]').attr('content');
        expect(ogDesc).toBeTruthy();
        expect(ogDesc.trim().length).toBeGreaterThan(0);
      });

      test('has og:type', () => {
        const ogType = $('meta[property="og:type"]').attr('content');
        expect(ogType).toBeTruthy();
        expect(ogType).toBe('website');
      });

      test('has og:url matching expected URL', () => {
        const ogUrl = $('meta[property="og:url"]').attr('content');
        expect(ogUrl).toBe(expectedUrl);
      });

      test('has og:image pointing to og-image.png', () => {
        const ogImage = $('meta[property="og:image"]').attr('content');
        expect(ogImage).toBeTruthy();
        expect(ogImage).toContain('og-image.png');
      });

      test('has twitter:card', () => {
        const card = $('meta[name="twitter:card"]').attr('content');
        expect(card).toBeTruthy();
      });

      test('has twitter:title', () => {
        const twitterTitle = $('meta[name="twitter:title"]').attr('content');
        expect(twitterTitle).toBeTruthy();
        expect(twitterTitle.trim().length).toBeGreaterThan(0);
      });

      test('has twitter:description', () => {
        const twitterDesc = $('meta[name="twitter:description"]').attr('content');
        expect(twitterDesc).toBeTruthy();
        expect(twitterDesc.trim().length).toBeGreaterThan(0);
      });

      test('has twitter:image', () => {
        const twitterImage = $('meta[name="twitter:image"]').attr('content');
        expect(twitterImage).toBeTruthy();
        expect(twitterImage).toContain('og-image.png');
      });

      test('has canonical link matching expected URL', () => {
        const canonical = $('link[rel="canonical"]').attr('href');
        expect(canonical).toBe(expectedUrl);
      });

      test('canonical and og:url match', () => {
        const canonical = $('link[rel="canonical"]').attr('href');
        const ogUrl = $('meta[property="og:url"]').attr('content');
        expect(canonical).toBe(ogUrl);
      });

      if (hasJsonLd) {
        test('has valid JSON-LD structured data', () => {
          const jsonLd = $('script[type="application/ld+json"]').first().html();
          expect(jsonLd).toBeTruthy();
          let parsed;
          expect(() => { parsed = JSON.parse(jsonLd); }).not.toThrow();
          expect(parsed['@context']).toBe('https://schema.org');
          expect(parsed['@type']).toBeTruthy();
        });

        test('JSON-LD contains url matching the canonical', () => {
          const jsonLd = $('script[type="application/ld+json"]').first().html();
          const parsed = JSON.parse(jsonLd);
          const canonical = $('link[rel="canonical"]').attr('href');
          expect(parsed.url).toBe(canonical);
        });
      }
    });
  });

  describe('robots meta tag', () => {
    const indexablePages = ['index.html', 'health.html', 'education.html', 'safety.html', 'housing.html', 'services.html', 'jobs.html', 'business.html'];

    indexablePages.forEach((page) => {
      test(`${page} has robots "index, follow"`, () => {
        const $ = load(page);
        const robots = $('meta[name="robots"]').attr('content');
        expect(robots).toBe('index, follow');
      });
    });

    test('404.html has robots "noindex, nofollow"', () => {
      const $ = load('404.html');
      const robots = $('meta[name="robots"]').attr('content');
      expect(robots).toBe('noindex, nofollow');
    });
  });
});
