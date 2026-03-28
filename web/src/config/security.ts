import type { MDTTab } from "../constants";

/** Security limits and validation rules */
export const SECURITY_CONFIG = {
	// Instance Management
	MAX_INSTANCES: 10, // Prevent memory exhaustion attacks
	MAX_INSTANCE_NAME_LENGTH: 50, // Prevent oversized names

	// Data Storage
	MAX_DATA_SIZE: 2048000, // Prevent large payloads (2MB per instance)
	MAX_UPLOAD_SIZE: 8000000, // Allow uploads up to ~8MB (base64 overhead)
	MAX_TOTAL_STORAGE_SIZE: 2000000, // Total localStorage limit (2MB)

	// Input Validation
	ALLOWED_ID_PATTERN: /^[a-zA-Z0-9_-]{1,32}$/, // Alphanumeric, underscore, dash only
	FORBIDDEN_NAME_CHARS: ["<", ">", "&", '"', "'"], // Prevent HTML/XSS injection

	// Content Security
	FORBIDDEN_CONTENT_PATTERNS: [
		"eval(",
		"javascript:",
		"<script",
		"</script>",
		"onclick=",
		"onerror=",
		"onload=",
	], // Prevent code injection

	// Whitelisted tabs (must match MDT_TABS from constants)
	ALLOWED_TABS: [
		"Dashboard",
		"Citizens",
		"BOLOs",
		"Vehicles",
		"Weapons",
		"Cases",
		"Evidence",
		"Reports",
		"Warrants",
		"Charges",
		"Awards",
		"Roster",
		"Map",
		"Cameras",
		"Bodycams",
		"IA",
		"PPR",
		"FTO",
		"SOP",
		"Court Cases",
		"Warrant Review",
		"Court Orders",
		"Legal Documents",
		"Settings",
		"Preferences",
	] as const satisfies readonly MDTTab[],
} as const;

/**
 * Security error messages for consistent logging
 */
export const SECURITY_MESSAGES = {
	INVALID_ID_FORMAT:
		"MDT: Invalid ID format - must be alphanumeric with dashes/underscores only",
	INVALID_NAME_FORMAT:
		"MDT: Invalid name - contains forbidden characters or too long",
	INVALID_TAB: "MDT: Invalid tab name - not in allowed list",
	DATA_TOO_LARGE: "MDT: Data too large - exceeds size limit",
	SUSPICIOUS_CONTENT:
		"MDT: Suspicious content detected - potential code injection",
	TOO_MANY_INSTANCES: "MDT: Too many instances - limiting to maximum allowed",
	STORAGE_TOO_LARGE: "MDT: Storage data too large - potential attack",
	INVALID_BOOLEAN: "MDT: Invalid boolean value",
	NOT_SERIALIZABLE: "MDT: Data not serializable",
} as const;

/**
 * Type helpers for security validation
 */
export type SecurityValidationResult = {
	isValid: boolean;
	message?: string;
};

/**
 * Get the maximum allowed storage size for instances
 */
export function getMaxInstanceStorageSize(): number {
	return SECURITY_CONFIG.MAX_DATA_SIZE * SECURITY_CONFIG.MAX_INSTANCES;
}

/**
 * Check if a string contains any forbidden content patterns
 */
export function containsForbiddenContent(content: string): boolean {
	const lowerContent = content.toLowerCase();
	return SECURITY_CONFIG.FORBIDDEN_CONTENT_PATTERNS.some((pattern) =>
		lowerContent.includes(pattern.toLowerCase()),
	);
}

/**
 * Check if a string contains forbidden name characters
 */
export function containsForbiddenNameChars(name: string): boolean {
	return SECURITY_CONFIG.FORBIDDEN_NAME_CHARS.some((char) =>
		name.includes(char),
	);
}
