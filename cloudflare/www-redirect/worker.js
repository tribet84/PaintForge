/**
 * Sends www.pintaminis.com to the apex.
 *
 * Serving the same pages on both hostnames splits the site in two as far as
 * search engines are concerned and gives every link two valid forms. One
 * canonical host, and www becomes a doorway rather than a duplicate.
 *
 * A 301 rather than a 302: this is permanent, and browsers and crawlers
 * should stop asking.
 */
export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = 'pintaminis.com';
    // Path and query ride along, so a bookmarked www.pintaminis.com/privacy
    // still lands on the policy rather than the front page.
    return Response.redirect(url.toString(), 301);
  },
};
