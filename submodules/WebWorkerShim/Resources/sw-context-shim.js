(function() {
    'use strict';

    const eventHandlers = {
        install: [],
        activate: [],
        fetch: []
    };

    // Helper function for base64 encoding large binary data without stack overflow
    function arrayBufferToBase64(buffer) {
        const bytes = new Uint8Array(buffer);
        const chunkSize = 8192;
        let binary = '';
        for (let i = 0; i < bytes.length; i += chunkSize) {
            const chunk = bytes.subarray(i, i + chunkSize);
            binary += String.fromCharCode.apply(null, chunk);
        }
        return btoa(binary);
    }

    // ServiceWorkerGlobalScope shim
    const swSelf = {
        addEventListener: function(event, handler) {
            if (eventHandlers[event]) {
                eventHandlers[event].push(handler);
            }
        },

        removeEventListener: function(event, handler) {
            if (eventHandlers[event]) {
                const idx = eventHandlers[event].indexOf(handler);
                if (idx !== -1) eventHandlers[event].splice(idx, 1);
            }
        },

        skipWaiting: function() {
            return Promise.resolve();
        },

        clients: {
            claim: function() { return Promise.resolve(); },
            get: function() { return Promise.resolve(null); },
            matchAll: function() { return Promise.resolve([]); },
            openWindow: function() { return Promise.resolve(null); }
        },

        registration: {
            scope: '/',
            navigationPreload: {
                enable: async () => {},
                disable: async () => {},
                setHeaderValue: async () => {}
            }
        }
    };

    // Expose as self
    Object.assign(self, swSelf);

    // Will be set when SW script is loaded
    window.__swOrigin = '';
    window.__swScriptURL = '';

    // importScripts shim - synchronous script loading is not possible in WebView,
    // but we can provide an async polyfill that warns developers
    self.importScripts = function(...urls) {
        console.warn('[SW] importScripts called but synchronous script loading is not supported in this polyfill. Scripts:', urls);
        // This is a limitation - real importScripts is synchronous
        // We could potentially pre-load scripts during SW registration
        throw new Error('importScripts is not supported in this service worker polyfill');
    };

    // Resolve a URL relative to the SW script location
    function resolveRelativeURL(url) {
        if (!url) return url;

        // Already absolute
        if (url.startsWith('http://') || url.startsWith('https://')) {
            return url;
        }

        // Use standard URL resolution with script URL as base
        if (window.__swScriptURL) {
            try {
                return new URL(url, window.__swScriptURL).href;
            } catch (e) {
                console.error('[SW] Failed to resolve URL:', url, e);
            }
        }

        // Fallback: prepend origin
        if (url.startsWith('/')) {
            return window.__swOrigin + url;
        }
        return window.__swOrigin + '/' + url;
    }

    // Cache API bridge
    class CacheShim {
        constructor(name, origin) {
            this.name = name;
            this.origin = origin;
        }

        _normalizeUrl(request) {
            const url = typeof request === 'string' ? request : request.url;
            return resolveRelativeURL(url);
        }

        async match(request) {
            const url = this._normalizeUrl(request);
            console.log('[SW Cache] match:', url, 'in cache:', this.name);
            return new Promise((resolve) => {
                const callbackId = 'cache_' + Date.now() + '_' + Math.random();
                window.__cacheCallbacks = window.__cacheCallbacks || {};

                const timeoutId = setTimeout(() => {
                    console.log('[SW Cache] match timeout for:', url);
                    delete window.__cacheCallbacks[callbackId];
                    resolve(undefined);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (response) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    if (response) {
                        console.log('[SW Cache] match HIT:', url);
                        resolve(new Response(
                            Uint8Array.from(atob(response.bodyBase64), c => c.charCodeAt(0)),
                            {
                                status: response.status,
                                statusText: response.statusText,
                                headers: response.headers
                            }
                        ));
                    } else {
                        console.log('[SW Cache] match MISS:', url);
                        resolve(undefined);
                    }
                };
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cacheMatch',
                    callbackId: callbackId,
                    origin: this.origin,
                    cacheName: this.name,
                    url: url
                });
            });
        }

        async put(request, response) {
            const url = this._normalizeUrl(request);
            const clonedResponse = response.clone();
            const body = await clonedResponse.arrayBuffer();
            const bodyBase64 = arrayBufferToBase64(body);

            const headers = {};
            clonedResponse.headers.forEach((value, key) => {
                headers[key] = value;
            });

            webkit.messageHandlers.swBridge.postMessage({
                type: 'cachePut',
                origin: this.origin,
                cacheName: this.name,
                url: url,
                response: {
                    status: clonedResponse.status,
                    statusText: clonedResponse.statusText,
                    headers: headers,
                    bodyBase64: bodyBase64
                }
            });
        }

        async add(request) {
            const url = this._normalizeUrl(request);
            const response = await fetch(url);
            if (!response.ok) {
                throw new TypeError('Bad response status');
            }
            return this.put(url, response);
        }

        async addAll(requests) {
            const urls = requests.map(r => this._normalizeUrl(r));
            await Promise.all(urls.map(url => this.add(url)));
        }

        async delete(request) {
            const url = this._normalizeUrl(request);
            return new Promise((resolve) => {
                const callbackId = 'cache_del_' + Date.now() + '_' + Math.random();
                window.__cacheCallbacks = window.__cacheCallbacks || {};

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve(false);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (result) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    resolve(result);
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cacheEntryDelete',
                    callbackId: callbackId,
                    origin: this.origin,
                    cacheName: this.name,
                    url: url
                });
            });
        }

        async keys() {
            return [];  // Simplified for now
        }
    }

    class CacheStorageShim {
        constructor(origin) {
            this.origin = origin;
            this._caches = {};
        }

        async open(name) {
            if (!this._caches[name]) {
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cacheOpen',
                    origin: this.origin,
                    cacheName: name
                });
                this._caches[name] = new CacheShim(name, this.origin);
            }
            return this._caches[name];
        }

        async has(name) {
            const keys = await this.keys();
            return keys.includes(name);
        }

        async delete(name) {
            delete this._caches[name];
            return new Promise((resolve) => {
                const callbackId = 'caches_del_' + Date.now() + '_' + Math.random();
                window.__cacheCallbacks = window.__cacheCallbacks || {};

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve(false);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (result) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    resolve(result);
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cacheStorageDelete',
                    callbackId: callbackId,
                    origin: this.origin,
                    cacheName: name
                });
            });
        }

        async keys() {
            return new Promise((resolve) => {
                const callbackId = 'caches_keys_' + Date.now() + '_' + Math.random();
                window.__cacheCallbacks = window.__cacheCallbacks || {};

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve(Object.keys(this._caches));  // Fall back to local
                }, 10000);

                window.__cacheCallbacks[callbackId] = (names) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    // Sync local cache map with actual stored caches
                    (names || []).forEach(n => {
                        if (!this._caches[n]) {
                            this._caches[n] = new CacheShim(n, this.origin);
                        }
                    });
                    resolve(names || []);
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cachesKeys',
                    callbackId: callbackId,
                    origin: this.origin
                });
            });
        }

        async match(request) {
            const url = typeof request === 'string' ? request : request.url;
            for (const cache of Object.values(this._caches)) {
                const response = await cache.match(url);
                if (response) return response;
            }
            return undefined;
        }
    }

    Object.defineProperty(self, 'caches', {
        get: function() {
            if (!window.__cachesInstance) {
                window.__cachesInstance = new CacheStorageShim(window.__swOrigin);
            }
            return window.__cachesInstance;
        }
    });

    // FetchEvent shim
    class FetchEvent {
        constructor(request, requestId) {
            this.request = request;
            this.requestId = requestId;
            this._responded = false;
            this._responseSent = false;  // Tracks if response actually sent to native
            this._waitUntilPromises = [];
        }

        respondWith(responsePromise) {
            this._responded = true;
            console.log('[SW] respondWith called for:', this.request.url);
            Promise.resolve(responsePromise).then(async (response) => {
                // Prevent double-response
                if (this._responseSent) {
                    console.log('[SW] Response already sent, ignoring duplicate');
                    return;
                }
                this._responseSent = true;

                console.log('[SW] Response received:', response.status, response.url || 'synthetic');
                const cloned = response.clone();
                const body = await cloned.arrayBuffer();
                const bodyBase64 = arrayBufferToBase64(body);

                const headers = {};
                cloned.headers.forEach((value, key) => {
                    headers[key] = value;
                });

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'fetchResponse',
                    requestId: this.requestId,
                    response: {
                        status: cloned.status,
                        statusText: cloned.statusText,
                        headers: headers,
                        bodyBase64: bodyBase64
                    }
                });
            }).catch((error) => {
                // Prevent double-response
                if (this._responseSent) {
                    console.log('[SW] Response already sent, ignoring error');
                    return;
                }
                this._responseSent = true;

                console.log('[SW] respondWith error:', error.message);
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'fetchResponse',
                    requestId: this.requestId,
                    error: error.message
                });
            });
        }

        waitUntil(promise) {
            this._waitUntilPromises.push(promise);
        }
    }

    // ExtendableEvent shim
    class ExtendableEvent {
        constructor(type) {
            this.type = type;
            this._waitUntilPromises = [];
        }

        waitUntil(promise) {
            this._waitUntilPromises.push(promise);
        }
    }

    // Global dispatch functions called from Swift
    window.dispatchFetchEvent = function(requestId, url, method, headers, bodyBase64, options) {
        console.log('[SW] dispatchFetchEvent:', url, 'method:', method);

        // Build request init
        const init = {
            method: method,
            headers: headers
        };

        // Add body for methods that support it (not GET/HEAD)
        if (bodyBase64 && method !== 'GET' && method !== 'HEAD') {
            const bodyBytes = Uint8Array.from(atob(bodyBase64), c => c.charCodeAt(0));
            init.body = bodyBytes;
        }

        // Add request options if provided
        if (options) {
            if (options.credentials) init.credentials = options.credentials;
            if (options.mode) init.mode = options.mode;
            if (options.redirect) init.redirect = options.redirect;
            if (options.cache) init.cache = options.cache;
        }

        const request = new Request(url, init);
        const event = new FetchEvent(request, requestId);

        for (const handler of eventHandlers.fetch) {
            handler(event);
        }

        // If no handler called respondWith, tell Swift to pass through to network
        // Use a longer timeout (50ms) to allow for async handlers like:
        //   event.respondWith((async () => { ... })())
        // Also check _responseSent to prevent double-sends
        setTimeout(() => {
            if (!event._responded && !event._responseSent) {
                event._responseSent = true;
                console.log('[SW] No handler responded for:', url);
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'fetchResponse',
                    requestId: requestId,
                    passthrough: true
                });
            }
        }, 50);
    };

    window.dispatchInstallEvent = function() {
        return new Promise((resolve) => {
            const event = new ExtendableEvent('install');
            for (const handler of eventHandlers.install) {
                handler(event);
            }
            Promise.all(event._waitUntilPromises).then(() => resolve(true)).catch(() => resolve(false));
        });
    };

    window.dispatchActivateEvent = function() {
        return new Promise((resolve) => {
            const event = new ExtendableEvent('activate');
            for (const handler of eventHandlers.activate) {
                handler(event);
            }
            Promise.all(event._waitUntilPromises).then(() => resolve(true)).catch(() => resolve(false));
        });
    };

    window.setOrigin = function(origin, scriptURL) {
        window.__swOrigin = origin;
        window.__swScriptURL = scriptURL || '';

        // Set up self.location to reflect the SW script URL
        if (scriptURL) {
            try {
                const url = new URL(scriptURL);
                const locationShim = {
                    href: scriptURL,
                    origin: url.origin,
                    protocol: url.protocol,
                    host: url.host,
                    hostname: url.hostname,
                    port: url.port,
                    pathname: url.pathname,
                    search: url.search,
                    hash: url.hash,
                    toString: function() { return scriptURL; }
                };
                // Override self.location (it's about:blank by default)
                Object.defineProperty(self, 'location', {
                    value: locationShim,
                    writable: false,
                    configurable: true
                });
            } catch (e) {
                console.error('[SW] Failed to set location:', e);
            }
        }
    };

    // Override fetch to route requests through native handler
    // This is needed because the SW context WebView can't make real network requests
    window.__fetchCallbacks = window.__fetchCallbacks || {};

    window.resolveSWFetchCallback = function(requestId, response, error) {
        if (window.__fetchCallbacks && window.__fetchCallbacks[requestId]) {
            window.__fetchCallbacks[requestId](response, error);
            delete window.__fetchCallbacks[requestId];
        }
    };

    const originalFetch = window.fetch;
    window.fetch = function(input, init) {
        let url;
        let method = 'GET';
        let headers = {};

        if (typeof input === 'string') {
            url = input;
        } else if (input instanceof Request) {
            url = input.url;
            method = input.method;
            input.headers.forEach((value, key) => { headers[key] = value; });
        } else if (input instanceof URL) {
            url = input.href;
        } else {
            return originalFetch.call(window, input, init);
        }

        if (init) {
            method = init.method || method;
            if (init.headers) {
                if (init.headers instanceof Headers) {
                    init.headers.forEach((value, key) => { headers[key] = value; });
                } else {
                    Object.assign(headers, init.headers);
                }
            }
        }

        // Resolve relative URLs
        url = resolveRelativeURL(url);

        // Helper to send the request to native
        function sendRequest(bodyBase64) {
            return new Promise((resolve, reject) => {
                const requestId = 'swfetch_' + Date.now() + '_' + Math.random();

                const timeoutId = setTimeout(() => {
                    delete window.__fetchCallbacks[requestId];
                    reject(new TypeError('Network request failed (timeout)'));
                }, 30000);

                window.__fetchCallbacks[requestId] = (response, error) => {
                    clearTimeout(timeoutId);
                    if (error) {
                        reject(new TypeError(error));
                    } else if (response) {
                        const bodyData = response.bodyBase64
                            ? Uint8Array.from(atob(response.bodyBase64), c => c.charCodeAt(0))
                            : new Uint8Array(0);
                        resolve(new Response(bodyData, {
                            status: response.status || 200,
                            statusText: response.statusText || 'OK',
                            headers: response.headers || {}
                        }));
                    } else {
                        reject(new TypeError('Network request failed'));
                    }
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'swFetch',
                    requestId: requestId,
                    url: url,
                    method: method,
                    headers: headers,
                    bodyBase64: bodyBase64,
                    origin: window.__swOrigin
                });
            });
        }

        // For GET/HEAD, no body allowed
        if (method === 'GET' || method === 'HEAD') {
            return sendRequest(null);
        }

        // Handle body from init
        if (init && init.body !== undefined && init.body !== null) {
            const body = init.body;
            if (typeof body === 'string') {
                return sendRequest(arrayBufferToBase64(new TextEncoder().encode(body).buffer));
            } else if (body instanceof ArrayBuffer) {
                return sendRequest(arrayBufferToBase64(body));
            } else if (ArrayBuffer.isView(body)) {
                return sendRequest(arrayBufferToBase64(body.buffer));
            } else if (body instanceof URLSearchParams) {
                return sendRequest(arrayBufferToBase64(new TextEncoder().encode(body.toString()).buffer));
            } else if (body instanceof Blob) {
                return body.arrayBuffer().then(ab => sendRequest(arrayBufferToBase64(ab)));
            }
        }

        // Handle body from Request object
        if (input instanceof Request && input.body) {
            return input.clone().arrayBuffer()
                .then(ab => sendRequest(arrayBufferToBase64(ab)))
                .catch(() => sendRequest(null));
        }

        // No body
        return sendRequest(null);
    };

    window.resolveCacheCallback = function(callbackId, response) {
        if (window.__cacheCallbacks && window.__cacheCallbacks[callbackId]) {
            window.__cacheCallbacks[callbackId](response);
        }
    };

    // Signal ready
    webkit.messageHandlers.swBridge.postMessage({ type: 'contextReady' });
})();
