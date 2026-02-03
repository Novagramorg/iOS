(function() {
    'use strict';

    if (window.__pwaShimInstalled) return;
    window.__pwaShimInstalled = true;

    const registrations = new Map();

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

    // Get origin from current page URL
    function getCurrentOrigin() {
        return location.origin;
    }

    // Callback system for async cache operations
    window.__cacheCallbacks = window.__cacheCallbacks || {};

    window.resolveCacheCallback = function(callbackId, response) {
        if (window.__cacheCallbacks && window.__cacheCallbacks[callbackId]) {
            window.__cacheCallbacks[callbackId](response);
        }
    };

    // Cache API shim for page context
    class CacheShim {
        constructor(name, origin) {
            this.name = name;
            this.origin = origin;
        }

        async match(request) {
            const url = this._normalizeUrl(request);
            return new Promise((resolve) => {
                const callbackId = 'cache_' + Date.now() + '_' + Math.random();

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve(undefined);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (response) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    if (response) {
                        resolve(new Response(
                            Uint8Array.from(atob(response.bodyBase64), c => c.charCodeAt(0)),
                            {
                                status: response.status,
                                statusText: response.statusText,
                                headers: response.headers
                            }
                        ));
                    } else {
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
            return new Promise((resolve) => {
                const callbackId = 'cache_keys_' + Date.now() + '_' + Math.random();

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve([]);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (urls) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
                    resolve((urls || []).map(url => new Request(url)));
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'cacheKeys',
                    callbackId: callbackId,
                    origin: this.origin,
                    cacheName: this.name
                });
            });
        }

        _normalizeUrl(request) {
            const url = typeof request === 'string' ? request : request.url;
            // Convert relative URLs to absolute
            return new URL(url, location.href).href;
        }
    }

    class CacheStorageShim {
        constructor() {
            this._caches = {};
        }

        get origin() {
            return getCurrentOrigin();
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
            return this._caches.hasOwnProperty(name);
        }

        async delete(name) {
            delete this._caches[name];
            return new Promise((resolve) => {
                const callbackId = 'caches_del_' + Date.now() + '_' + Math.random();

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

                const timeoutId = setTimeout(() => {
                    delete window.__cacheCallbacks[callbackId];
                    resolve([]);
                }, 10000);

                window.__cacheCallbacks[callbackId] = (names) => {
                    clearTimeout(timeoutId);
                    delete window.__cacheCallbacks[callbackId];
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

    // Install the caches shim
    const cachesShim = new CacheStorageShim();
    Object.defineProperty(window, 'caches', {
        value: cachesShim,
        writable: false,
        configurable: false
    });

    const mockServiceWorker = {
        state: 'activated',
        scriptURL: '',
        addEventListener: function() {},
        removeEventListener: function() {},
        postMessage: function() {}
    };

    function createMockRegistration(scope, scriptURL) {
        const scopePath = new URL(scope, location.origin).pathname;
        return {
            scope: scope,
            installing: null,
            waiting: null,
            active: Object.assign({}, mockServiceWorker, { scriptURL: scriptURL }),
            navigationPreload: {
                enable: async () => {},
                disable: async () => {},
                setHeaderValue: async () => {},
                getState: async () => ({ enabled: false, headerValue: '' })
            },
            addEventListener: function() {},
            removeEventListener: function() {},
            update: async function() { return this; },
            unregister: async function() {
                return new Promise((resolve) => {
                    const callbackId = 'unreg_' + Date.now() + '_' + Math.random();

                    const timeoutId = setTimeout(() => {
                        delete window.__registrationCallbacks[callbackId];
                        // Still remove from local map even on timeout
                        registrations.delete(scopePath);
                        resolve(true);
                    }, 10000);

                    window.__registrationCallbacks[callbackId] = (success) => {
                        clearTimeout(timeoutId);
                        registrations.delete(scopePath);
                        resolve(success);
                    };

                    webkit.messageHandlers.swBridge.postMessage({
                        type: 'unregister',
                        callbackId: callbackId,
                        scope: scopePath
                    });
                });
            },
            showNotification: async function() {},
            getNotifications: async function() { return []; }
        };
    }

    // Pending registration callbacks
    window.__registrationCallbacks = window.__registrationCallbacks || {};

    window.resolveRegistrationCallback = function(callbackId, success, error) {
        if (window.__registrationCallbacks && window.__registrationCallbacks[callbackId]) {
            window.__registrationCallbacks[callbackId](success, error);
            delete window.__registrationCallbacks[callbackId];
        }
    };

    // State update handler - native sends this when SW state changes
    window.updateSWState = function(scope, state) {
        const registration = registrations.get(scope);
        if (registration) {
            if (state === 'installing') {
                registration.installing = Object.assign({}, mockServiceWorker, { scriptURL: registration.active?.scriptURL || '' });
                registration.active = null;
            } else if (state === 'installed') {
                registration.waiting = registration.installing;
                registration.installing = null;
            } else if (state === 'activated') {
                registration.active = registration.waiting || registration.installing;
                registration.installing = null;
                registration.waiting = null;
            }
        }
    };

    navigator.serviceWorker = {
        register: async function(scriptURL, options) {
            // Resolve script URL to absolute
            const absoluteScriptURL = new URL(scriptURL, location.href).href;

            // Resolve scope - store as absolute URL for correct matching
            let scopeURL;
            if (options?.scope) {
                scopeURL = new URL(options.scope, location.href).href;
            } else {
                // Default: directory of the SW script
                const scriptPath = new URL(absoluteScriptURL).pathname;
                const scopePath = scriptPath.substring(0, scriptPath.lastIndexOf('/') + 1);
                scopeURL = new URL(scopePath, location.origin).href;
            }

            const scopePath = new URL(scopeURL).pathname;

            return new Promise((resolve, reject) => {
                const callbackId = 'reg_' + Date.now() + '_' + Math.random();

                const timeoutId = setTimeout(() => {
                    delete window.__registrationCallbacks[callbackId];
                    reject(new TypeError('Service worker registration timed out'));
                }, 30000);

                window.__registrationCallbacks[callbackId] = (success, error) => {
                    clearTimeout(timeoutId);
                    if (success) {
                        const registration = createMockRegistration(scopeURL, absoluteScriptURL);
                        // Start with installing state
                        registration.installing = Object.assign({}, mockServiceWorker, { scriptURL: absoluteScriptURL });
                        registration.active = null;
                        registrations.set(scopePath, registration);
                        resolve(registration);
                    } else {
                        reject(new TypeError(error || 'Service worker registration failed'));
                    }
                };

                webkit.messageHandlers.swBridge.postMessage({
                    type: 'register',
                    callbackId: callbackId,
                    scriptURL: absoluteScriptURL,
                    scope: scopePath
                });
            });
        },

        getRegistration: async function(scope) {
            if (!scope) {
                // No scope provided - return registration matching current page
                const pageURL = new URL(location.href);
                for (const [regScope, reg] of registrations) {
                    // Check if current page is within this scope
                    if (pageURL.pathname.startsWith(new URL(reg.scope).pathname)) {
                        return reg;
                    }
                }
                return undefined;
            }

            // Normalize scope to absolute URL for lookup
            let normalizedScope;
            try {
                normalizedScope = new URL(scope, location.href).pathname;
            } catch (e) {
                normalizedScope = scope;
            }

            // Try direct match first, then path match
            if (registrations.has(normalizedScope)) {
                return registrations.get(normalizedScope);
            }

            // Try matching as full URL
            for (const [regScope, reg] of registrations) {
                if (reg.scope === scope || new URL(reg.scope).pathname === normalizedScope) {
                    return reg;
                }
            }

            return undefined;
        },

        getRegistrations: async function() {
            return Array.from(registrations.values());
        },

        get ready() {
            return new Promise((resolve) => {
                const check = () => {
                    // Find a registration with an active worker
                    for (const reg of registrations.values()) {
                        if (reg.active) {
                            resolve(reg);
                            return;
                        }
                    }
                    setTimeout(check, 50);
                };
                setTimeout(check, 100);
            });
        },

        get controller() {
            // Controller should only be non-null if there's an active SW that controls this page
            for (const reg of registrations.values()) {
                if (reg.active) {
                    return reg.active;
                }
            }
            return null;
        },

        addEventListener: function() {},
        removeEventListener: function() {}
    };

    Object.defineProperty(navigator, 'serviceWorker', {
        value: navigator.serviceWorker,
        writable: false,
        configurable: false
    });

    // Note: No custom fetch override needed - NSURLProtocol handles all requests
})();
