//#region ../walletkit/dist/esm/errors/codes.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Error codes for WalletKit
* Range: 7000-7999
*/
var ERROR_CODES = {
	BRIDGE_NOT_INITIALIZED: 7e3,
	BRIDGE_CONNECTION_FAILED: 7001,
	BRIDGE_EVENT_PROCESSING_FAILED: 7002,
	BRIDGE_RESPONSE_SEND_FAILED: 7003,
	SESSION_NOT_FOUND: 7100,
	SESSION_ID_REQUIRED: 7101,
	SESSION_CREATION_FAILED: 7102,
	SESSION_DOMAIN_REQUIRED: 7103,
	SESSION_RESTORATION_FAILED: 7104,
	EVENT_STORE_NOT_INITIALIZED: 7200,
	EVENT_STORE_OPERATION_FAILED: 7201,
	STORAGE_READ_FAILED: 7300,
	STORAGE_WRITE_FAILED: 7301,
	WALLET_NOT_FOUND: 7400,
	WALLET_REQUIRED: 7401,
	WALLET_INVALID: 7402,
	WALLET_CREATION_FAILED: 7403,
	WALLET_INITIALIZATION_FAILED: 7404,
	LEDGER_DEVICE_ERROR: 7405,
	INVALID_REQUEST_EVENT: 7500,
	REQUEST_PROCESSING_FAILED: 7501,
	RESPONSE_CREATION_FAILED: 7502,
	APPROVAL_FAILED: 7503,
	REJECTION_FAILED: 7504,
	API_CLIENT_ERROR: 7600,
	TON_CLIENT_INITIALIZATION_FAILED: 7601,
	API_REQUEST_FAILED: 7602,
	ACCOUNT_NOT_FOUND: 7603,
	JETTONS_MANAGER_ERROR: 7700,
	NFT_MANAGER_ERROR: 7701,
	CONTRACT_DEPLOYMENT_FAILED: 7800,
	CONTRACT_EXECUTION_FAILED: 7801,
	CONTRACT_VALIDATION_FAILED: 7802,
	NETWORK_NOT_CONFIGURED: 7850,
	UNKNOWN_ERROR: 7900,
	VALIDATION_ERROR: 7901,
	INITIALIZATION_ERROR: 7902,
	CONFIGURATION_ERROR: 7903,
	NETWORK_ERROR: 7904,
	UNKNOWN_EMULATION_ERROR: 7905,
	INVALID_CONFIG: 7906
};
/**
* Get error code name by value
*/
function getErrorCodeName(code) {
	const entry = Object.entries(ERROR_CODES).find(([, value]) => value === code);
	return entry ? entry[0] : `UNKNOWN_CODE_${code}`;
}
//#endregion
//#region ../walletkit/dist/esm/errors/WalletKitError.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Generic error class for WalletKit that wraps standard Error with error codes
*/
var WalletKitError = class WalletKitError extends Error {
	code;
	codeName;
	originalError;
	context;
	constructor(code, message, originalError, context) {
		const fullMessage = originalError ? `${message}: ${originalError.message}` : message;
		super(fullMessage);
		this.name = "WalletKitError";
		this.code = code;
		this.codeName = getErrorCodeName(code);
		this.originalError = originalError;
		this.context = context;
		if (Error.captureStackTrace) Error.captureStackTrace(this, WalletKitError);
		if (originalError?.stack) this.stack = `${this.stack}\nCaused by: ${originalError.stack}`;
	}
	/**
	* Create a WalletKitError from an unknown error
	*/
	static fromError(code, message, error, context) {
		if (error instanceof Error) return new WalletKitError(code, message, error, context);
		return new WalletKitError(code, `${message}: ${error && typeof error === "object" && "message" in error ? String(error.message) : String(error)}`, void 0, {
			...context,
			originalValue: error
		});
	}
	/**
	* Check if an error is a WalletKitError with a specific code
	*/
	static isWalletKitError(error, code) {
		if (!(error instanceof WalletKitError)) return false;
		if (code !== void 0) return error.code === code;
		return true;
	}
	/**
	* Serialize error to JSON
	*/
	toJSON() {
		return {
			name: this.name,
			message: this.message,
			code: this.code,
			codeName: this.codeName,
			context: this.context,
			stack: this.stack,
			originalError: this.originalError ? {
				name: this.originalError.name,
				message: this.originalError.message,
				stack: this.originalError.stack
			} : void 0
		};
	}
};
//#endregion
//#region ../walletkit/dist/esm/utils/getDefaultWalletConfig.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Default device info for JS Bridge
*/
var DEFAULT_DEVICE_INFO = {
	platform: "browser",
	appName: "Wallet",
	appVersion: "1.0.0",
	maxProtocolVersion: 2,
	features: ["SendTransaction", {
		name: "SendTransaction",
		maxMessages: 1
	}]
};
var DEFAULT_WALLET_INFO = {
	name: "Wallet",
	appName: "Wallet",
	imageUrl: "https://example.com/image.png",
	bridgeUrl: "https://example.com/bridge.png",
	universalLink: "https://example.com/universal-link",
	aboutUrl: "https://example.com/about",
	platforms: [
		"chrome",
		"firefox",
		"safari",
		"android",
		"ios",
		"windows",
		"macos",
		"linux"
	],
	jsBridgeKey: "wallet"
};
function getDeviceInfoWithDefaults(options) {
	return addLegacySendTransactionFeature({
		...DEFAULT_DEVICE_INFO,
		...options
	});
}
function getWalletInfoWithDefaults(options) {
	return {
		...DEFAULT_WALLET_INFO,
		...options
	};
}
function addLegacySendTransactionFeature(options) {
	const features = options.features;
	const hasSendTransactionString = features.some((feature) => feature === "SendTransaction");
	const hasSendTransactionObject = features.some((feature) => typeof feature === "object" && feature.name === "SendTransaction");
	const shouldAddString = !hasSendTransactionString && hasSendTransactionObject;
	return {
		...options,
		features: shouldAddString ? ["SendTransaction", ...features] : features
	};
}
//#endregion
//#region ../walletkit/dist/esm/bridge/core/BridgeConfig.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Validates and normalizes bridge configuration
*/
function validateBridgeConfig(config) {
	if (!config.deviceInfo) throw new Error("deviceInfo is required");
	if (!config.walletInfo) throw new Error("walletInfo is required");
	if (!config.jsBridgeKey || typeof config.jsBridgeKey !== "string") throw new Error("jsBridgeKey must be a non-empty string");
	if (config.protocolVersion < 2) throw new Error("protocolVersion must be at least 2");
}
//#endregion
//#region ../walletkit/dist/esm/bridge/core/TonConnectBridge.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Core TonConnect JS Bridge implementation
* Implements the TonConnect protocol specification
* Uses dependency injection for transport layer
*/
var TonConnectBridge = class {
	deviceInfo;
	walletInfo;
	protocolVersion;
	isWalletBrowser;
	transport;
	eventListeners = [];
	constructor(config, transport) {
		this.deviceInfo = config.deviceInfo;
		this.walletInfo = config.walletInfo;
		this.protocolVersion = config.protocolVersion;
		this.isWalletBrowser = config.isWalletBrowser;
		this.transport = transport;
		this.transport.onEvent((event) => {
			this.notifyListeners(event);
		});
	}
	/**
	* Initiates connect request - forwards to transport
	*/
	async connect(protocolVersion, message) {
		if (protocolVersion < 2) throw new Error("Unsupported protocol version");
		return this.transport.send({
			method: "connect",
			params: {
				protocolVersion,
				...message
			}
		});
	}
	/**
	* Attempts to restore previous connection - forwards to transport
	*/
	async restoreConnection() {
		return this.transport.send({
			method: "restoreConnection",
			params: []
		});
	}
	/**
	* Sends a message to the bridge - forwards to transport
	*/
	async send(message) {
		return this.transport.send({
			method: "send",
			params: [message]
		});
	}
	/**
	* Registers a listener for events from the wallet
	* Returns unsubscribe function
	*/
	listen(callback) {
		if (typeof callback !== "function") throw new Error("Callback must be a function");
		this.eventListeners.push(callback);
		return () => {
			const index = this.eventListeners.indexOf(callback);
			if (index > -1) this.eventListeners.splice(index, 1);
		};
	}
	/**
	* Expose listener count for environments that need to fan-out events across frames.
	*/
	hasListeners() {
		return this.eventListeners.length > 0;
	}
	/**
	* Notify all registered listeners of an event
	*/
	notifyListeners(event) {
		this.eventListeners.forEach((callback) => {
			try {
				callback(event);
			} catch (error) {
				console.error("TonConnect event listener error:", error);
			}
		});
	}
	/**
	* Check if transport is available
	*/
	isTransportAvailable() {
		return this.transport.isAvailable();
	}
	/**
	* Cleanup resources
	*/
	destroy() {
		this.eventListeners.length = 0;
		this.transport.destroy();
	}
};
//#endregion
//#region ../walletkit/dist/esm/bridge/utils/timeouts.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Timeout constants for bridge operations
*/
/**
* Default timeout for bridge requests (300 seconds)
*/
var DEFAULT_REQUEST_TIMEOUT = 3e5;
/**
* Timeout for restoreConnection requests (10 seconds)
* Shorter because this is called frequently on page load
*/
var RESTORE_CONNECTION_TIMEOUT = 1e4;
//#endregion
//#region ../walletkit/dist/esm/bridge/injection/IframeWatcher.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Watches for iframe creation in the DOM and triggers callbacks
* Separated from bridge injection for better separation of concerns
*/
var IframeWatcher = class {
	onIframeDetected;
	observer = null;
	constructor(onIframeDetected) {
		this.onIframeDetected = onIframeDetected;
	}
	/**
	* Start watching for iframes
	*/
	start() {
		if (this.observer) return;
		this.observer = new MutationObserver((mutations) => {
			this.handleMutations(mutations);
		});
		this.observer.observe(document.body, {
			childList: true,
			subtree: true
		});
	}
	/**
	* Stop watching for iframes
	*/
	stop() {
		if (this.observer) {
			this.observer.disconnect();
			this.observer = null;
		}
	}
	/**
	* Handle DOM mutations
	*/
	handleMutations(mutations) {
		for (const mutation of mutations) {
			if (mutation.type !== "childList") continue;
			for (const node of mutation.addedNodes) this.handleAddedNode(node);
		}
	}
	/**
	* Handle a single added node
	*/
	handleAddedNode(node) {
		if (node.nodeType !== Node.ELEMENT_NODE) return;
		const element = node;
		if (element.tagName === "IFRAME") {
			this.setupIframeListeners(element);
			this.onIframeDetected();
			return;
		}
		const iframes = element.querySelectorAll("iframe");
		if (iframes.length > 0) {
			iframes.forEach((iframe) => {
				this.setupIframeListeners(iframe);
			});
			this.onIframeDetected();
		}
	}
	/**
	* Setup event listeners for iframe
	*/
	setupIframeListeners(iframe) {
		const handleIframeEvent = () => {
			this.onIframeDetected();
		};
		iframe.removeEventListener("load", handleIframeEvent);
		iframe.removeEventListener("error", handleIframeEvent);
		iframe.addEventListener("load", handleIframeEvent);
		iframe.addEventListener("error", handleIframeEvent);
	}
};
//#endregion
//#region ../walletkit/dist/esm/bridge/injection/WindowAccessor.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Type-safe accessor for window object manipulation
*/
var WindowAccessor = class {
	window;
	bridgeKey;
	injectTonKey;
	constructor(window, { bridgeKey, injectTonKey }) {
		this.window = window;
		this.bridgeKey = bridgeKey;
		this.injectTonKey = injectTonKey ?? true;
	}
	/**
	* Check if bridge already exists
	*/
	exists() {
		const windowObj = this.window;
		return !!(windowObj[this.bridgeKey] && windowObj[this.bridgeKey].tonconnect);
	}
	/**
	* Get bridge key name
	*/
	getBridgeKey() {
		return this.bridgeKey;
	}
	get tonKey() {
		return "ton";
	}
	/**
	* Ensure wallet object exists on window
	*/
	ensureWalletObject() {
		const windowObj = this.window;
		if (!windowObj[this.bridgeKey]) windowObj[this.bridgeKey] = {};
		if (this.injectTonKey) {
			if (!windowObj[this.tonKey]) windowObj[this.tonKey] = {};
		}
	}
	/**
	* Inject bridge into window object
	*/
	injectBridge(bridge) {
		this.ensureWalletObject();
		const windowObj = this.window;
		Object.defineProperty(windowObj[this.bridgeKey], "tonconnect", {
			value: bridge,
			writable: false,
			enumerable: true,
			configurable: false
		});
		if (this.injectTonKey) Object.defineProperty(windowObj[this.tonKey], "tonconnect", {
			value: bridge,
			writable: false,
			enumerable: true,
			configurable: false
		});
	}
};
//#endregion
//#region ../walletkit/dist/esm/bridge/injection/BridgeInjector.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Cleanup function to remove bridge and stop watching
*/
/**
* Resolve jsBridgeKey from options
*/
function resolveJsBridgeKey(options) {
	if (options.jsBridgeKey) return options.jsBridgeKey;
	if (options.walletInfo) {
		if ("jsBridgeKey" in options.walletInfo) return options.walletInfo.jsBridgeKey;
		if ("name" in options.walletInfo) return options.walletInfo.name;
	}
	return "unknown-wallet";
}
/**
* Create bridge configuration from options
*/
function createBridgeConfig(options) {
	return {
		deviceInfo: getDeviceInfoWithDefaults(options.deviceInfo),
		walletInfo: getWalletInfoWithDefaults(options.walletInfo),
		jsBridgeKey: resolveJsBridgeKey(options),
		isWalletBrowser: options.isWalletBrowser ?? false,
		protocolVersion: 2
	};
}
/**
* Injects TonConnect JS Bridge into the window object
* This is the main facade that orchestrates all components
*
* @param window - Window object to inject into
* @param options - Configuration options
* @returns Cleanup function to remove bridge and stop watching
*/
function injectBridge(window, options, argsTransport) {
	const config = createBridgeConfig(options);
	validateBridgeConfig(config);
	let shouldInjectTonKey = void 0;
	if (options.injectTonKey !== void 0) shouldInjectTonKey = options.injectTonKey;
	else if (options.isWalletBrowser === true) shouldInjectTonKey = true;
	else shouldInjectTonKey = true;
	const windowAccessor = new WindowAccessor(window, {
		bridgeKey: config.jsBridgeKey,
		injectTonKey: shouldInjectTonKey
	});
	if (windowAccessor.exists()) {
		console.log(`${config.jsBridgeKey}.tonconnect already exists, skipping injection`);
		return;
	}
	let transport;
	if (argsTransport) transport = typeof argsTransport === "function" ? argsTransport() : argsTransport;
	else throw new WalletKitError(ERROR_CODES.INVALID_CONFIG, "Transport is not configured");
	const bridge = new TonConnectBridge(config, transport);
	windowAccessor.injectBridge(bridge);
	console.log(`TonConnect JS Bridge injected for ${config.jsBridgeKey} - forwarding to extension`);
	new IframeWatcher(() => {
		transport.requestContentScriptInjection();
	}).start();
}
//#endregion
//#region ../walletkit/dist/esm/core/Logger.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Logger module for TonWalletKit with hierarchical prefix support
*
* Features:
* - Configurable log levels (DEBUG, INFO, WARN, ERROR, NONE)
* - Hierarchical logger creation with prefix inheritance
* - Parent-child logger relationships
* - Structured logging with context support
* - Timestamp and stack trace options
*
* Example usage:
* ```typescript
* import { createLogger, LogLevel } from './Logger';
*
* // Create root logger
* const appLogger = createLogger({
*   level: LogLevel.DEBUG,
*   prefix: 'WalletKit'
* });
*
* // Create child loggers with inherited prefixes
* const connectionLogger = appLogger.createChild('Connection');
* const httpLogger = connectionLogger.createChild('HTTP');
*
* // Logs will show as: [WalletKit:Connection:HTTP] INFO: Request sent
* httpLogger.info('Request sent');
* ```
*/
/**
* Log levels enum for controlling logger verbosity
*/
var LogLevel;
(function(LogLevel) {
	LogLevel[LogLevel["DEBUG"] = 0] = "DEBUG";
	LogLevel[LogLevel["INFO"] = 1] = "INFO";
	LogLevel[LogLevel["WARN"] = 2] = "WARN";
	LogLevel[LogLevel["ERROR"] = 3] = "ERROR";
	LogLevel[LogLevel["NONE"] = 4] = "NONE";
})(LogLevel || (LogLevel = {}));
function getDefaultLogLevel() {
	if (typeof process === "undefined" || typeof process?.env === "undefined") return LogLevel.ERROR;
	return process?.env?.WALLETKIT_LOG_LEVEL === "debug" ? LogLevel.DEBUG : process?.env?.WALLETKIT_LOG_LEVEL === "none" ? LogLevel.NONE : process?.env?.WALLETKIT_LOG_LEVEL === "info" ? LogLevel.INFO : process?.env?.WALLETKIT_LOG_LEVEL === "warn" ? LogLevel.WARN : process?.env?.WALLETKIT_LOG_LEVEL === "off" ? LogLevel.NONE : LogLevel.ERROR;
}
new class Logger {
	config;
	parent;
	static defaultConfig = {
		level: LogLevel.INFO,
		prefix: "TonWalletKit",
		enableTimestamp: true,
		enableStackTrace: false
	};
	constructor(config) {
		this.parent = config?.parent;
		this.config = {
			...Logger.defaultConfig,
			...config
		};
		if (this.parent) this.config = {
			...this.parent.config,
			...config,
			prefix: this.buildHierarchicalPrefix(config?.prefix)
		};
	}
	/**
	* Update logger configuration
	*/
	configure(config) {
		this.config = {
			...this.config,
			...config
		};
	}
	/**
	* Create a child logger with a prefix that inherits from this logger
	*/
	createChild(prefix, config) {
		return new Logger({
			...config,
			parent: this,
			prefix
		});
	}
	/**
	* Build hierarchical prefix by combining parent prefix with current prefix
	*/
	buildHierarchicalPrefix(currentPrefix) {
		if (!this.parent || !currentPrefix) return currentPrefix || this.parent?.config.prefix || "";
		const parentPrefix = this.parent.config.prefix;
		if (!parentPrefix) return currentPrefix;
		return `${parentPrefix}:${currentPrefix}`;
	}
	/**
	* Get the full hierarchical prefix for this logger
	*/
	getPrefix() {
		return this.config.prefix || "";
	}
	/**
	* Get the parent logger if it exists
	*/
	getParent() {
		return this.parent;
	}
	/**
	* Log debug messages
	*/
	debug(message, context) {
		if (this.config.level <= LogLevel.DEBUG) this.log("DEBUG", message, context);
	}
	/**
	* Log info messages
	*/
	info(message, context) {
		if (this.config.level <= LogLevel.INFO) this.log("INFO", message, context);
	}
	/**
	* Log warning messages
	*/
	warn(message, context) {
		if (this.config.level <= LogLevel.WARN) this.log("WARN", message, context);
	}
	/**
	* Log error messages
	*/
	error(message, context) {
		if (this.config.level <= LogLevel.ERROR) this.log("ERROR", message, context);
	}
	/**
	* Internal logging method
	*/
	log(level, message, context) {
		const timestamp = this.config.enableTimestamp ? (/* @__PURE__ */ new Date()).toISOString() : "";
		const prefix = this.config.prefix ? `[${this.config.prefix}]` : "";
		let logMessage = "";
		if (timestamp) logMessage += `${timestamp} `;
		if (prefix) logMessage += `${prefix} `;
		logMessage += `${level}: ${message}`;
		const logArgs = [logMessage];
		if (context && Object.keys(context).length > 0) logArgs.push(context);
		switch (level) {
			case "DEBUG":
				console.debug(...logArgs);
				break;
			case "INFO":
				console.info(...logArgs);
				break;
			case "WARN":
				console.warn(...logArgs);
				break;
			case "ERROR":
				console.error(...logArgs);
				if (this.config.enableStackTrace) console.trace();
				break;
		}
	}
}({
	level: getDefaultLogLevel(),
	enableStackTrace: true
}).createChild("ExtensionTransport");
//#endregion
//#region ../walletkit/dist/esm/bridge/JSBridgeInjector.js
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
/**
* Injects a simplified TonConnect JS Bridge that forwards all requests to the parent extension
* The extension handles all logic through WalletKit
*
* @param window - Window object to inject bridge into
* @param options - Configuration options for the bridge
*/
function injectBridgeCode(window, options, transport) {
	injectBridge(window, options, transport);
}
//#endregion
//#region src/inject.ts
/**
* Copyright (c) TonTech.
*
* This source code is licensed under the MIT license found in the
* LICENSE file in the root directory of this source tree.
*
*/
window.injectWalletKit = (options) => {
	try {
		injectBridgeCode(window, options, new SwiftTransport(window));
	} catch (_error) {}
};
window.id = crypto.randomUUID();
var SwiftTransport = class {
	constructor(window) {
		this.eventCallback = null;
		this.messageListener = null;
		this.window = window;
		this.setupMessageListener();
	}
	setupMessageListener() {
		this.messageListener = (event) => {
			if (event.source !== this.window) return;
			const data = event.data;
			if (!data || typeof data !== "object") return;
			if (data.type === "TONCONNECT_BRIDGE_EVENT") {
				this.handleEvent(data.event);
				return;
			}
		};
		this.window.addEventListener("message", this.messageListener);
	}
	handleEvent(event) {
		if (this.eventCallback) try {
			this.eventCallback(event);
		} catch (error) {
			console.error("TonConnect event callback error:", error);
		}
	}
	async send(request) {
		let timeout = request.method === "restoreConnection" ? RESTORE_CONNECTION_TIMEOUT : DEFAULT_REQUEST_TIMEOUT;
		let response = await window.webkit.messageHandlers.walletKitInjectionBridge.postMessage({
			...request,
			frameID: window.id,
			timeout
		});
		if (!response || typeof response !== "object") return Promise.reject(/* @__PURE__ */ new Error("Invalid response"));
		if (response.success) return Promise.resolve(response.payload);
		else return Promise.reject(response.error);
	}
	onEvent(callback) {
		this.eventCallback = callback;
	}
	isAvailable() {
		return true;
	}
	requestContentScriptInjection() {}
	destroy() {}
};
//#endregion

//# sourceMappingURL=inject.mjs.map