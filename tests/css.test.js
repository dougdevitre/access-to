'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const CSS_PATH = path.join(ROOT, 'styles.css');

describe('CSS (styles.css)', () => {
  let css;

  beforeAll(() => {
    css = fs.readFileSync(CSS_PATH, 'utf-8');
  });

  test('file exists and is non-empty', () => {
    expect(css.trim().length).toBeGreaterThan(0);
  });

  describe(':root custom properties', () => {
    const requiredVars = [
      '--color-bg',
      '--color-text',
      '--color-muted',
      '--color-border',
      '--color-card-bg',
      '--color-accent-health',
      '--color-accent-education',
      '--color-accent-safety',
      '--color-accent-housing',
      '--color-accent-services',
      '--color-accent-jobs',
      '--color-accent-business',
      '--color-accent-primary',
      '--font-display',
      '--font-body',
      '--max-width',
      '--radius',
    ];

    requiredVars.forEach((varName) => {
      test(`defines ${varName}`, () => {
        expect(css).toContain(varName);
      });
    });
  });

  describe('dark mode overrides', () => {
    test('has [data-theme="dark"] block', () => {
      expect(css).toContain('[data-theme="dark"]');
    });

    const darkVars = [
      '--color-bg',
      '--color-text',
      '--color-muted',
      '--color-border',
      '--color-card-bg',
    ];

    darkVars.forEach((varName) => {
      test(`dark mode overrides ${varName}`, () => {
        // Find the dark-mode block and check the variable is present inside it
        const darkBlock = css.match(/\[data-theme="dark"\]\s*\{[^}]+\}/);
        expect(darkBlock).not.toBeNull();
        expect(darkBlock[0]).toContain(varName);
      });
    });
  });

  describe('core component classes', () => {
    const requiredClasses = [
      '.skip-link',
      '.topbar',
      '.topbar-logo',
      '.topbar-links',
      '.hamburger',
      '.theme-toggle',
      '.hero',
      '.pillar-card',
      '.back-to-top',
      '.site-footer',
      '.footer-grid',
      '.tag',
      '.btn-primary',
      '.btn-secondary',
      '.pillar-hero',
      '.project-card',
      '.cross-links',
      '.donate-section',
    ];

    requiredClasses.forEach((cls) => {
      test(`defines styles for ${cls}`, () => {
        expect(css).toContain(cls);
      });
    });
  });

  describe('responsive breakpoints', () => {
    test('has at least one @media query', () => {
      expect(css).toContain('@media');
    });

    test('includes a mobile breakpoint (max-width)', () => {
      expect(css).toMatch(/@media[^{]*max-width/);
    });
  });

  describe('reveal animation', () => {
    test('defines .reveal class', () => {
      expect(css).toContain('.reveal');
    });

    test('defines .reveal.visible state', () => {
      expect(css).toContain('.reveal.visible');
    });
  });

  describe('pillar color accent usage', () => {
    const pillars = ['health', 'education', 'safety', 'housing', 'services', 'jobs', 'business'];

    pillars.forEach((pillar) => {
      test(`references --color-accent-${pillar}`, () => {
        expect(css).toContain(`--color-accent-${pillar}`);
      });
    });
  });
});
