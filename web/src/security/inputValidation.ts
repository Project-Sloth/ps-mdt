import {
	SECURITY_CONFIG,
	containsForbiddenContent,
	containsForbiddenNameChars,
} from "../security/security";

/**
 * Input validation utilities using the global security config
 */

/**
 * Validates and sanitizes tag input
 */
export function validateTagInput(tag: string): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	if (!tag || typeof tag !== "string") {
		return {
			isValid: false,
			sanitized: "",
			message: "Tag must be a non-empty string",
		};
	}

	const trimmed = tag.trim();

	// Check length
	if (trimmed.length === 0) {
		return {
			isValid: false,
			sanitized: "",
			message: "Invalid input",
		};
	}

	if (trimmed.length > SECURITY_CONFIG.MAX_INSTANCE_NAME_LENGTH) {
		return {
			isValid: false,
			sanitized: trimmed.substring(
				0,
				SECURITY_CONFIG.MAX_INSTANCE_NAME_LENGTH,
			),
			message: "Input too long",
		};
	}

	// Check for forbidden characters
	if (containsForbiddenNameChars(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	// Check for suspicious content
	if (containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	return { isValid: true, sanitized: trimmed };
}

/**
 * Validates report title input
 */
export function validateReportTitle(title: string): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	if (!title || typeof title !== "string") {
		return {
			isValid: false,
			sanitized: "",
			message: "Title must be a non-empty string",
		};
	}

	const trimmed = title.trim();

	// Allow longer titles for reports but still limit them
	const MAX_TITLE_LENGTH = 200;

	if (trimmed.length > MAX_TITLE_LENGTH) {
		return {
			isValid: false,
			sanitized: trimmed.substring(0, MAX_TITLE_LENGTH),
			message: `Input too long`,
		};
	}

	// Check for forbidden characters (less strict for titles)
	if (containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	return { isValid: true, sanitized: trimmed };
}

/**
 * Validates search query input
 */
export function validateSearchQuery(query: string): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	if (!query || typeof query !== "string") {
		return { isValid: true, sanitized: "" }; // Empty search is valid
	}

	const trimmed = query.trim();

	// Limit search query length
	const MAX_SEARCH_LENGTH = 100;

	if (trimmed.length > MAX_SEARCH_LENGTH) {
		return {
			isValid: false,
			sanitized: trimmed.substring(0, MAX_SEARCH_LENGTH),
			message: `Input too long`,
		};
	}

	// Check for suspicious content in search
	if (containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	return { isValid: true, sanitized: trimmed };
}

/**
 * Validates text area/notes input
 */
export function validateNotesInput(notes: string): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	if (!notes || typeof notes !== "string") {
		return { isValid: true, sanitized: "" }; // Empty notes are valid
	}

	const trimmed = notes.trim();

	// Limit notes length
	const MAX_NOTES_LENGTH = 2000;

	if (trimmed.length > MAX_NOTES_LENGTH) {
		return {
			isValid: false,
			sanitized: trimmed.substring(0, MAX_NOTES_LENGTH),
			message: `Input too long`,
		};
	}

	// Check for suspicious content
	if (containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	return { isValid: true, sanitized: trimmed };
}

/**
 * Validates evidence serial number input
 */
export function validateSerialNumber(serial: string): {
	isValid: boolean;
	sanitized: string;
	message?: string;
} {
	if (!serial || typeof serial !== "string") {
		return { isValid: true, sanitized: "" }; // Empty serial is valid
	}

	const trimmed = serial.trim();

	// Limit serial length
	const MAX_SERIAL_LENGTH = 50;

	if (trimmed.length > MAX_SERIAL_LENGTH) {
		return {
			isValid: false,
			sanitized: trimmed.substring(0, MAX_SERIAL_LENGTH),
			message: `Input too long`,
		};
	}

	// Check for forbidden characters
	if (containsForbiddenNameChars(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	// Check for suspicious content
	if (containsForbiddenContent(trimmed)) {
		return {
			isValid: false,
			sanitized: trimmed,
			message: "Invalid input",
		};
	}

	return { isValid: true, sanitized: trimmed };
}
