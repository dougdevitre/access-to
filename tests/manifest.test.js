'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const MANIFEST_PATH = path.join(ROOT, 'manifest.json');

describe('PWA Web App Manifest (manifest.json)', () => {
  let manifest;

  beforeAll(() => {
    const raw = fs.readFileSync(MANIFEST_PATH, 'utf-8');
    manifest = JSON.parse(raw);
  });

  test('file exists and is valid JSON', () => {
    expect(manifest).toBeDefined();
    expect(typeof manifest).toBe('object');
  });

  test('has "name" field', () => {
    expect(manifest.name).toBeTruthy();
    expect(typeof manifest.name).toBe('string');
  });

  test('has "short_name" field', () => {
    expect(manifest.short_name).toBeTruthy();
    expect(typeof manifest.short_name).toBe('string');
  });

  test('short_name is 12 characters or fewer (recommended limit)', () => {
    expect(manifest.short_name.length).toBeLessThanOrEqual(12);
  });

  test('has "description" field', () => {
    expect(manifest.description).toBeTruthy();
    expect(typeof manifest.description).toBe('string');
  });

  test('has "start_url" field', () => {
    expect(manifest.start_url).toBeTruthy();
  });

  test('has "display" field with valid value', () => {
    const validDisplayModes = ['fullscreen', 'standalone', 'minimal-ui', 'browser'];
    expect(validDisplayModes).toContain(manifest.display);
  });

  test('has "background_color" field with valid hex color', () => {
    expect(manifest.background_color).toBeTruthy();
    expect(manifest.background_color).toMatch(/^#[0-9A-Fa-f]{3,6}$/);
  });

  test('has "theme_color" field with valid hex color', () => {
    expect(manifest.theme_color).toBeTruthy();
    expect(manifest.theme_color).toMatch(/^#[0-9A-Fa-f]{3,6}$/);
  });

  test('has "icons" array', () => {
    expect(Array.isArray(manifest.icons)).toBe(true);
    expect(manifest.icons.length).toBeGreaterThan(0);
  });

  test('each icon entry has "src", "sizes", and "type"', () => {
    manifest.icons.forEach((icon) => {
      expect(icon.src).toBeTruthy();
      expect(icon.sizes).toBeTruthy();
      expect(icon.type).toBeTruthy();
    });
  });

  test('icon src files exist in the repository', () => {
    manifest.icons.forEach((icon) => {
      // Resolve relative to root; skip absolute URLs
      if (!icon.src.startsWith('http')) {
        const iconPath = path.join(ROOT, icon.src);
        expect(fs.existsSync(iconPath)).toBe(true);
      }
    });
  });

  test('manifest is referenced by all main HTML pages', () => {
    const cheerio = require('cheerio');
    const mainPages = ['index.html', 'health.html', 'education.html', 'safety.html', 'housing.html', 'services.html', 'jobs.html', 'business.html'];
    mainPages.forEach((page) => {
      const html = fs.readFileSync(path.join(ROOT, page), 'utf-8');
      const $ = cheerio.load(html);
      const manifestLink = $('link[rel="manifest"]');
      expect(manifestLink.length).toBe(1);
      expect(manifestLink.attr('href')).toBe('manifest.json');
    });
  });
});
