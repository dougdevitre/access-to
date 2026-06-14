'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const readJSON = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), 'utf-8'));

describe('Integrated network graph (graph.json)', () => {
  let graph;
  let repos;
  let content;

  beforeAll(() => {
    graph = readJSON('graph.json');
    repos = readJSON('.github/config/repos.json');
    content = readJSON('.github/config/content.json');
  });

  const nonHubPillars = () =>
    repos.repos.filter((r) => r.role !== 'hub').map((r) => r.pillar);

  test('is valid JSON with the expected top-level shape', () => {
    expect(graph).toBeDefined();
    expect(Array.isArray(graph.nodes)).toBe(true);
    expect(Array.isArray(graph.edges)).toBe(true);
    expect(Array.isArray(graph.journeys)).toBe(true);
  });

  test('has one node per non-hub repo', () => {
    expect(graph.nodes.length).toBe(nonHubPillars().length);
    const graphPillars = graph.nodes.map((n) => n.pillar).sort();
    expect(graphPillars).toEqual(nonHubPillars().sort());
  });

  test('every node carries the fields the site renders', () => {
    graph.nodes.forEach((n) => {
      expect(n.pillar).toBeTruthy();
      expect(n.title).toBeTruthy();
      expect(n.color).toMatch(/^[0-9a-fA-F]{6}$/);
      expect(n.page).toBe(`${n.pillar}.html`);
      expect(n.repo).toMatch(/^[a-z0-9-]+$/);
      expect(Array.isArray(n.connects_to)).toBe(true);
    });
  });

  test('owner is carried from repos.json', () => {
    expect(graph.owner).toBe(repos.owner);
  });

  test('node colors come from repos.json (single source of truth)', () => {
    const byName = {};
    repos.repos.forEach((r) => { byName[r.pillar] = r; });
    graph.nodes.forEach((n) => {
      const repo = byName[n.pillar];
      expect(n.color.toLowerCase()).toBe(repo.color.toLowerCase());
      expect(n.color_dark).toMatch(/^[0-9a-fA-F]{6}$/);
      if (repo.color_dark) {
        expect(n.color_dark.toLowerCase()).toBe(repo.color_dark.toLowerCase());
      }
    });
  });

  test('content.json no longer duplicates per-pillar colors', () => {
    nonHubPillars().forEach((p) => {
      expect(content.brand.colors[p]).toBeUndefined();
    });
  });

  test('styles.css pillar tokens match repos.json colors (no drift)', () => {
    const css = fs.readFileSync(path.join(ROOT, 'styles.css'), 'utf-8');
    repos.repos.filter((r) => r.role !== 'hub').forEach((r) => {
      const m = css.match(new RegExp(`--color-accent-${r.pillar}:\\s*#([0-9a-fA-F]{6})`));
      expect(m).toBeTruthy();
      expect(m[1].toLowerCase()).toBe(r.color.toLowerCase());
    });
  });

  test('every edge references real pillar nodes', () => {
    const pillars = new Set(graph.nodes.map((n) => n.pillar));
    graph.edges.forEach((e) => {
      expect(pillars.has(e.from)).toBe(true);
      expect(pillars.has(e.to)).toBe(true);
    });
  });

  test('node connects_to matches the edge list', () => {
    const edgeKeys = new Set(graph.edges.map((e) => `${e.from}>${e.to}`));
    graph.nodes.forEach((n) => {
      n.connects_to.forEach((to) => {
        expect(edgeKeys.has(`${n.pillar}>${to}`)).toBe(true);
      });
    });
  });

  test('every journey flow references real pillars', () => {
    const pillars = new Set(graph.nodes.map((n) => n.pillar));
    graph.journeys.forEach((j) => {
      expect(j.flow.length).toBeGreaterThanOrEqual(2);
      j.flow.forEach((p) => expect(pillars.has(p)).toBe(true));
    });
  });

  test('journeys mirror content.json cross_pillar_stories', () => {
    expect(graph.journeys.length).toBe(content.cross_pillar_stories.length);
  });

  test('content.json stats are consistent with the graph', () => {
    expect(content.brand.stats.pillars).toBe(graph.nodes.length);
    expect(content.brand.stats.projects).toBe(graph.nodes.length);
  });
});

describe('Network is wired into the pages', () => {
  const cheerio = require('cheerio');
  const load = (p) => cheerio.load(fs.readFileSync(path.join(ROOT, p), 'utf-8'));
  const PILLARS = ['health', 'education', 'safety', 'housing', 'services', 'jobs', 'business'];

  test('index.html has graph + journeys targets and loads network.js', () => {
    const $ = load('index.html');
    expect($('#network-graph').length).toBe(1);
    expect($('#journeys').length).toBe(1);
    expect($('script[src="network.js"]').length).toBe(1);
  });

  PILLARS.forEach((pillar) => {
    test(`${pillar}.html has its data-network-for target and loads network.js`, () => {
      const $ = load(`${pillar}.html`);
      const host = $(`[data-network-for="${pillar}"]`);
      expect(host.length).toBe(1);
      expect($('script[src="network.js"]').length).toBe(1);
      // Static fallback nav is preserved for the no-JS case.
      expect($('.cross-links-grid').length).toBe(1);
    });
  });
});
