/**
 * Preferences that have to be in place before the first frame.
 *
 * The authoritative copy lives in Lua's KVP store, because localStorage does
 * not survive a CEF cache clear. localStorage is only a mirror, which means
 * that after a server or resource restart it can be empty while KVP still
 * holds the real values. Pulling KVP used to happen in Settings.svelte's
 * onMount, so nothing was restored until the player opened the Preferences
 * page — the MDT came up at default zoom and window size every time.
 *
 * Seeding therefore happens once at boot, and everything that reads a
 * preference at startup re-applies itself when the pull lands.
 */

export const PREFS_KEY = "ps-mdt-preferences";

/** Fired on window once the KVP copy has been mirrored into localStorage. */
export const PREFS_READY_EVENT = "mdt-prefs-ready";

/** key, window width, window height */
export const WINDOW_STEPS: Array<[string, string, string]> = [
	["compact", "75vw", "72vh"],
	["default", "95vw", "90vh"],
	["full", "99vw", "96vh"],
];

export function readPrefs(): Record<string, unknown> {
	try {
		return JSON.parse(localStorage.getItem(PREFS_KEY) ?? "{}");
	} catch {
		return {};
	}
}

/** Preferences that live on <html> and so belong to no single component. */
export function applyGlobalPrefs(): void {
	const prefs = readPrefs();

	document.documentElement.classList.toggle(
		"mdt-reduced-motion",
		prefs.reducedMotion === true,
	);

	const step =
		WINDOW_STEPS.find(([key]) => key === prefs.windowSize) ?? WINDOW_STEPS[1];
	document.documentElement.style.setProperty("--mdt-window-w", step[1]);
	document.documentElement.style.setProperty("--mdt-window-h", step[2]);
}

let seeded = false;
let markReady: () => void;

/**
 * Resolves once the KVP pull has finished (or failed). Anything that reads a
 * preference exactly once — the default tab, for instance — should wait on
 * this rather than racing the fetch.
 */
export const prefsReady: Promise<void> = new Promise((resolve) => {
	markReady = resolve;
});

/**
 * Mirrors the KVP copy into localStorage and tells the UI to re-read it.
 * Safe to call more than once; only the first call does any work.
 */
export async function seedPreferences(): Promise<void> {
	if (seeded) return;
	seeded = true;

	try {
		const resource = (window as any).GetParentResourceName?.() ?? "ps-mdt";
		const response = await fetch(`https://${resource}/getMdtPrefs`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: "{}",
		});
		const result = await response.json();
		if (result?.data) {
			try {
				localStorage.setItem(PREFS_KEY, result.data);
			} catch {
				/* storage full or blocked — the event still fires for in-memory use */
			}
		}
	} catch {
		/* client unreachable: whatever localStorage holds stands */
	}

	applyGlobalPrefs();
	window.dispatchEvent(new CustomEvent(PREFS_READY_EVENT));
	markReady();
}

/** Subscribe to the seed landing. Returns an unsubscribe function. */
export function onPrefsReady(callback: () => void): () => void {
	window.addEventListener(PREFS_READY_EVENT, callback);
	return () => window.removeEventListener(PREFS_READY_EVENT, callback);
}
