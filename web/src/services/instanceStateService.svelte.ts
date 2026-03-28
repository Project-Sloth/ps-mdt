import type { MDTTab, ComponentId } from "@/constants";
import type {
	ReportPageData,
	CitizensPageData,
	ChargesPageData,
	VehiclesPageData,
	WeaponsPageData,
	RosterPageData,
	DashboardPageData,
} from "@/schemas/persistenceSchema";
import type { TabService } from "./tabService.svelte";

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

export interface InstanceState {
	instanceId: ComponentId;
	currentTab: MDTTab;
	isDirty: boolean;
	lastAccessed: number;
}

export function createInstanceStateService(tabService: TabService) {
	let activeInstanceId = $state<ComponentId | null>(null);
	let instances = $state<Map<ComponentId, InstanceState>>(new Map());

	function markCurrentInstanceClean(): void {
		if (!activeInstanceId) {
			return;
		}

		const instance = instances.get(activeInstanceId);

		if (!instance || !instance.isDirty) {
			return;
		}

		instance.isDirty = false;
		instance.lastAccessed = Date.now();
	}

	function persistInstanceData<T extends PageType>(
		instanceId: ComponentId,
		pageType: T,
		data: PageDataMap[T],
	): boolean {
		try {
			// Get the tab instance from tab service
			const tabInstance = tabService.instances.find(
				(inst) => inst.id === instanceId,
			);
			if (!tabInstance) {
				console.warn(`Instance ${instanceId} not found in tab service`);
				return false;
			}

			// Initialize data object if it doesn't exist
			if (!tabInstance.data) {
				tabService.updateInstanceData(instanceId, {});
			}

			// Update the specific page data within the instance
			const currentData = tabService.getInstanceData(instanceId) || {};
			currentData[pageType] = data;

			// Save back to tab service (which handles localStorage persistence)
			tabService.updateInstanceData(instanceId, currentData);

			return true;
		} catch (error) {
			console.error(
				`Failed to persist instance data for ${instanceId}:${pageType}:`,
				error,
			);
			return false;
		}
	}

	function loadInstanceData<T extends PageType>(
		instanceId: ComponentId,
		pageType: T,
	): PageDataMap[T] | null {
		try {
			// Get data from tab service
			const instanceData = tabService.getInstanceData(instanceId);
			if (!instanceData) {
				return null;
			}

			return instanceData[pageType] || null;
		} catch (error) {
			console.error(
				`Failed to load instance data for ${instanceId}:${pageType}:`,
				error,
			);
			return null;
		}
	}

	function switchToInstance(newInstanceId: ComponentId, tab: MDTTab): void {
		// Mark current instance as clean before switching
		markCurrentInstanceClean();

		// Update or create the target instance state
		if (!instances.has(newInstanceId)) {
			instances.set(newInstanceId, {
				instanceId: newInstanceId,
				currentTab: tab,
				isDirty: false,
				lastAccessed: Date.now(),
			});
		} else {
			const instance = instances.get(newInstanceId)!;
			instance.currentTab = tab;
			instance.lastAccessed = Date.now();
		}

		activeInstanceId = newInstanceId;
	}

	function markInstanceDirty(instanceId: ComponentId): void {
		const instance = instances.get(instanceId);
		if (instance) {
			instance.isDirty = true;
		}
	}

	function isInstanceDirty(instanceId: ComponentId): boolean {
		const instance = instances.get(instanceId);
		return instance?.isDirty || false;
	}

	function removePageData<T extends PageType>(
		instanceId: ComponentId,
		pageType: T,
	): boolean {
		try {
			// Get the tab instance from tab service
			const tabInstance = tabService.instances.find(
				(inst) => inst.id === instanceId,
			);
			if (!tabInstance) {
				return false;
			}

			// If there's no data, consider it successfully removed
			if (!tabInstance.data) {
				return true;
			}

			// Get current data and delete the specific page
			const currentData = tabService.getInstanceData(instanceId) || {};
			delete currentData[pageType];

			// Update the instance data without the removed page
			tabService.updateInstanceData(instanceId, currentData);

			// Verify the data was actually removed
			const verifyData = tabService.getInstanceData(instanceId) || {};
			const isRemoved = !(pageType in verifyData);

			return isRemoved;
		} catch (error) {
			return false;
		}
	}

	return {
		get activeInstanceId() {
			return activeInstanceId;
		},
		get instances() {
			return instances;
		},
		markCurrentInstanceClean,
		persistInstanceData,
		loadInstanceData,
		switchToInstance,
		markInstanceDirty,
		isInstanceDirty,
		removePageData,
	};
}
