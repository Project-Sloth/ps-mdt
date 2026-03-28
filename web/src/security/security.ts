/**
 * Security configuration and content validation utilities
 */

export const SECURITY_CONFIG = {
	MAX_NUI_MESSAGE_SIZE: 1024 * 1024, // 1MB
	MAX_DATA_SIZE: 1024 * 1024, // 1MB
	// Text length limits
	MAX_INSTANCE_NAME_LENGTH: 50,
	MAX_REPORT_TITLE_LENGTH: 200,
	MAX_SEARCH_QUERY_LENGTH: 100,
	MAX_NOTES_LENGTH: 2000,
	MAX_SERIAL_NUMBER_LENGTH: 50,

	// Content limits
	MAX_EVIDENCE_ITEMS: 20,
	MAX_INVOLVED_PERSONS: 50,
	MAX_TAGS_PER_REPORT: 10,

	// File size limits
	MAX_IMAGE_SIZE: 5 * 1024 * 1024, // 5MB
	MAX_PERSISTENCE_SIZE: 5 * 1024 * 1024, // 5MB
} as const;

/**
 * List of forbidden characters for names and identifiers
 */
const FORBIDDEN_NAME_CHARS = [
	"<",
	">",
	'"',
	"'",
	"&",
	"\0",
	"\r",
	"\n",
	"\t",
	"script",
	"javascript:",
	"vbscript:",
	"onload",
	"onerror",
	"data:",
	"blob:",
	"file:",
	"ftp:",
	"javascript",
];

/**
 * List of suspicious content patterns
 */
const FORBIDDEN_CONTENT_PATTERNS = [
	// Script injection attempts
	/<script\b/i,
	/<\/script>/i,
	/javascript:/i,
	/vbscript:/i,
	/onload\s*=/i,
	/onerror\s*=/i,
	/onclick\s*=/i,
	/onmouseover\s*=/i,

	// HTML injection
	/<iframe\b/i,
	/<object\b/i,
	/<embed\b/i,
	/<form\b/i,
	/<input\b/i,

	// SQL injection patterns
	/union\s+select/i,
	/drop\s+table/i,
	/delete\s+from/i,
	/insert\s+into/i,
	/update\s+set/i,

	// Path traversal
	/\.\.\//,
	/\.\.[/\\]/,

	// Command injection
	/\\\|\s*[a-zA-Z]/,
	/;\s*[a-zA-Z]/,
	/&&\s*[a-zA-Z]/,
	/\$\(/,
	/`[^`]*`/,
] as const;

/**
 * Checks if text contains forbidden characters for names/identifiers
 */
export function containsForbiddenNameChars(text: string): boolean {
	if (!text || typeof text !== "string") {
		return false;
	}

	const lowerText = text.toLowerCase();

	return FORBIDDEN_NAME_CHARS.some((char) =>
		lowerText.includes(char.toLowerCase()),
	);
}

/**
 * Checks if text contains forbidden content patterns
 */
export function containsForbiddenContent(text: string): boolean {
	if (!text || typeof text !== "string") {
		return false;
	}

	// Check for forbidden patterns
	return FORBIDDEN_CONTENT_PATTERNS.some((pattern) => {
		if (pattern instanceof RegExp) {
			return pattern.test(text);
		}
		return false;
	});
}

/**
 * Sanitizes text by removing or escaping dangerous content
 */
export function sanitizeText(text: string): string {
	if (!text || typeof text !== "string") {
		return "";
	}

	return text
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&#x27;")
		.replace(/\0/g, "")
		.replace(/\r\n/g, "\n")
		.replace(/\r/g, "\n")
		.trim();
}

/**
 * Validates that a string is within acceptable length limits
 */
export function isWithinLengthLimit(text: string, maxLength: number): boolean {
	return !text || text.length <= maxLength;
}

/**
 * Truncates text to specified length while preserving word boundaries
 */
export function truncateText(text: string, maxLength: number): string {
	if (!text || text.length <= maxLength) {
		return text || "";
	}

	const truncated = text.substring(0, maxLength);
	const lastSpace = truncated.lastIndexOf(" ");

	// If we can break at a word boundary, do so
	if (lastSpace > maxLength * 0.8) {
		return truncated.substring(0, lastSpace) + "...";
	}

	// Otherwise, hard truncate
	return truncated + "...";
}

/**
 * Comprehensive content validation
 */
export function validateContent(
	content: string,
	options: {
		maxLength?: number;
		allowEmpty?: boolean;
		checkForbiddenChars?: boolean;
		checkForbiddenContent?: boolean;
	} = {},
): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	const {
		maxLength = Infinity,
		allowEmpty = true,
		checkForbiddenChars = true,
		checkForbiddenContent = true,
	} = options;

	if (!content || typeof content !== "string") {
		if (!allowEmpty) {
			return {
				isValid: false,
				sanitized: "",
				message: "Content is required",
			};
		}
		return { isValid: true, sanitized: "" };
	}

	const trimmed = content.trim();

	if (!allowEmpty && trimmed.length === 0) {
		return {
			isValid: false,
			sanitized: "",
			message: "Content is required",
		};
	}

	if (!isWithinLengthLimit(trimmed, maxLength)) {
		return {
			isValid: false,
			sanitized: truncateText(trimmed, maxLength),
			message: `Content exceeds maximum length of ${maxLength} characters`,
		};
	}

	if (checkForbiddenChars && containsForbiddenNameChars(trimmed)) {
		return {
			isValid: false,
			sanitized: sanitizeText(trimmed),
			message: "Content contains forbidden characters",
		};
	}

	if (checkForbiddenContent && containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: sanitizeText(trimmed),
			message: "Content contains suspicious patterns",
		};
	}

	return { isValid: true, sanitized: trimmed };
}
