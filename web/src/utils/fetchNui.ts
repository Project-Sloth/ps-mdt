import { isEnvBrowser } from "./misc";
import { GetParentResourceName } from "./fivem";
import type { NuiEventName } from "../constants/nuiEvents";
import { validateNuiAction } from "../security/nuiSecurity";

const DEFAULT_TIMEOUT = 10000; // 10 seconds

export async function fetchNui<T = any>(
	eventName: NuiEventName,
	data?: any,
	mockData?: T,
	timeout: number = DEFAULT_TIMEOUT,
): Promise<T> {
	// Security: Validate the event name against whitelist
	if (!validateNuiAction(eventName)) {
		console.warn("[ps-mdt] fetchNui: blocked unknown event:", eventName);
		if (mockData !== undefined) {
			return mockData;
		}
		return {} as T;
	}

	const options = {
		method: "POST",
		headers: {
			"Content-Type": "application/json; charset=UTF-8",
		},
		body: JSON.stringify(data),
	};

	if (isEnvBrowser()) {
		if (mockData) {
			return new Promise((resolve) => {
				setTimeout(() => resolve(mockData), 100);
			});
		}
		return new Promise((resolve) => {
			setTimeout(() => resolve({} as T), 100);
		});
	}

	const resourceName = GetParentResourceName();

	try {
		// Race the fetch against a timeout so a hung callback can't block the dashboard
		const controller = new AbortController();
		const timeoutId = setTimeout(() => controller.abort(), timeout);

		const resp = await fetch(
			`https://${resourceName}/${eventName}`,
			{ ...options, signal: controller.signal },
		);
		clearTimeout(timeoutId);

		if (resp.ok) {
			return await resp.json();
		}

		throw new Error(`HTTP error! status: ${resp.status}`);
	} catch (err) {
		if (isEnvBrowser() && mockData !== undefined) {
			return mockData;
		}
		if (err instanceof DOMException && err.name === "AbortError") {
			console.warn(`[ps-mdt] fetchNui timed out after ${timeout}ms:`, eventName);
			return {} as T;
		}
		throw err;
	}
}
