/* dougdevitre.org — homepage app. Vanilla JS, no build step.
 *
 * Everything the app shows comes from the JSON that render-hub.sh embeds in
 * index.html (#app-data): the projects (repos.json), the journey content
 * (journey.json), the narration transcripts and the words the app writes at
 * runtime (i18n/<lang>.json "ui"). The same script runs every language's page
 * (es/index.html embeds Spanish data), so nothing here is in English.
 * Narration MP3s are optional: a play button appears only when
 * audio/manifest.json lists its clip (Spanish clip ids end in -es).
 * Without JavaScript every door is still a working link.
 */
(function () {
  'use strict';

  var dataEl = document.getElementById('app-data');
  if (!dataEl) return;
  var DATA = JSON.parse(dataEl.textContent);
  var PROJECTS = DATA.projects;
  var BY_ID = {};
  PROJECTS.forEach(function (p, i) { p.index = i; BY_ID[p.id] = p; });
  var J = DATA.journey;
  var T = DATA.ui;                                   // this page's words
  var ROOT = DATA.root || '';                        // '' on /, '../' on /es/
  var SUFFIX = DATA.lang && DATA.lang !== 'en' ? '-' + DATA.lang : '';   // clip ids
  function fmt(s, v) { return String(s).replace(/\{(\w+)\}/g, function (m, k) { return v[k] != null ? v[k] : m; }); }

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $all(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function el(tag, attrs, text) {
    var n = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) { n.setAttribute(k, attrs[k]); });
    if (text != null) n.textContent = text;
    return n;
  }
  function store(key, value) {
    try {
      if (value === undefined) return localStorage.getItem(key);
      localStorage.setItem(key, value);
    } catch (e) { return null; }
  }
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── Theme ── */
  $('#theme-toggle').addEventListener('click', function () {
    var dark = document.documentElement.getAttribute('data-theme') === 'dark';
    if (dark) document.documentElement.removeAttribute('data-theme');
    else document.documentElement.setAttribute('data-theme', 'dark');
    store('theme', dark ? 'light' : 'dark');
    tone(dark ? 660 : 440, 0.25, 0.05);
  });

  /* ── Sound: glass-bowl tones made in the browser, no files ──
   * Each door owns one note of a pentatonic scale, so any two doors sound
   * good together: opening a door plays its note, a blend plays both. */
  var soundOn = store('sound') !== 'off';
  var ctx = null;
  var soundBtn = $('#sound-toggle');
  function renderSoundBtn() {
    soundBtn.setAttribute('aria-pressed', String(soundOn));
    soundBtn.setAttribute('aria-label', soundOn ? T.sound_on : T.sound_off);
  }
  renderSoundBtn();
  soundBtn.addEventListener('click', function () {
    soundOn = !soundOn;
    store('sound', soundOn ? 'on' : 'off');
    renderSoundBtn();
    if (soundOn) tone(523.25, 0.4, 0.07);
    else stopNarration();
  });

  function audio() {
    if (!ctx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }
  function tone(freq, seconds, gain, delay) {
    if (!soundOn) return;
    var ac = audio();
    if (!ac) return;
    var t = ac.currentTime + (delay || 0);
    var vol = (gain || 0.08) * (narrating ? 0.3 : 1);
    [[1, 1], [2.76, 0.25], [5.4, 0.08]].forEach(function (partial) {   // bowl-like partials
      var osc = ac.createOscillator();
      var amp = ac.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq * partial[0];
      amp.gain.setValueAtTime(0.0001, t);
      amp.gain.exponentialRampToValueAtTime(vol * partial[1], t + 0.01);
      amp.gain.exponentialRampToValueAtTime(0.0001, t + seconds / partial[0] + 0.05);
      osc.connect(amp).connect(ac.destination);
      osc.start(t);
      osc.stop(t + seconds + 0.1);
    });
  }
  var SCALE = [261.63, 293.66, 329.63, 392.0, 440.0];                 // C D E G A
  function note(i) { return SCALE[i % 5] * Math.pow(2, Math.floor(i / 5) % 3); }
  function haptic() { if (navigator.vibrate) navigator.vibrate(8); }

  /* ── Narration ── */
  var CLIPS = {};
  var player = null;
  var playingBtn = null;
  var narrating = false;

  $all('[data-transcript]').forEach(function (d) {
    var text = DATA.clips[d.getAttribute('data-transcript')];
    if (text) $('p', d).textContent = text;
  });

  fetch(ROOT + 'audio/manifest.json', { cache: 'no-cache' })
    .then(function (r) { return r.ok ? r.json() : { clips: {} }; })
    .then(function (m) {
      CLIPS = (m && m.clips) || {};
      $all('[data-clip]').forEach(function (b) { if (CLIPS[b.getAttribute('data-clip') + SUFFIX]) b.hidden = false; });
    })
    .catch(function () { /* no narration yet: buttons stay hidden */ });

  function stopNarration() {
    if (player) { player.pause(); player = null; }
    if (playingBtn) playingBtn.setAttribute('data-playing', 'false');
    playingBtn = null;
    narrating = false;
  }
  function playClip(id, btn) {
    var clip = CLIPS[id + SUFFIX];
    if (!clip) return;
    if (playingBtn === btn) { stopNarration(); return; }
    stopNarration();
    player = new Audio(ROOT + clip.file);
    playingBtn = btn;
    narrating = true;
    btn.setAttribute('data-playing', 'true');
    player.addEventListener('ended', stopNarration);
    player.play().catch(stopNarration);
  }
  $all('[data-clip]').forEach(function (b) {
    b.addEventListener('click', function () {
      haptic();
      var id = b.getAttribute('data-clip');
      if (id === 'welcome') lightTheLamp();
      playClip(id, b);
    });
  });

  /* The one orchestrated moment: the lamp sweeps across the doors. */
  function lightTheLamp() {
    var lamp = $('.lamp');
    lamp.classList.remove('lit');
    void lamp.offsetWidth;
    lamp.classList.add('lit');
    var doors = $all('.door');
    doors.forEach(function (d, i) {
      if (reducedMotion) return;
      setTimeout(function () {
        d.classList.add('caught');
        setTimeout(function () { d.classList.remove('caught'); }, 420);
      }, 900 + i * 70);
    });
  }

  /* ── Detail sheet ── */
  var sheet = $('#sheet');
  var current = null;

  function link(href, label, primary, external) {
    var a = el('a', { href: href, class: 'big-btn' + (primary ? '' : ' ghost') }, label);
    if (external) { a.target = '_blank'; a.rel = 'noopener'; }
    return a;
  }

  function fillSheet(p) {
    current = p;
    sheet.style.setProperty('--c', p.color);
    $('.sheet-icon svg', sheet).innerHTML = p.icon;                   // trusted: icons.json
    $('#sheet-title').textContent = p.title;
    $('.sheet-meta', sheet).textContent = fmt(T.status_scope, { status: p.status, scope: p.scope });
    $('.sheet-desc', sheet).textContent = p.description + '.';

    var listen = $('.sheet-listen', sheet);
    listen.hidden = !CLIPS[p.id + SUFFIX];
    listen.setAttribute('data-playing', 'false');
    $('.big-btn-text', listen).textContent = fmt(T.listen_to, { title: p.title });
    var tr = $('.sheet-transcript', sheet);
    tr.open = false;
    $('p', tr).textContent = DATA.clips[p.id] || '';

    var facts = $('.sheet-facts', sheet);
    facts.textContent = '';
    [[T.fact_adopter, p.adopter], [T.fact_pilot, p.pilot], [T.fact_audience, p.audience.join(', ')]]
      .forEach(function (f) {
        if (!f[1]) return;
        var row = el('div');
        row.appendChild(el('dt', {}, f[0]));
        row.appendChild(el('dd', {}, f[1].charAt(0).toUpperCase() + f[1].slice(1)));
        facts.appendChild(row);
      });

    var steps = $('.sheet-beacon', sheet);
    steps.textContent = '';
    J.beacon.forEach(function (s, i) {
      var li = el('li');
      li.appendChild(el('b', { 'aria-hidden': 'true' }, s.letter));
      var span = el('span');
      span.appendChild(el('strong', {}, s.title + '. '));
      var prompt = s.prompt;
      if (i === 0 && p.audience.length) prompt += fmt(T.beacon_start, { audience: p.audience.join(', ') });
      if (i === 2 && p.adopter) prompt += fmt(T.beacon_here, { adopter: p.adopter });
      span.appendChild(document.createTextNode(prompt));
      li.appendChild(span);
      steps.appendChild(li);
    });

    var blend = $('.sheet-blend', sheet);
    blend.textContent = '';
    $('.sheet-blend-title', sheet).hidden = !p.connects.length;
    p.connects.forEach(function (id) {
      var q = BY_ID[id];
      if (!q) return;
      var chip = el('button', { type: 'button', class: 'chip', 'data-door': q.id }, q.title);
      chip.style.setProperty('--c', q.color);
      chip.addEventListener('click', function () {
        haptic();
        tone(note(p.index), 0.9, 0.07);
        tone(note(q.index), 0.9, 0.07, 0.12);
        stopNarration();
        openSheet(q.id, true);
        $('.sheet-inner', sheet).scrollIntoView({ block: 'start' });
      });
      blend.appendChild(chip);
    });

    var links = $('.sheet-links', sheet);
    links.textContent = '';
    if (p.live) links.appendChild(link(p.live, p.cta, true, true));
    if (p.page) links.appendChild(link(p.page, fmt(T.explore, { title: p.title }), !p.live, false));
    if (p.repo) links.appendChild(link(p.repo, T.view_source, !p.live && !p.page, true));
    if (p.private) links.appendChild(el('p', { class: 'step-note' }, T.private_note));
    else if (T.links_note) links.appendChild(el('p', { class: 'step-note' }, T.links_note));
    links.appendChild(link('mailto:dougdevitre@gmail.com?subject=' + encodeURIComponent(fmt(T.mail_subject, { title: p.title })),
      T.bring_it, false, false));
  }

  function openSheet(id, fromBlend) {
    var p = BY_ID[id];
    if (!p) return;
    fillSheet(p);
    if (!sheet.open) {
      if (typeof sheet.showModal === 'function') sheet.showModal();
      else sheet.setAttribute('open', '');
    }
    if (!fromBlend) tone(note(p.index), 1.1, 0.08);
    try { history.replaceState(null, '', '#door=' + id); } catch (e) {}
  }
  function closeSheet() {
    stopNarration();
    if (sheet.open && typeof sheet.close === 'function') sheet.close();
    else sheet.removeAttribute('open');
  }
  sheet.addEventListener('close', function () {
    stopNarration();
    tone(196, 0.5, 0.04);
    try { history.replaceState(null, '', location.pathname); } catch (e) {}
    var door = current && $('.door[data-id="' + current.id + '"]');
    if (door) door.focus();
  });
  $('.sheet-close', sheet).addEventListener('click', closeSheet);
  sheet.addEventListener('click', function (e) { if (e.target === sheet) closeSheet(); });   // backdrop
  $('.sheet-listen', sheet).addEventListener('click', function () {
    if (current) playClip(current.id, $('.sheet-listen', sheet));
  });

  $all('.door').forEach(function (d) {
    d.addEventListener('click', function (e) {
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;
      e.preventDefault();
      haptic();
      openSheet(d.getAttribute('data-id'));
    });
  });
  function openFromHash() {                      // shared links: dougdevitre.org/#door=access-to-peace
    var m = /^#door=([a-z0-9-]+)$/.exec(location.hash);
    if (m && BY_ID[m[1]] && !(sheet.open && current && current.id === m[1])) openSheet(m[1], true);
  }
  openFromHash();
  window.addEventListener('hashchange', openFromHash);

  /* ── Find my door: who you are, what's going on, where you are → up to 3 doors ──
   * The questions and the need → door mapping live in journey.json (finder).
   * A safety answer always shows the crisis lines before any door. The last
   * result is remembered on this device only, so a return visit opens on it. */
  var F = J.finder;
  if (F) {
    var QUESTIONS = [
      { key: 'role', text: T.q_role, options: F.roles },
      { key: 'need', text: T.q_need, options: F.needs },
      { key: 'place', text: T.q_place, options: F.places }
    ];
    var answers = {};
    var stepIndex = 0;
    var startBtn = $('#finder-start');
    var flow = $('#finder-flow');
    var result = $('#finder-result');
    startBtn.hidden = false;

    var renderQuestion = function () {
      var q = QUESTIONS[stepIndex];
      var qEl = $('#finder-q');
      qEl.textContent = q.text;
      $all('.finder-progress span').forEach(function (s, i) { s.classList.toggle('on', i <= stepIndex); });
      var box = $('#finder-options');
      box.textContent = '';
      q.options.forEach(function (o) {
        var b = el('button', { type: 'button', class: 'finder-option', 'aria-pressed': String(answers[q.key] === o.id) }, o.label);
        b.addEventListener('click', function () {
          haptic();
          tone(SCALE[(stepIndex * 2) % 5] * 2, 0.6, 0.07);
          answers[q.key] = o.id;
          if (stepIndex < QUESTIONS.length - 1) { stepIndex++; renderQuestion(); }
          else showResult(true);
        });
        box.appendChild(b);
      });
      $('#finder-back').hidden = stepIndex === 0;
      qEl.focus();
    };

    var pickDoors = function () {
      var need = F.needs.filter(function (n) { return n.id === answers.need; })[0];
      var role = F.roles.filter(function (r) { return r.id === answers.role; })[0];
      var helpLens = role && role.lens === 'help';
      var all = need.doors.map(function (id) { return BY_ID[id]; }).filter(Boolean);
      // Someone seeking help today needs a tool that works today.
      var usable = helpLens ? all.filter(function (p) { return !p.private && p.stage !== 'spec'; }) : all;
      var local = answers.place === 'missouri' ? usable : usable.filter(function (p) { return p.region !== 'missouri'; });
      var chosen = (local.length ? local : usable.length ? usable : all).slice(0, 3);
      return { need: need, helpLens: helpLens, doors: chosen, missouriOnly: !local.length && answers.place !== 'missouri' };
    };

    var showResult = function (fresh) {
      var r = pickDoors();
      flow.hidden = true;
      startBtn.hidden = true;
      result.hidden = false;

      var crisis = $('#finder-crisis');
      crisis.hidden = !r.need.crisis;
      crisis.textContent = r.need.crisis ? F.crisis_note : '';

      var list = $('#match-list');
      list.textContent = '';
      r.doors.forEach(function (p) {
        var li = el('li');
        var b = el('button', { type: 'button', class: 'match' });
        b.style.setProperty('--c', p.color);
        var icon = el('span', { class: 'door-icon', 'aria-hidden': 'true' });
        icon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + p.icon + '</svg>';
        var text = el('span', { class: 'match-text' });
        text.appendChild(el('span', { class: 'match-name' }, p.title));
        var why = r.helpLens || !p.pilot ? p.description + '.' : fmt(T.pilot_why, { pilot: p.pilot });
        text.appendChild(el('span', { class: 'match-why' }, why));
        if (p.private || p.stage === 'spec') text.appendChild(el('span', { class: 'match-flag' }, p.status));
        else if (p.region === 'missouri' && answers.place !== 'missouri') text.appendChild(el('span', { class: 'match-flag' }, T.built_for_missouri));
        b.appendChild(icon);
        b.appendChild(text);
        b.addEventListener('click', function () { haptic(); openSheet(p.id); });
        li.appendChild(b);
        list.appendChild(li);
      });

      var note = r.helpLens ? F.help_note : T.adopt_note;
      if (r.missouriOnly) note += T.missouri_note;
      $('#finder-note').textContent = note;

      // Light the matching doors in the grid until the guide is restarted.
      $all('.door').forEach(function (d) {
        d.classList.toggle('match-lit', r.doors.some(function (p) { return p.id === d.getAttribute('data-id'); }));
      });
      if (fresh) {
        [0, 2, 4].forEach(function (k, n) { tone(SCALE[k] * 2, 1.4, 0.06, n * 0.1); });
        store('finder', JSON.stringify(answers));
        $('#finder-result-title').focus();
      }
    };

    var startFinder = function () {
      answers = {};
      stepIndex = 0;
      result.hidden = true;
      startBtn.hidden = true;
      flow.hidden = false;
      $all('.door.match-lit').forEach(function (d) { d.classList.remove('match-lit'); });
      store('finder', '');
      renderQuestion();
    };

    startBtn.addEventListener('click', function () { haptic(); tone(SCALE[0] * 2, 0.5, 0.06); startFinder(); });
    $('#finder-restart').addEventListener('click', startFinder);
    $('#finder-back').addEventListener('click', function () {
      if (stepIndex > 0) { stepIndex--; renderQuestion(); }
    });

    // A return visit opens on the last result (stored on this device only).
    try {
      var saved = JSON.parse(store('finder') || 'null');
      var valid = saved && F.roles.some(function (x) { return x.id === saved.role; }) &&
        F.needs.some(function (x) { return x.id === saved.need; }) &&
        F.places.some(function (x) { return x.id === saved.place; });
      if (valid) { answers = saved; showResult(false); }
    } catch (e) { /* ignore a malformed saved answer */ }
  }

  /* ── Distribute virtue: virtue + door + four gates = one mindful step ── */
  var pick = { virtue: null, door: null, gates: {} };

  function chipGroup(container, items, label, onPick) {
    items.forEach(function (item) {
      var b = el('button', { type: 'button', class: 'chip', 'aria-pressed': 'false' }, label(item));
      if (item.color) { b.setAttribute('data-door', item.id); b.style.setProperty('--c', item.color); }
      b.addEventListener('click', function () {
        $all('.chip', container).forEach(function (c) { c.setAttribute('aria-pressed', 'false'); });
        b.setAttribute('aria-pressed', 'true');
        haptic();
        onPick(item);
      });
      container.appendChild(b);
    });
  }

  chipGroup($('#virtue-chips'), J.virtues, function (v) { return v.name; }, function (v) {
    pick.virtue = v;
    var q = $('#virtue-question');
    q.textContent = '';
    q.appendChild(el('strong', {}, v.question + ' '));
    q.appendChild(document.createTextNode(v.practice));
    $('#step-virtue').classList.add('done');
    tone(SCALE[J.virtues.indexOf(v) % 5] * 2, 0.8, 0.07);
    update();
  });
  chipGroup($('#door-chips'), PROJECTS, function (p) { return p.title; }, function (p) {
    pick.door = p;
    $('#step-door').classList.add('done');
    tone(note(p.index), 0.9, 0.07);
    update();
  });

  var gateRow = $('#gates');
  J.gates.forEach(function (g, i) {
    var b = el('button', { type: 'button', class: 'gate', 'aria-pressed': 'false' }, g);
    b.addEventListener('click', function () {
      var on = b.getAttribute('aria-pressed') !== 'true';
      b.setAttribute('aria-pressed', String(on));
      pick.gates[i] = on;
      haptic();
      if (on) tone(SCALE[i + 1] * 2, 0.7, 0.07);
      else tone(SCALE[0], 0.3, 0.04);
      update();
    });
    gateRow.appendChild(b);
  });

  var wasComplete = false;
  function update() {
    var gatesPassed = J.gates.every(function (_, i) { return pick.gates[i]; });
    $('#step-gates').classList.toggle('done', gatesPassed);
    var complete = pick.virtue && pick.door && gatesPassed;
    var box = $('#my-step');
    box.hidden = !complete;
    if (!complete) { wasComplete = false; return; }
    var d = pick.door;
    var text = fmt(T.step, { virtue: pick.virtue.name, practice: pick.virtue.practice, door: d.title }) +
      (d.pilot ? fmt(T.step_pilot, { pilot: d.pilot }) : T.step_end);
    $('#my-step-text').textContent = text;
    if (!wasComplete) {                                                // a resolved chord, once
      [0, 2, 4].forEach(function (k, n) { tone(SCALE[k] * 2, 1.6, 0.06, n * 0.09); });
      box.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'nearest' });
    }
    wasComplete = true;
  }

  $('#share-step').addEventListener('click', function () {
    var text = $('#my-step-text').textContent + T.share_from;
    var btn = this;
    if (navigator.share) {
      navigator.share({ title: T.share_title, text: text, url: DATA.url }).catch(function () {});
    } else if (navigator.clipboard) {
      navigator.clipboard.writeText(text + ' ' + DATA.url).then(function () {
        btn.textContent = T.copied;
        setTimeout(function () { btn.textContent = T.share; }, 1800);
      });
    }
  });
  $('#reset-step').addEventListener('click', function () {
    pick = { virtue: null, door: null, gates: {} };
    $all('#practice [aria-pressed="true"]').forEach(function (b) { b.setAttribute('aria-pressed', 'false'); });
    $all('#practice .step').forEach(function (s) { s.classList.remove('done'); });
    $('#virtue-question').textContent = '';
    update();
    $('#step-virtue').scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth' });
  });

  /* ── BEACON ── */
  var list = $('#beacon-list');
  J.beacon.forEach(function (s, i) {
    var li = el('li', { class: 'beacon-item' });
    var id = 'beacon-' + s.letter;
    var b = el('button', { type: 'button', 'aria-expanded': 'false', 'aria-controls': id });
    b.appendChild(el('span', { class: 'beacon-letter', 'aria-hidden': 'true' }, s.letter));
    b.appendChild(el('span', {}, s.title));
    var p = el('p', { id: id }, s.prompt);
    p.hidden = true;
    b.addEventListener('click', function () {
      var open = b.getAttribute('aria-expanded') !== 'true';
      b.setAttribute('aria-expanded', String(open));
      p.hidden = !open;
      if (open) tone(SCALE[i % 5] * (i < 5 ? 1 : 2), 0.8, 0.06);
    });
    li.appendChild(b);
    li.appendChild(p);
    list.appendChild(li);
  });

  /* ── Back to top ── */
  var top = $('#back-to-top');
  window.addEventListener('scroll', function () { top.classList.toggle('show', window.scrollY > 600); }, { passive: true });
  top.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' }); });
})();
