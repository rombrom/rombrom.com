import markdownIt from "markdown-it";
import markdownItAnchor from "markdown-it-anchor";
import Shiki from "@shikijs/markdown-it";
import {
  transformerNotationDiff,
  transformerNotationHighlight,
} from "@shikijs/transformers";
import markdownItAbbr from "markdown-it-abbr";
import markdownItFootnotes from "markdown-it-footnote";

const markdown = markdownIt({
  html: true,
  linkify: true,
  typographer: true,
})
  .use(markdownItAbbr)
  .use(markdownItAnchor)
  .use(markdownItFootnotes)
  .use(
    await Shiki({
      theme: "houston",
      transformers: [transformerNotationDiff(), transformerNotationHighlight()],
    }),
  );

export default function configure(config) {
  config.setLibrary("md", markdown);

  config.addGlobalData("date", "git Created");
  config.addGlobalData("layout", "base");
  config.addGlobalData("NODE_ENV", process.env.NODE_ENV);

  config.addPassthroughCopy({ "src/public": ".", "src/*.css": "css" });

  config.addFilter("prettyDate", (dateStr) => {
    const date = new Date(dateStr);
    return date.toDateString();
  });

  config.addFilter("json", (input) => JSON.stringify(input));
}
