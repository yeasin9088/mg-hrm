/** A deterministic GitHub Pages HTML overlay, leaving the 1.6 MB legacy SPA source untouched. */
function insertBeforeLast(html, closingTag, markup) {
  const pattern = closingTag === 'head' ? /<\/head\s*>/gi : /<\/body\s*>/gi;
  const matches = [...html.matchAll(pattern)];
  if (!matches.length) throw new Error('Cannot install PWA App Center: missing </' + closingTag + '>');
  const index = matches[matches.length - 1].index;
  return html.slice(0, index) + markup + '\n' + html.slice(index);
}
export function injectPwaEnhancements(html) {
  if (typeof html !== 'string') throw new TypeError('Expected HTML source');
  let output = html;
  if (!/pwa-experience\.css/i.test(output)) {
    output = insertBeforeLast(output, 'head', '  <link rel="stylesheet" href="./pwa-experience.css">');
  }
  if (!/pwa-experience\.js/i.test(output)) {
    output = insertBeforeLast(output, 'body', '  <script defer src="./pwa-experience.js"></script>');
  }
  return output;
}
