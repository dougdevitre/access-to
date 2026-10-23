/**
 * Private project cards carry exactly one status label.
 *
 * A private listed repo used to show two or three at once: a "Beta" tag, a
 * "Coming soon" placeholder link and an "In development" status, which read
 * as contradictory. The rule now: private + beta shows "Private beta" with a
 * short invite-only line; any other private status shows "Coming soon". The
 * repo link stays replaced by "source opening soon". The homepage door, the
 * embedded data and the detail-sheet note follow the same rule.
 */
const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const repos = JSON.parse(read('.github/config/repos.json'));
const listed = repos.repos.filter((r) => r.role !== 'hub' && (r.listed ?? true));
const priv = listed.filter((r) => r.visibility === 'private');
const privBeta = priv.filter((r) => r.status === 'beta');
const privOther = priv.filter((r) => r.status !== 'beta');

// Every wording that states where a project stands.
const STATUS_WORDS = ['Coming soon', 'Private beta', 'In beta', 'Beta', 'In development'];
const expected = (r) => (r.status === 'beta' ? 'Private beta' : 'Coming soon');

const about = cheerio.load(read('about.html'));
const home = cheerio.load(read('index.html'));
const data = JSON.parse(home('#app-data').text());

function cardFor(r) {
  const title = r.title || `Access to ${r.pillar[0].toUpperCase()}${r.pillar.slice(1)}`;
  const cards = about('#pillars .pillar-card').filter((_, el) => about(el).find('h2').text() === title);
  expect(cards.length).toBe(1);
  return cards.first();
}

function statusLabels(card) {
  return card
    .find('.tag, .pillar-link, .pillar-status')
    .map((_, el) => about(el).text().trim())
    .get()
    .filter((t) => STATUS_WORDS.includes(t));
}

describe('private project cards', () => {
  test('the registry has a private beta and a private non-beta project to check', () => {
    expect(privBeta.length).toBeGreaterThan(0);
    expect(privOther.length).toBeGreaterThan(0);
  });

  describe.each(priv.map((r) => [r.name, r]))('%s', (_, r) => {
    const card = cardFor(r);

    test(`shows exactly one status label: "${expected(r)}"`, () => {
      expect(statusLabels(card)).toEqual([expected(r)]);
    });

    test('says "source opening soon" and has no repo link', () => {
      expect(card.find('.repo-private').text()).toContain('source opening soon');
      expect(card.find(`a[href*="github.com/${repos.owner}/${r.name}"]`).length).toBe(0);
    });

    test(r.status === 'beta' ? 'adds an invite-only line' : 'has no invite-only line', () => {
      const note = card.find('.pillar-note').text();
      if (r.status === 'beta') expect(note).toMatch(/invite-only/i);
      else expect(note).toBe('');
    });

    test('homepage door shows the same single label', () => {
      expect(home(`a.door[data-id="${r.name}"] .door-status`).text()).toBe(expected(r));
    });

    test('detail sheet: status and note do not repeat a label', () => {
      const p = data.projects.find((x) => x.id === r.name);
      expect(p.status).toBe(expected(r));
      expect(p.note).toBeTruthy();
      STATUS_WORDS.forEach((w) => expect(p.note).not.toContain(w));
    });
  });
});

/**
 * README.md is generated from the same registry, so it follows the same rule:
 * a private beta reads "Private beta" with an invite-only note, any other
 * private status reads "Coming soon". It used to say "coming soon" for every
 * private repo, including the private betas.
 */
describe('README private project labels', () => {
  const readme = read('README.md');
  const lines = readme.split('\n');
  const titleOf = (r) => r.title || `Access to ${r.pillar[0].toUpperCase()}${r.pillar.slice(1)}`;
  const note = (r) => (r.status === 'beta' ? 'private beta, invite-only' : 'coming soon');

  describe.each(priv.map((r) => [r.name, r]))('%s', (_, r) => {
    test(`diagram node says "${note(r)}"`, () => {
      const node = lines.filter((l) => l.includes(`<b>${r.name}</b>`));
      expect(node).toHaveLength(1);
      expect(node[0]).toContain(`<i>${note(r)}</i>`);
    });

    test(`pillars row says "${note(r)}"`, () => {
      const row = lines.find((l) => l.startsWith('| **') && l.includes(`${titleOf(r)} _(`));
      expect(row).toBeDefined();
      expect(row).toContain(`${titleOf(r)} _(${note(r)})_`);
    });

    test(`directory badge is "${expected(r)}"${r.status === 'beta' ? ' with an invite-only note' : ''}`, () => {
      const row = lines.find((l) => l.startsWith(`| ${r.name} |`));
      expect(row).toBeDefined();
      const badges = [...row.matchAll(/!\[([^\]]+)\]\(https:\/\/img\.shields\.io/g)].map((m) => m[1]);
      expect(badges).toEqual([expected(r)]);
      if (r.status === 'beta') expect(row).toMatch(/invite-only/i);
      else expect(row).not.toMatch(/invite-only/i);
    });
  });
});
