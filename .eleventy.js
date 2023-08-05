module.exports = function configure(eleventyConfig) {
  eleventyConfig.addGlobalData('layout', 'base');
  eleventyConfig.addPassthroughCopy({ 'src/style.css': 'style.css' });
  eleventyConfig.addFilter('prettyDate', (dateStr) => {
    const date = new Date(dateStr);
    return date.toDateString();
  });
};
