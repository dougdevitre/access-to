/**
 * @jest-environment jsdom
 *
 * Exercises network.js against the real graph.json in a DOM, confirming the
 * connection graph, journeys, and per-page connections actually render.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const graph = JSON.parse(fs.readFileSync(path.join(ROOT, 'graph.json'), 'utf-8'));

function loadNetworkJS() {
  // network.js is an IIFE that runs on require and fetches graph.json.
  global.fetch = () => Promise.resolve({ json: () => Promise.resolve(graph) });
  jest.isolateModules(() => { require('../network.js'); });
  // Let the fetch().then() microtasks flush.
  return new Promise((resolve) => setTimeout(resolve, 0));
}

afterEach(() => { delete global.fetch; document.body.innerHTML = ''; });

test('renders one graph node per pillar and all journeys', async () => {
  document.body.innerHTML = '<div id="network-graph"></div><div id="journeys"></div>';
  await loadNetworkJS();
  expect(document.querySelectorAll('#network-graph .net-node').length).toBe(graph.nodes.length);
  expect(document.querySelectorAll('#network-graph .net-edge').length).toBeGreaterThan(0);
  expect(document.querySelectorAll('#journeys .journey-card').length).toBe(graph.journeys.length);
});

test('renders per-page connections from the graph', async () => {
  document.body.innerHTML = '<section data-network-for="education"></section>';
  await loadNetworkJS();
  const host = document.querySelector('[data-network-for]');
  expect(host.querySelector('h2')).toBeTruthy();
  const edu = graph.nodes.find((n) => n.pillar === 'education');
  expect(host.querySelectorAll('.connect-card').length).toBe(edu.connects_to.length);
});

test('is a no-op (no throw) when the page has no network targets', async () => {
  document.body.innerHTML = '<div id="unrelated"></div>';
  await expect(loadNetworkJS()).resolves.toBeUndefined();
  expect(document.querySelectorAll('.net-node').length).toBe(0);
});
