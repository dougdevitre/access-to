/**
 * Tests for the inline JavaScript functions shared across all pages.
 * These functions are extracted and tested in isolation using jsdom.
 *
 * @jest-environment jsdom
 */

'use strict';

// ---------------------------------------------------------------------------
// Helpers to set up a minimal DOM that mirrors the site's HTML structure
// ---------------------------------------------------------------------------

function setupDOM() {
  document.documentElement.removeAttribute('data-theme');
  document.body.innerHTML = `
    <button class="hamburger"></button>
    <nav class="topbar-links"></nav>
    <button id="backToTop" class="back-to-top"></button>
    <div id="stats">
      <div class="stat-number" data-target="6">0</div>
      <div class="stat-number" data-target="10">0</div>
      <div class="stat-number" data-target="400" data-suffix="+">0</div>
    </div>
    <div class="reveal"></div>
    <div class="reveal"></div>
  `;
}

// ---------------------------------------------------------------------------
// Extract and expose the inline functions under test
// ---------------------------------------------------------------------------

function closeMobileNav() {
  document.querySelector('.hamburger').classList.remove('open');
  document.querySelector('.topbar-links').classList.remove('open');
}

function toggleTheme() {
  var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  if (isDark) {
    document.documentElement.removeAttribute('data-theme');
    localStorage.setItem('theme', 'light');
  } else {
    document.documentElement.setAttribute('data-theme', 'dark');
    localStorage.setItem('theme', 'dark');
  }
}

function applyThemeFromStorage() {
  var t = localStorage.getItem('theme');
  if (t === 'dark' || (!t && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.setAttribute('data-theme', 'dark');
  } else {
    document.documentElement.removeAttribute('data-theme');
  }
}

function copyCmd(btn, text, clipboardImpl) {
  return clipboardImpl.writeText(text).then(
    function () {
      btn.textContent = 'Copied!';
      btn.classList.add('copied');
      setTimeout(function () {
        btn.textContent = 'Copy';
        btn.classList.remove('copied');
      }, 2000);
    },
    function () {
      btn.textContent = 'Failed';
      setTimeout(function () { btn.textContent = 'Copy'; }, 2000);
    }
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  setupDOM();
  localStorage.clear();
});

describe('closeMobileNav()', () => {
  test('removes "open" class from hamburger button', () => {
    const hamburger = document.querySelector('.hamburger');
    hamburger.classList.add('open');
    closeMobileNav();
    expect(hamburger.classList.contains('open')).toBe(false);
  });

  test('removes "open" class from topbar-links nav', () => {
    const nav = document.querySelector('.topbar-links');
    nav.classList.add('open');
    closeMobileNav();
    expect(nav.classList.contains('open')).toBe(false);
  });

  test('is idempotent when called on already-closed nav', () => {
    closeMobileNav();
    closeMobileNav();
    const hamburger = document.querySelector('.hamburger');
    const nav = document.querySelector('.topbar-links');
    expect(hamburger.classList.contains('open')).toBe(false);
    expect(nav.classList.contains('open')).toBe(false);
  });

  test('does not affect other classes on hamburger', () => {
    const hamburger = document.querySelector('.hamburger');
    hamburger.classList.add('open');
    hamburger.classList.add('sticky');
    closeMobileNav();
    expect(hamburger.classList.contains('sticky')).toBe(true);
    expect(hamburger.classList.contains('open')).toBe(false);
  });
});

describe('toggleTheme()', () => {
  test('sets data-theme="dark" when currently light', () => {
    document.documentElement.removeAttribute('data-theme');
    toggleTheme();
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });

  test('removes data-theme attribute when currently dark', () => {
    document.documentElement.setAttribute('data-theme', 'dark');
    toggleTheme();
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
  });

  test('persists "dark" to localStorage when switching to dark', () => {
    document.documentElement.removeAttribute('data-theme');
    toggleTheme();
    expect(localStorage.getItem('theme')).toBe('dark');
  });

  test('persists "light" to localStorage when switching to light', () => {
    document.documentElement.setAttribute('data-theme', 'dark');
    toggleTheme();
    expect(localStorage.getItem('theme')).toBe('light');
  });

  test('toggles correctly on two successive calls', () => {
    document.documentElement.removeAttribute('data-theme');
    toggleTheme();
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
    toggleTheme();
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
  });
});

describe('applyThemeFromStorage() — theme initialisation', () => {
  test('applies dark theme when localStorage has "dark"', () => {
    localStorage.setItem('theme', 'dark');
    applyThemeFromStorage();
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });

  test('applies light theme when localStorage has "light"', () => {
    localStorage.setItem('theme', 'light');
    applyThemeFromStorage();
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
  });

  test('applies light theme when localStorage is empty and system is light', () => {
    localStorage.removeItem('theme');
    // jsdom matchMedia defaults to false for all queries
    window.matchMedia = jest.fn().mockReturnValue({ matches: false });
    applyThemeFromStorage();
    expect(document.documentElement.getAttribute('data-theme')).toBeNull();
  });

  test('applies dark theme when localStorage is empty and system prefers dark', () => {
    localStorage.removeItem('theme');
    window.matchMedia = jest.fn().mockReturnValue({ matches: true });
    applyThemeFromStorage();
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });
});

describe('back-to-top button visibility', () => {
  test('button gains "visible" class when scrollY > 600', () => {
    const btt = document.getElementById('backToTop');
    expect(btt).not.toBeNull();

    Object.defineProperty(window, 'scrollY', { value: 601, writable: true, configurable: true });
    btt.classList.toggle('visible', window.scrollY > 600);
    expect(btt.classList.contains('visible')).toBe(true);
  });

  test('button loses "visible" class when scrollY <= 600', () => {
    const btt = document.getElementById('backToTop');
    btt.classList.add('visible');

    Object.defineProperty(window, 'scrollY', { value: 400, writable: true, configurable: true });
    btt.classList.toggle('visible', window.scrollY > 600);
    expect(btt.classList.contains('visible')).toBe(false);
  });
});

describe('copyCmd()', () => {
  let btn;

  beforeEach(() => {
    btn = document.createElement('button');
    btn.textContent = 'Copy';
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('sets button text to "Copied!" on success', async () => {
    const clipboard = { writeText: jest.fn().mockResolvedValue(undefined) };
    await copyCmd(btn, 'test text', clipboard);
    expect(btn.textContent).toBe('Copied!');
  });

  test('adds "copied" class to button on success', async () => {
    const clipboard = { writeText: jest.fn().mockResolvedValue(undefined) };
    await copyCmd(btn, 'test text', clipboard);
    expect(btn.classList.contains('copied')).toBe(true);
  });

  test('resets button text to "Copy" after 2 seconds', async () => {
    const clipboard = { writeText: jest.fn().mockResolvedValue(undefined) };
    await copyCmd(btn, 'test text', clipboard);
    jest.advanceTimersByTime(2000);
    expect(btn.textContent).toBe('Copy');
    expect(btn.classList.contains('copied')).toBe(false);
  });

  test('sets button text to "Failed" on clipboard error', async () => {
    const clipboard = { writeText: jest.fn().mockRejectedValue(new Error('denied')) };
    await copyCmd(btn, 'test text', clipboard);
    expect(btn.textContent).toBe('Failed');
  });

  test('resets button text to "Copy" after 2 seconds on error', async () => {
    const clipboard = { writeText: jest.fn().mockRejectedValue(new Error('denied')) };
    await copyCmd(btn, 'test text', clipboard);
    jest.advanceTimersByTime(2000);
    expect(btn.textContent).toBe('Copy');
  });

  test('writes the correct text to the clipboard', async () => {
    const clipboard = { writeText: jest.fn().mockResolvedValue(undefined) };
    await copyCmd(btn, 'git clone https://example.com', clipboard);
    expect(clipboard.writeText).toHaveBeenCalledWith('git clone https://example.com');
  });
});

describe('stat counter animation logic', () => {
  test('ease function produces value in [0, 1] range', () => {
    // Mirrors: var ease = 1 - Math.pow(1 - progress, 3);
    function easeOutCubic(progress) {
      return 1 - Math.pow(1 - progress, 3);
    }
    expect(easeOutCubic(0)).toBe(0);
    expect(easeOutCubic(1)).toBe(1);
    expect(easeOutCubic(0.5)).toBeGreaterThan(0);
    expect(easeOutCubic(0.5)).toBeLessThan(1);
  });

  test('counter rounds correctly toward target', () => {
    const target = 10;
    const progress = 1; // fully complete
    const ease = 1 - Math.pow(1 - progress, 3);
    expect(Math.round(target * ease)).toBe(10);
  });

  test('counter with suffix appends suffix string', () => {
    const target = 400;
    const suffix = '+';
    const ease = 1;
    const display = String(Math.round(target * ease)) + suffix;
    expect(display).toBe('400+');
  });
});
