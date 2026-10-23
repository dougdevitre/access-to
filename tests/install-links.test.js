/**
 * "Install in Claude" links.
 *
 * Each skill repo publishes a claude.ai install zip on a release tagged
 * skill-latest; repos.json names it in `install_zip` (an asset filename or a
 * full https URL). render-hub.sh turns that into a link on the project's card
 * in about.html and into `install` in the homepage data, which app.js shows
 * in the detail sheet. Private repos never get one: their downloads only work
 * for signed-in collaborators.
 */
const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

const ROOT = path.join(__dirname, '..');
const read = (f) => fs.readFileSync(path.join(ROOT, f), 'utf-8');
const registry = JSON.parse(read('.github/config/repos.json'));
const listed = registry.repos.filter((r) => r.role !== 'hub' && r.listed !== false);
const isPublic = (r) => (r.visibility || 'public') === 'public';
const withZip = listed.filter((r) => r.install_zip);
const withoutZip = listed.filter((r) => !r.install_zip);

const zipUrl = (r) => (r.install_zip.startsWith('https://')
  ? r.install_zip
  : `https://github.com/${registry.owner}/${r.name}/releases/download/skill-latest/${r.install_zip}`);
const title = (r) => r.title || `Access to ${r.pillar[0].toUpperCase()}${r.pillar.slice(1)}`;

const about = cheerio.load(read('about.html'));
const home = cheerio.load(read('index.html'));
const data = JSON.parse(home('#app-data').text());
const card = (r) => about(`#pillars .pillar-card`).filter((_, el) => about(el).find('h2').text() === title(r));

/** The declarations of the first rule whose selector list contains `selector`. */
function ruleBody(css, selector) {
  const esc = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const m = css.match(new RegExp(`(?:^|[}\\s,])${esc}\\s*(?:,[^{]*)?\\{([^}]*)\\}`, 'm'));
  return m ? m[1] : '';
}

describe('Install in Claude', () => {
  test('the registry names at least one install file (so the checks below are not vacuous)', () => {
    expect(withZip.length).toBeGreaterThan(0);
  });

  test('only public repos have install_zip', () => {
    withZip.forEach((r) => expect(isPublic(r)).toBe(true));
  });

  describe('project cards (about.html)', () => {
    test.each(withZip.map((r) => [r.name, r]))('%s card links to its install zip', (_, r) => {
      const c = card(r);
      expect(c.length).toBe(1);
      const a = c.find('a.install-link');
      expect(a.length).toBe(1);
      expect(a.attr('href')).toBe(zipUrl(r));
      expect(a.text().trim()).toBe('Install in Claude');
    });

    test.each(withZip.map((r) => [r.name, r]))('%s install link is accessible', (_, r) => {
      const a = card(r).find('a.install-link');
      const label = a.attr('aria-label') || '';
      // Label-in-name: the accessible name starts with the visible text and names the skill.
      expect(label.startsWith('Install in Claude')).toBe(true);
      expect(label).toContain(title(r));
      // Keyboard-reachable: a real link that is not taken out of the tab order.
      expect(a.attr('tabindex')).toBeUndefined();
      // The how-to line is tied to the link.
      const help = about(`#${a.attr('aria-describedby')}`);
      expect(help.length).toBe(1);
      expect(help.text()).toContain('Download, don’t unzip, then Claude → Customize → Skills → + → Upload a skill');
      expect(help.find('a[href="https://support.claude.com/en/articles/12512180-use-skills-in-claude"]').attr('rel')).toContain('noopener');
    });

    test.each(withoutZip.map((r) => [r.name, r]))('%s card (no install_zip) has no install link', (_, r) => {
      expect(card(r).find('.install, a.install-link').length).toBe(0);
    });

    test('no page links to a private repo’s release download', () => {
      const html = read('about.html') + read('index.html');
      listed.filter((r) => !isPublic(r)).forEach((r) => {
        expect(html).not.toContain(`github.com/${registry.owner}/${r.name}/releases`);
      });
    });
  });

  describe('homepage detail sheet (index.html + app.js)', () => {
    test('embedded data carries install for exactly the projects with install_zip', () => {
      listed.forEach((r) => {
        const p = data.projects.find((x) => x.id === r.name);
        expect(p.install).toBe(r.install_zip ? zipUrl(r) : null);
      });
    });

    test('app.js renders the install link with a label naming the skill and the how-to line', () => {
      const js = read('app.js');
      expect(js).toMatch(/if \(p\.install\)/);
      expect(js).toContain("'Install in Claude: ' + p.title");
      expect(js).toContain('Upload a skill');
    });
  });

  describe('styles match the cards in light and dark mode', () => {
    const css = read('styles.css');
    const link = ruleBody(css, '.install .install-link');

    test('the link is a 44px touch target', () => {
      expect(link).toMatch(/min-height:\s*44px/);
    });

    test('text uses theme tokens, so contrast holds in dark mode', () => {
      expect(link).toContain('color: var(--color-text)');
      expect(link).toContain('background: var(--color-bg)');
      expect(ruleBody(css, '.install .install-help')).toContain('color: var(--color-muted)');
    });
  });
});
