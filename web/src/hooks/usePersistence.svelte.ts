import { onDestroy } from "svelte";
import type { createInstanceStateService } from "../services/instanceStateService.svelte";
import type {
	ReportPageData,
	CitizensPageData,
	ChargesPageData,
	VehiclesPageData,
	WeaponsPageData,
	RosterPageData,
	DashboardPageData,
} from "../schemas/persistenceSchema";

type PageType =
	| "report-page"
	| "citizens-page"
	| "charges-page"
	| "vehicles-page"
	| "weapons-page"
	| "roster-page"
	| "dashboard-page";

type PageDataMap = {
	"report-page": ReportPageData;
	"citizens-page": CitizensPageData;
	"charges-page": ChargesPageData;
	"vehicles-page": VehiclesPageData;
	"weapons-page": WeaponsPageData;
	"roster-page": RosterPageData;
	"dashboard-page": DashboardPageData;
};

interface PersistenceOptions {
	debounceMs?: number;
	autoSaveOnChange?: boolean;
	loadOnInstanceChange?: boolean;
	storageKey?: string;
	maxSize?: number;
}

export function usePersistence<T extends PageType>(
	instanceStateService: ReturnType<typeof createInstanceStateService>,
	pageType: T,
	options: PersistenceOptions = {},
) {
	const {
		debounceMs = 500,
		autoSaveOnChange = true,
		loadOnInstanceChange = true,
		storageKey = "mdt-persistence",
		maxSize = 5 * 1024 * 1024, // 5MB default
	} = options;

	let saveTimeout: ReturnType<typeof setTimeout> | null = null;
	let isInitialized = $state(false);
	let previousInstanceId = $state<string | null>(null);

	// Load persisted data for the current instance
	function loadPersistedData(): PageDataMap[T] | null {
		if (!instanceStateService.activeInstanceId) return null;

		return instanceStateService.loadInstanceData(
			instanceStateService.activeInstanceId,
			pageType,
		);
	}

	// Save current data to persistence
	function saveData(data: PageDataMap[T]): boolean {
		if (!instanceStateService.activeInstanceId) {
			console.warn("No active instance to save data to");
			return false;
		}

		try {
			// Validate data size before saving
			const serialized = JSON.stringify(data);
			if (serialized.length > maxSize) {
				console.warn(
					`Data for ${pageType} exceeds max size of ${maxSize} bytes (${serialized.length} bytes). Data not saved.`,
				);
				return false;
			}

			const success = instanceStateService.persistInstanceData(
				instanceStateService.activeInstanceId,
				pageType,
				data,
			);

			if (success) {
				instanceStateService.markInstanceDirty(
					instanceStateService.activeInstanceId,
				);
			} else {
				console.warn(`Failed to save data for ${pageType}`);
			}

			return success;
		} catch (error) {
			console.error(
				`Failed to save persisted data for ${pageType}:`,
				error,
			);
			return false;
		}
	}

	// Debounced save function
	function debouncedSave(data: PageDataMap[T]): void {
		if (!isInitialized) return;

		if (saveTimeout) {
			clearTimeout(saveTimeout);
		}

		saveTimeout = setTimeout(() => {
			saveData(data);
		}, debounceMs);
	}

	// Cancel any pending debounced saves
	function cancelDebouncedSave(): void {
		if (saveTimeout) {
			clearTimeout(saveTimeout);
			saveTimeout = null;
		}
	}

	// Mark instance as clean (typically after successful external save)
	function markClean(): void {
		if (instanceStateService.activeInstanceId) {
			instanceStateService.markCurrentInstanceClean();
		}
	}

	// Check if current instance has unsaved changes
	function isDirty(): boolean {
		if (!instanceStateService.activeInstanceId) return false;
		return instanceStateService.isInstanceDirty(
			instanceStateService.activeInstanceId,
		);
	}

	// Initialize persistence
	function initialize(): void {
		isInitialized = true;
	}

	// Remove data for current instance and page
	function removeData(): boolean {
		if (!instanceStateService.activeInstanceId) {
			return false;
		}

		try {
			// First, use the instance service to properly clear the data
			const success = instanceStateService.removePageData(
				instanceStateService.activeInstanceId,
				pageType,
			);

			if (success) {
				markClean();
			}

			return success;
		} catch (error) {
			console.error(
				`Failed to remove persisted data for ${pageType}:`,
				error,
			);
			return false;
		}
	}

	// Force clear data by directly manipulating localStorage and in-memory instances
	function forceRemoveData(): boolean {
		if (!instanceStateService.activeInstanceId) {
			return false;
		}

		try {
			// First, clear the data through the instance service to update in-memory state
			const instanceSuccess = instanceStateService.removePageData(
				instanceStateService.activeInstanceId,
				pageType,
			);

			// Then, also directly manipulate localStorage to ensure it's cleared
			const storageKey = "mdt-tab-instances";
			const stored = localStorage.getItem(storageKey);

			if (stored) {
				const instances = JSON.parse(stored);

				// Find the current instance and remove the page data
				const targetInstance = instances.find(
					(inst: any) =>
						inst.id === instanceStateService.activeInstanceId,
				);

				if (
					targetInstance &&
					targetInstance.data &&
					targetInstance.data[pageType]
				) {
					delete targetInstance.data[pageType];

					// Save back to localStorage
					localStorage.setItem(storageKey, JSON.stringify(instances));
				}
			}

			if (instanceSuccess) {
				markClean();
			}

			return instanceSuccess;
		} catch (error) {
			console.error(
				`Failed to force remove persisted data for ${pageType}:`,
				error,
			);
			return false;
		}
	}

	// Update data using an updater function (useful for partial updates)
	function updateData(
		updater: (current: PageDataMap[T] | null) => PageDataMap[T],
	): boolean {
		const currentData = loadPersistedData();
		const updatedData = updater(currentData);
		return saveData(updatedData);
	}

	// Watch for instance changes and reload data if needed
	if (loadOnInstanceChange) {
		$effect(() => {
			const currentInstanceId = instanceStateService.activeInstanceId;

			if (
				previousInstanceId !== null &&
				previousInstanceId !== currentInstanceId &&
				isInitialized
			) {
				// Instance has changed - let the component handle reloading
				// We don't automatically reload here because each component has different logic
			}

			previousInstanceId = currentInstanceId;
		});
	}

	// Cleanup on destroy
	onDestroy(() => {
		if (saveTimeout) {
			clearTimeout(saveTimeout);
		}
	});

	return {
		// Core persistence functions

		/**
		 * Loads persisted data for the current active instance and page type.
		 * @returns The persisted data for the current instance, or null if no data exists or no active instance
		 */
		loadPersistedData,

		/**
		 * Saves data to persistence for the current active instance.
		 * Validates data size against maxSize limit before saving.
		 * @param data - The data to persist
		 * @returns True if data was successfully saved, false otherwise
		 */
		saveData,

		/**
		 * Debounced version of saveData that delays saving until after the debounce period.
		 * Useful for auto-saving during user input to avoid excessive localStorage writes.
		 * @param data - The data to persist after debounce delay
		 */
		debouncedSave,

		/**
		 * Cancels any pending debounced saves.
		 * Useful when you want to prevent pending saves from executing.
		 */
		cancelDebouncedSave,

		/**
		 * Removes persisted data for the current instance and page type.
		 * Also marks the instance as clean after successful removal.
		 * @returns True if data was successfully removed, false otherwise
		 */
		clearPersistedData: removeData,

		/**
		 * Force removes persisted data by directly manipulating localStorage.
		 * Use this as a fallback when the normal removal doesn't work.
		 * @returns True if data was successfully removed, false otherwise
		 */
		forceRemoveData,

		/**
		 * Updates persisted data using an updater function for partial updates.
		 * Loads current data, applies the updater function, then saves the result.
		 * @param updater - Function that receives current data and returns updated data
		 * @returns True if data was successfully updated and saved, false otherwise
		 */
		updateData,

		// Instance state management

		/**
		 * Marks the current instance as clean (no unsaved changes).
		 * Typically called after successfully saving data to an external service.
		 */
		markClean,

		/**
		 * Checks if the current instance has unsaved changes.
		 * @returns True if the instance has unsaved changes, false otherwise
		 */
		isDirty,

		/**
		 * Initializes the persistence hook and enables auto-save functionality.
		 * Must be called before using debounced save features.
		 */
		initialize,

		// State getters

		/**
		 * Whether the persistence hook has been initialized.
		 * @returns True if initialize() has been called, false otherwise
		 */
		get isInitialized() {
			return isInitialized;
		},

		/**
		 * The ID of the currently active instance.
		 * @returns The active instance ID, or null if no instance is active
		 */
		get activeInstanceId() {
			return instanceStateService.activeInstanceId;
		},

		/**
		 * Whether the active instance has changed since the last check.
		 * Useful for detecting when components need to reload their data.
		 * @returns True if the instance has changed, false otherwise
		 */
		get hasInstanceChanged() {
			return previousInstanceId !== instanceStateService.activeInstanceId;
		},
	};
}
