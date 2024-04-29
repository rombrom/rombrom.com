import markdownIt from 'markdown-it';
import markdownItAnchor from 'markdown-it-anchor';
import Shiki from '@shikijs/markdown-it';

const markdown = markdownIt({
  html: true,
  linkify: true,
  typographer: true,
})
  .use(markdownItAnchor)
  .use(
    await Shiki({ theme: 'houston' })
  );

const footnoteCache = new Map();

export default function configure(config) {
  config.setLibrary('md', markdown);

  config.addGlobalData('date', 'git Created');
  config.addGlobalData('layout', 'base');

  config.addPassthroughCopy({
    'src/public': '.',
    'src/style.css': 'style.css',
  });

  config.addFilter('prettyDate', (dateStr) => {
    const date = new Date(dateStr);
    return date.toDateString();
  });

  config.addPairedShortcode('footnote', function (content) {
    if (!footnoteCache.has(this.page)) footnoteCache.set(this.page, []);
    const footnotes = footnoteCache.get(this.page);
    const index1 = footnotes.push(markdown.renderInline(content));
    this.page.footnotes = footnotes;
    return `<sup class="footnote"><a id="notesrc${index1}" href="#note${index1}">${index1}</a></sup>`;
  });

  config.addFilter('json', (input) => JSON.stringify(input));
}
