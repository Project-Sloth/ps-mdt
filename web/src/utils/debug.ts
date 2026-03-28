export function debugLog(...args: any[]): void {
	if (import.meta.env.DEV) {
		console.log("[MDT Debug]", ...args);
	}
}

export function debugError(...args: any[]): void {
	if (import.meta.env.DEV) {
		console.error("[MDT Error]", ...args);
	}
}

export function debugWarn(...args: any[]): void {
	if (import.meta.env.DEV) {
		console.warn("[MDT Warning]", ...args);
	}
}
