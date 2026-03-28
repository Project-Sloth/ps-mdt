import { fetchNui } from "../utils/fetchNui";
import { debugError } from "../utils/debug";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type { PlayerData } from "../interfaces/IPlayerData";
import type { NuiEventName } from "../constants/nuiEvents";

export function createDispatchService() {
	async function performDispatchAction(
		action: NuiEventName,
		dispatchId: string,
	): Promise<any[] | null> {
		try {
			const result = await fetchNui(action, dispatchId);
			return result && Array.isArray(result) ? result : null;
		} catch (error) {
			debugError(
				`Failed to ${action.replace(/([A-Z])/g, " $1").toLowerCase()}:`,
				error,
			);
			return null;
		}
	}

	async function attachYourselfToDispatch(
		dispatchId: string,
	): Promise<any[] | null> {
		return performDispatchAction(
			NUI_EVENTS.DISPATCH.ATTACH_TO_DISPATCH,
			dispatchId,
		);
	}

	async function detachYourselfFromDispatch(
		dispatchId: string,
	): Promise<any[] | null> {
		return performDispatchAction(
			NUI_EVENTS.DISPATCH.DETACH_FROM_DISPATCH,
			dispatchId,
		);
	}

	function isUserAttachedToDispatch(
		dispatch: any,
		playerData: PlayerData | null,
	): boolean {
		if (!playerData) return false;

		const units = dispatch.units || dispatch.attachedUnits || [];
		if (units.length === 0) return false;

		return units.some(
			(unit: any) => unit.citizenid === playerData.citizenid,
		);
	}

	async function routeToDispatch(dispatch: any): Promise<void> {
		try {
			await fetchNui(NUI_EVENTS.DISPATCH.ROUTE_TO_DISPATCH, dispatch);
			await fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI);
		} catch (error) {
			debugError("Failed to route to dispatch:", error);
		}
	}

	function getCallSign(callsign?: string): string {
		return callsign && callsign !== "NO CALLSIGN" ? callsign : "XX";
	}

	return {
		attachYourselfToDispatch,
		detachYourselfFromDispatch,
		isUserAttachedToDispatch,
		routeToDispatch,
		getCallSign,
	};
}

export type DispatchService = ReturnType<typeof createDispatchService>;
