import { SECURITY_CONFIG as NUI_SECURITY_CONFIG, containsForbiddenContent } from "./security";
import { GetParentResourceName } from "../utils/fivem";
import { ALL_NUI_EVENTS, type NuiEventName } from "../constants/nuiEvents";

/**
 * NUI (Native User Interface) security utilities for FiveM
 */

/**
 * Validates incoming NUI message data
 */
export function validateNuiMessage(data: any): {
	isValid: boolean;
	sanitized: any;
	message?: string;
} {
	if (data === null || data === undefined) {
		return { isValid: true, sanitized: data };
	}

	// Check if data is an object
	if (typeof data === "object") {
		try {
			// Check serialization size
			const serialized = JSON.stringify(data);
			if (serialized.length > NUI_SECURITY_CONFIG.MAX_NUI_MESSAGE_SIZE) {
				return {
					isValid: false,
					sanitized: {},
					// Generic message - don't reveal size limits
					message: "Invalid data",
				};
			}

			// Check for suspicious content
			if (containsForbiddenContent(serialized)) {
				return {
					isValid: false,
					sanitized: {},
					// Generic message - don't reveal what patterns we check
					message: "Invalid data",
				};
			}

			return { isValid: true, sanitized: data };
		} catch (error) {
			return {
				isValid: false,
				sanitized: {},
				// Generic message - don't reveal serialization details
				message: "Invalid data",
			};
		}
	}

	// For primitive types, check for suspicious content
	if (typeof data === "string") {
		if (containsForbiddenContent(data)) {
			return {
				isValid: false,
				sanitized: "",
				// Generic message - don't reveal content filtering
				message: "Invalid data",
			};
		}
	}

	return { isValid: true, sanitized: data };
}

/**
 * Validates NUI event action names against the whitelist of allowed events
 */
export function validateNuiAction(action: string): action is NuiEventName {
	if (!action || typeof action !== "string") {
		// Don't reveal what we're checking for
		return false;
	}

	// Security: Check against whitelist of allowed NUI events
	if (!ALL_NUI_EVENTS.includes(action as NuiEventName)) {
		// Silent rejection - don't reveal the whitelist exists
		return false;
	}

	// Additional security: Check for suspicious content (defense in depth)
	if (containsForbiddenContent(action)) {
		// Silent rejection - don't reveal what patterns we're checking
		return false;
	}

	return true;
}

/**
 * Secure wrapper for postMessage to FiveM
 */
export function securePostMessage(action: NuiEventName, data?: any): void {
	// Validate action against whitelist (silent validation)
	if (!validateNuiAction(action)) {
		// Silent rejection - no error details
		return;
	}

	// Validate data (silent validation)
	const validation = validateNuiMessage(data);
	if (!validation.isValid) {
		// Silent rejection - no error details
		return;
	}

	// Safe to send
	try {
		const resourceName = GetParentResourceName();

		fetch(`https://${resourceName}/${action}`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json; charset=UTF-8",
			},
			body: JSON.stringify(validation.sanitized),
		});
	} catch (error) {
		// Silent failure - don't reveal fetch details
	}
}

/**
 * Rate limiting for NUI events to prevent spam
 */
class NuiRateLimit {
	private actionCounts = new Map<
		string,
		{ count: number; resetTime: number }
	>();
	private readonly maxRequestsPerMinute = 60;
	private readonly windowMs = 60000; // 1 minute
	private lastCleanup = Date.now();
	private readonly cleanupIntervalMs = 300000; // Prune expired entries every 5 minutes

	private cleanup(now: number): void {
		if (now - this.lastCleanup < this.cleanupIntervalMs) return;
		this.lastCleanup = now;
		for (const [key, entry] of this.actionCounts) {
			if (now > entry.resetTime) {
				this.actionCounts.delete(key);
			}
		}
	}

	isAllowed(action: NuiEventName): boolean {
		const now = Date.now();
		this.cleanup(now);
		const current = this.actionCounts.get(action);

		if (!current || now > current.resetTime) {
			// Reset or first time
			this.actionCounts.set(action, {
				count: 1,
				resetTime: now + this.windowMs,
			});
			return true;
		}

		if (current.count >= this.maxRequestsPerMinute) {
			// Silent rate limiting - don't reveal limits or action names
			return false;
		}

		current.count++;
		return true;
	}
}

export const nuiRateLimit = new NuiRateLimit();

/**
 * Check if an action is allowed without validation side effects
 * Note: This is for internal use only - doesn't reveal validation details
 */
export function isNuiActionAllowed(action: string): action is NuiEventName {
	return ALL_NUI_EVENTS.includes(action as NuiEventName);
}
