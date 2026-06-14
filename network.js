/* Access To — integrated network renderer.
 * Progressive enhancement: fetches the generated graph.json (the join of
 * repos.json + content.json) and renders the pillar connection graph, the
 * cross-pillar journeys, and per-page "connects to" sections.
 *
 * Additive by design — does not redefine theme/nav helpers that live inline
 * in each page. Every render target is optional, so this script is safe to
 * load on any page; if graph.json fails to load, the static HTML fallback
 * already in the markup remains.
 */
(function () {
  'use strict';

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function byPillar(graph) {
    var map = {};
    graph.nodes.forEach(function (n) { map[n.pillar] = n; });
    return map;
  }

  function isDark() {
    return document.documentElement.getAttribute('data-theme') === 'dark';
  }

  // Theme-aware pillar color: dark-mode palette under [data-theme="dark"].
  function pillarColor(node) {
    return '#' + (isDark() && node.color_dark ? node.color_dark : node.color);
  }

  // ── Connection graph (radial SVG node-link diagram) ──
  function renderGraph(graph) {
    var host = document.getElementById('network-graph');
    if (!host) return;

    var nodes = graph.nodes;
    var n = nodes.length;
    var SIZE = 520, CENTER = SIZE / 2, RADIUS = SIZE * 0.36, R = 30;
    var pos = {};
    nodes.forEach(function (node, i) {
      var angle = (i / n) * 2 * Math.PI - Math.PI / 2;
      pos[node.pillar] = { x: CENTER + RADIUS * Math.cos(angle), y: CENTER + RADIUS * Math.sin(angle) };
    });

    var svg = '<svg viewBox="0 0 ' + SIZE + ' ' + SIZE + '" class="network-svg" role="group" ' +
      'aria-label="Diagram of how the ' + n + ' pillars connect">';

    // Edges first (drawn under nodes). De-duplicate A-B / B-A into one undirected line.
    var seen = {};
    graph.edges.forEach(function (e) {
      var key = [e.from, e.to].sort().join('~');
      if (seen[key]) return;
      seen[key] = true;
      var a = pos[e.from], b = pos[e.to];
      if (!a || !b) return;
      svg += '<line class="net-edge" data-a="' + e.from + '" data-b="' + e.to + '" ' +
        'x1="' + a.x.toFixed(1) + '" y1="' + a.y.toFixed(1) + '" ' +
        'x2="' + b.x.toFixed(1) + '" y2="' + b.y.toFixed(1) + '" />';
    });

    // Nodes as focusable links.
    nodes.forEach(function (node) {
      var p = pos[node.pillar];
      var color = pillarColor(node);
      svg += '<a class="net-node" href="' + esc(node.page) + '" data-pillar="' + esc(node.pillar) + '" ' +
        'aria-label="Access to ' + esc(node.title) + ' — connects to ' +
        esc(node.connects_to.join(', ')) + '">' +
        '<title>Access to ' + esc(node.title) + '</title>' +
        '<circle class="net-dot" cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="' + R + '" ' +
        'fill="' + color + '" />' +
        '<text class="net-label" x="' + p.x.toFixed(1) + '" y="' + (p.y + 4).toFixed(1) + '" ' +
        'text-anchor="middle">' + esc(node.title) + '</text>' +
        '</a>';
    });
    svg += '</svg>';
    host.innerHTML = svg;

    // Highlight a node's connections on hover/focus.
    var anchors = host.querySelectorAll('.net-node');
    function focusPillar(pillar) {
      host.classList.add('net-active');
      var node = byPillar(graph)[pillar];
      var related = {};
      related[pillar] = true;
      if (node) node.connects_to.forEach(function (t) { related[t] = true; });
      host.querySelectorAll('.net-node').forEach(function (a) {
        a.classList.toggle('net-dim', !related[a.getAttribute('data-pillar')]);
      });
      host.querySelectorAll('.net-edge').forEach(function (l) {
        var on = l.getAttribute('data-a') === pillar || l.getAttribute('data-b') === pillar;
        l.classList.toggle('net-edge-on', on);
        l.classList.toggle('net-dim', !on);
      });
    }
    function clearFocus() {
      host.classList.remove('net-active');
      host.querySelectorAll('.net-dim').forEach(function (el) { el.classList.remove('net-dim'); });
      host.querySelectorAll('.net-edge-on').forEach(function (el) { el.classList.remove('net-edge-on'); });
    }
    anchors.forEach(function (a) {
      var pillar = a.getAttribute('data-pillar');
      a.addEventListener('mouseenter', function () { focusPillar(pillar); });
      a.addEventListener('focus', function () { focusPillar(pillar); });
      a.addEventListener('mouseleave', clearFocus);
      a.addEventListener('blur', clearFocus);
    });
  }

  // ── Journey / roadmap strips ──
  function journeyHTML(graph, journey) {
    var nmap = byPillar(graph);
    var steps = journey.flow.map(function (pillar, i) {
      var node = nmap[pillar];
      if (!node) return '';
      var arrow = i < journey.flow.length - 1 ? '<span class="journey-arrow" aria-hidden="true">&#8594;</span>' : '';
      return '<a class="journey-step" href="' + esc(node.page) + '" ' +
        'style="--journey-color:' + pillarColor(node) + '">' + esc(node.title) + '</a>' + arrow;
    }).join('');
    return '<article class="journey-card">' +
      '<h3 class="journey-name">' + esc(journey.name) + '</h3>' +
      '<p class="journey-persona">' + esc(journey.persona) + '</p>' +
      '<div class="journey-flow">' + steps + '</div>' +
      '<p class="journey-narrative">' + esc(journey.narrative) + '</p>' +
      '</article>';
  }

  function renderJourneys(graph) {
    var host = document.getElementById('journeys');
    if (!host) return;
    host.innerHTML = graph.journeys.map(function (j) { return journeyHTML(graph, j); }).join('');
  }

  // ── Per-pillar-page "connects to" + relevant journeys ──
  function renderPageConnections(graph) {
    var host = document.querySelector('[data-network-for]');
    if (!host) return;
    var pillar = host.getAttribute('data-network-for');
    var nmap = byPillar(graph);
    var node = nmap[pillar];
    if (!node) return;

    var cards = node.connects_to.map(function (to) {
      var t = nmap[to];
      if (!t) return '';
      return '<a class="connect-card" href="' + esc(t.page) + '" style="--connect-color:' + pillarColor(t) + '">' +
        '<span class="connect-title">Access to ' + esc(t.title) + '</span>' +
        '<span class="connect-desc">' + esc(t.description) + '</span>' +
        '<span class="connect-arrow" aria-hidden="true">&#8594;</span>' +
        '</a>';
    }).join('');

    var related = graph.journeys.filter(function (j) { return j.flow.indexOf(pillar) !== -1; });
    var journeysHTML = related.length
      ? '<h3 class="connect-subhead">Journeys through ' + esc(node.title) + '</h3>' +
        '<div class="journeys-grid">' + related.map(function (j) { return journeyHTML(graph, j); }).join('') + '</div>'
      : '';

    host.innerHTML =
      '<h2>How ' + esc(node.title) + ' connects</h2>' +
      '<p class="connect-intro">Access to ' + esc(node.title) +
      ' works alongside these pillars to support a person’s full journey.</p>' +
      '<div class="connect-grid">' + cards + '</div>' +
      journeysHTML;
  }

  var currentGraph = null;

  function init(graph) {
    currentGraph = graph;
    renderGraph(graph);
    renderJourneys(graph);
    renderPageConnections(graph);
  }

  // Re-render with the dark/light palette when the theme toggles.
  var themeObserver = new MutationObserver(function () {
    if (currentGraph) init(currentGraph);
  });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  // Only fetch if this page actually has a render target.
  if (document.getElementById('network-graph') ||
      document.getElementById('journeys') ||
      document.querySelector('[data-network-for]')) {
    fetch('graph.json')
      .then(function (r) { return r.json(); })
      .then(init)
      .catch(function () { /* static fallback markup remains in place */ });
  }
})();
