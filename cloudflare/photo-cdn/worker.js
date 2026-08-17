/**
 * Edge cache for recipe cover photos.
 *
 * Photos are served by Firebase Storage, which is a separate host and so
 * never passes through this zone's proxy — every view is an egress charge,
 * and photo egress is the one metric with a real ceiling on the free tier.
 * This Worker fronts that host on img.pintaminis.com so the edge answers
 * repeat views instead.
 *
 * It is a pure pass-through: the path and query string reach Storage exactly
 * as they arrived, including the access token that authorizes the download.
 * The Worker therefore cannot widen access to anything the original URL did
 * not already grant, and Storage stays the only thing deciding who may read
 * an object.
 */

/** Only this bucket is proxied — the Worker is not an open relay. */
const BUCKET = 'paintforge-d8cf2.firebasestorage.app';
const STORAGE_ORIGIN = 'https://firebasestorage.googleapis.com';

/** Uploads already set this; repeated here for objects that predate it. */
const CACHE_CONTROL = 'public, max-age=31536000, immutable';

export default {
  async fetch(request) {
    // Photos are read-only. Anything else is a bug or a probe, and a cache
    // has no business forwarding it.
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', {
        status: 405,
        headers: { Allow: 'GET, HEAD' },
      });
    }

    const url = new URL(request.url);
    const prefix = `/v0/b/${BUCKET}/o/`;
    if (!url.pathname.startsWith(prefix)) {
      return new Response('Not found', { status: 404 });
    }

    const originUrl = `${STORAGE_ORIGIN}${url.pathname}${url.search}`;
    const response = await fetch(originUrl, {
      method: request.method,
      // cacheEverything is what actually makes this worth deploying: the
      // download URL carries a query string, which the default cache rules
      // treat as uncacheable.
      cf: { cacheEverything: true, cacheTtl: 31536000 },
    });

    // A denied or missing object must not be cached as if it were a photo —
    // a rotated token would otherwise keep serving from the edge.
    if (!response.ok) {
      return new Response(response.statusText, {
        status: response.status,
        headers: { 'Cache-Control': 'no-store' },
      });
    }

    const headers = new Headers(response.headers);
    headers.set('Cache-Control', CACHE_CONTROL);
    // The app fetches these cross-origin from pintaminis.com.
    headers.set('Access-Control-Allow-Origin', '*');

    return new Response(response.body, {
      status: response.status,
      headers,
    });
  },
};
