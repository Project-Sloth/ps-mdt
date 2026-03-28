import type { TabInstance } from "../interfaces/IMDT";
import type { ComponentId, MDTTab } from "../constants";
import {
	SECURITY_CONFIG,
	SECURITY_MESSAGES,
	getMaxInstanceStorageSize,
	containsForbiddenContent,
	containsForbiddenNameChars,
} from "../config/security";

function isValidTab(tab: string): tab is MDTTab {
	return (SECURITY_CONFIG.ALLOWED_TABS as readonly string[]).includes(tab);
}

function isValidInstanceId(id: string): id is ComponentId {
	return (
		typeof id === "string" && SECURITY_CONFIG.ALLOWED_ID_PATTERN.test(id)
	);
}

function isValidInstanceName(name: string): boolean {
	return (
		typeof name === "string" &&
		name.length > 0 &&
		name.length <= SECURITY_CONFIG.MAX_INSTANCE_NAME_LENGTH &&
		!containsForbiddenNameChars(name)
	);
}

function isValidDataSize(data: any): boolean {
	if (data === undefined || data === null) {
		return true;
	}

	try {
		const serialized = JSON.stringify(data);
		return serialized.length <= SECURITY_CONFIG.MAX_DATA_SIZE;
	} catch {
		return false;
	}
}

/** Validates an instance object's properties and security constraints */
export function isValidInstance(instance: any): instance is TabInstance {
	if (!instance || typeof instance !== "object") {
		return false;
	}

	// Check required properties exist
	if (!instance.id || !instance.instanceName || !instance.currentTab) {
		return false;
	}

	// Security validations
	if (!isValidInstanceId(instance.id)) {
		console.warn(SECURITY_MESSAGES.INVALID_ID_FORMAT);
		return false;
	}

	if (!isValidInstanceName(instance.instanceName)) {
		console.warn(SECURITY_MESSAGES.INVALID_NAME_FORMAT);
		return false;
	}

	if (!isValidTab(instance.currentTab)) {
		console.warn(SECURITY_MESSAGES.INVALID_TAB);
		return false;
	}

	// Validate isActive is boolean
	if (typeof instance.isActive !== "boolean") {
		console.warn(SECURITY_MESSAGES.INVALID_BOOLEAN);
		return false;
	}

	// Validate data size if present
	if (!isValidDataSize(instance.data)) {
		console.warn(SECURITY_MESSAGES.DATA_TOO_LARGE);
		return false;
	}

	return true;
}

/** Validates data is serializable and safe for localStorage */
export function validateSerializableData(data: any): any {
	if (data === undefined || data === null) {
		return data;
	}

	// Check data size first
	if (!isValidDataSize(data)) {
		console.warn(SECURITY_MESSAGES.DATA_TOO_LARGE);
		return undefined;
	}

	try {
		// Test serialization
		const serialized = JSON.stringify(data);

		// Additional security: prevent function injection
		if (containsForbiddenContent(serialized)) {
			console.warn(SECURITY_MESSAGES.SUSPICIOUS_CONTENT);
			return undefined;
		}

		return data;
	} catch (error) {
		console.warn(SECURITY_MESSAGES.NOT_SERIALIZABLE);
		return undefined;
	}
}

/** Validates and filters instances with security limits */
export function validateInstanceArray(instances: any[]): TabInstance[] {
	// Security: Limit number of instances to prevent memory exhaustion
	if (instances.length > SECURITY_CONFIG.MAX_INSTANCES) {
		console.warn(SECURITY_MESSAGES.TOO_MANY_INSTANCES);
		instances = instances.slice(0, SECURITY_CONFIG.MAX_INSTANCES);
	}

	const validInstances = instances.filter((instance: any) => {
		if (!isValidInstance(instance)) {
			console.warn("MDT: Found invalid instance data in localStorage");
			return false;
		}
		return true;
	});

	if (validInstances.length !== instances.length) {
		console.warn(
			"MDT: Some saved instances were corrupted and have been removed",
		);
	}

	// Ensure at least one instance is active, and only one
	const activeInstances = validInstances.filter(
		(instance) => instance.isActive,
	);
	if (activeInstances.length !== 1) {
		console.warn("MDT: Fixed invalid active instance state");
		validInstances.forEach((instance, index) => {
			instance.isActive = index === 0; // Make first instance active
		});
	}

	return validInstances;
}

/** Loads and validates instances from localStorage */
export function loadInstancesFromStorage(): TabInstance[] {
	try {
		const savedTabs = localStorage.getItem("mdt-tab-instances");
		if (!savedTabs) {
			return [];
		}

		// Security: Check data size before parsing to prevent large payload attacks
		if (savedTabs.length > getMaxInstanceStorageSize()) {
			console.warn(SECURITY_MESSAGES.STORAGE_TOO_LARGE);
			localStorage.removeItem("mdt-tab-instances"); // Clean up
			return [];
		}

		const parsed = JSON.parse(savedTabs);
		if (!Array.isArray(parsed)) {
			console.warn(
				"MDT: Invalid localStorage data format, resetting instances",
			);
			localStorage.removeItem("mdt-tab-instances"); // Clean up
			return [];
		}

		return validateInstanceArray(parsed);
	} catch (error) {
		console.error("MDT: Failed to load saved instances:", error);
		// Clean up potentially corrupted data
		try {
			localStorage.removeItem("mdt-tab-instances");
		} catch {
			// Ignore cleanup errors
		}
		return [];
	}
}

/** Saves validated instances to localStorage */
export function saveInstancesToStorage(instances: TabInstance[]): void {
	try {
		// Security: Limit number of instances
		if (instances.length > SECURITY_CONFIG.MAX_INSTANCES) {
			console.warn(SECURITY_MESSAGES.TOO_MANY_INSTANCES);
			instances = instances.slice(0, SECURITY_CONFIG.MAX_INSTANCES);
		}

		// Filter out any invalid instances before saving
		const validInstances = instances.filter((instance) => {
			if (!isValidInstance(instance)) {
				console.warn("MDT: Skipping invalid instance during save");
				return false;
			}
			return true;
		});

		// Security: Check total payload size
		const serialized = JSON.stringify(validInstances);
		if (serialized.length > getMaxInstanceStorageSize()) {
			console.warn(SECURITY_MESSAGES.STORAGE_TOO_LARGE);
			return;
		}

		localStorage.setItem("mdt-tab-instances", serialized);
	} catch (error) {
		console.error("MDT: Failed to save instances:", error);

		// Check if it's a quota exceeded error
		if (
			error instanceof DOMException &&
			error.name === "QuotaExceededError"
		) {
			console.error(
				"MDT: localStorage quota exceeded - try clearing browser data",
			);
		}
	}
}

/** Validates instance creation parameters */
export function validateInstanceCreation(
	id: ComponentId,
	instanceName: string,
): boolean {
	if (!isValidInstanceId(id)) {
		console.warn(SECURITY_MESSAGES.INVALID_ID_FORMAT);
		return false;
	}

	if (!isValidInstanceName(instanceName)) {
		console.warn(SECURITY_MESSAGES.INVALID_NAME_FORMAT);
		return false;
	}

	return true;
}

export function validateTab(tab: MDTTab): boolean {
	if (!isValidTab(tab)) {
		console.warn(SECURITY_MESSAGES.INVALID_TAB);
		return false;
	}
	return true;
}
