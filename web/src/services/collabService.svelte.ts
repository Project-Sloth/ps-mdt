import * as Y from "yjs";
import { fetchNui } from "../utils/fetchNui";
import { useNuiEvent } from "../utils/useNuiEvent";
import { NUI_EVENTS } from "../constants/nuiEvents";
import { GetParentResourceName } from "../utils/fivem";
import { isEnvBrowser } from "../utils/misc";

export interface CollabEditor {
	source: number;
	name: string;
	citizenid: string;
	color: string;
}

export interface CollabState {
	active: boolean;
	reportId: string | null;
	myColor: string;
	myName: string;
	editors: CollabEditor[];
}

function fireNui(eventName: string, data: any) {
	if (isEnvBrowser()) return;
	const resourceName = GetParentResourceName();
	fetch(`https://${resourceName}/${eventName}`, {
		method: "POST",
		headers: { "Content-Type": "application/json; charset=UTF-8" },
		body: JSON.stringify(data),
	}).catch(() => {});
}

function uint8ToBase64(arr: Uint8Array): string {
	let binary = "";
	for (let i = 0; i < arr.length; i++) {
		binary += String.fromCharCode(arr[i]);
	}
	return btoa(binary);
}

function base64ToUint8(b64: string): Uint8Array {
	const binary = atob(b64);
	const arr = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) {
		arr[i] = binary.charCodeAt(i);
	}
	return arr;
}

export function createCollabService() {
	let state = $state<CollabState>({
		active: false,
		reportId: null,
		myColor: "#3B82F6",
		myName: "",
		editors: [],
	});

	let myCitizenId: string = "";
	let ydoc: Y.Doc | null = null;
	let isDestroyed = false;
	let yjsPollerInterval: ReturnType<typeof setInterval> | null = null;

	let onEditorsChanged: ((editors: CollabEditor[]) => void) | null = null;
	let onRemoteDataUpdate: ((dataType: string, data: any) => void) | null = null;

	let lastRemoteData: Record<string, string> = {};
	let structuredDataSyncTimer: ReturnType<typeof setTimeout> | null = null;
	let lastSentStructuredData: Record<string, string> = {};

	let pendingUpdates: Uint8Array[] = [];
	let updateFlushTimer: ReturnType<typeof setTimeout> | null = null;

	function flushYjsUpdates() {
		if (pendingUpdates.length === 0 || !state.active || !state.reportId) return;
		const merged = Y.mergeUpdates(pendingUpdates);
		pendingUpdates = [];
		fireNui("syncYjsUpdate", {
			reportId: state.reportId,
			update: uint8ToBase64(merged),
		});
	}

	function startYjsPoller() {
		stopYjsPoller();
		yjsPollerInterval = setInterval(async () => {
			if (!ydoc || isDestroyed || !state.active) return;
			try {
				const resp = await fetchNui<{ updates: any[] }>(
					"pollYjsUpdates" as any,
					{},
					{ updates: [] },
					2000,
				);
				if (!resp?.updates || resp.updates.length === 0) return;
				if (!ydoc || isDestroyed) return;

				const allDecoded: Uint8Array[] = [];
				for (const batch of resp.updates) {
					if (batch.updates && Array.isArray(batch.updates)) {
						for (const item of batch.updates) {
							const b64 = typeof item === "string" ? item : item.update;
							if (b64) allDecoded.push(base64ToUint8(b64));
						}
					} else if (batch.update) {
						allDecoded.push(base64ToUint8(batch.update));
					}
				}
				if (allDecoded.length === 0) return;

				const merged = allDecoded.length === 1
					? allDecoded[0]
					: Y.mergeUpdates(allDecoded);
				Y.applyUpdate(ydoc, merged, "remote");
			} catch {
				// Ignore poll errors
			}
		}, 100);
	}

	function stopYjsPoller() {
		if (yjsPollerInterval) {
			clearInterval(yjsPollerInterval);
			yjsPollerInterval = null;
		}
	}

	function onYjsUpdate(update: Uint8Array, origin: any) {
		if (origin === "remote") return;
		if (!state.active || !state.reportId) return;
		pendingUpdates.push(update);
		if (updateFlushTimer) clearTimeout(updateFlushTimer);
		updateFlushTimer = setTimeout(flushYjsUpdates, 200);
	}

	function setupListeners() {
		useNuiEvent<any>("reportEditorJoined", (data) => {
			if (String(data.reportId) !== String(state.reportId)) return;
			if (data.editors) {
				state.editors = data.editors.filter(
					(e: CollabEditor) => e.citizenid !== myCitizenId,
				);
			} else if (data.editor) {
				const existing = state.editors.find(
					(e) => e.source === data.editor.source,
				);
				if (!existing && data.editor.citizenid !== myCitizenId) {
					state.editors = [...state.editors, data.editor];
				}
			}
			onEditorsChanged?.(state.editors);
		});

		useNuiEvent<any>("reportEditorLeft", (data) => {
			if (String(data.reportId) !== String(state.reportId)) return;
			if (data.editors) {
				state.editors = data.editors.filter(
					(e: CollabEditor) => e.citizenid !== myCitizenId,
				);
			} else {
				state.editors = state.editors.filter(
					(e) => e.source !== data.source,
				);
			}
			onEditorsChanged?.(state.editors);
		});

		startYjsPoller();

		useNuiEvent<any>("reportDataUpdate", (data) => {
			if (String(data.reportId) !== String(state.reportId)) return;
			lastRemoteData[data.dataType] = JSON.stringify(data.data);
			lastSentStructuredData[data.dataType] = JSON.stringify(data.data);
			onRemoteDataUpdate?.(data.dataType, data.data);
		});
	}

	async function joinSession(reportId: string): Promise<{
		lastContent?: string;
		lastStructuredData?: Record<string, any>;
	}> {
		ydoc = new Y.Doc();
		isDestroyed = false;
		ydoc.on("update", onYjsUpdate);

		const result = await fetchNui<{
			success: boolean;
			color?: string;
			myName?: string;
			editors?: CollabEditor[];
			lastContent?: string;
			lastStructuredData?: Record<string, any>;
			version?: number;
			yjsState?: string;
		}>(
			NUI_EVENTS.COLLAB.JOIN_REPORT_SESSION,
			{ reportId },
			{
				success: true,
				color: "#3B82F6",
				myName: "You",
				editors: [],
				version: 0,
			},
		);

		if (result?.success) {
			state.active = true;
			state.reportId = reportId;
			state.myColor = result.color || "#3B82F6";
			state.myName = result.myName || "";
			myCitizenId = (result as any).myCitizenId || "";
			state.editors = result.editors || [];
			lastRemoteData = {};
			lastSentStructuredData = {};
			onEditorsChanged?.(state.editors);

			if ((result as any).yjsState && ydoc) {
				try {
					const serverState = base64ToUint8((result as any).yjsState);
					Y.applyUpdate(ydoc, serverState, "remote");
				} catch {
					// Ignore state apply errors
				}
			}
		}

		return {
			lastContent: result?.lastContent ?? undefined,
			lastStructuredData: result?.lastStructuredData ?? undefined,
		};
	}

	async function leaveSession() {
		if (!state.active || !state.reportId) return;

		stopYjsPoller();
		if (structuredDataSyncTimer) clearTimeout(structuredDataSyncTimer);

		await fetchNui(
			NUI_EVENTS.COLLAB.LEAVE_REPORT_SESSION,
			{ reportId: state.reportId },
			{ success: true },
		);

		if (ydoc) {
			ydoc.off("update", onYjsUpdate);
			ydoc.destroy();
			ydoc = null;
		}
		isDestroyed = true;

		state.active = false;
		state.reportId = null;
		state.editors = [];
		state.myName = "";
	}

	function syncData(dataType: string, data: any) {
		if (!state.active) return;
		const serialized = JSON.stringify(data);
		if (lastRemoteData[dataType] === serialized) return;
		fireNui("syncReportData", {
			reportId: state.reportId,
			dataType,
			data,
		});
	}

	return {
		get state() {
			return state;
		},
		get isActive() {
			return state.active;
		},
		get editors() {
			return state.editors;
		},
		get myColor() {
			return state.myColor;
		},
		get myName() {
			return state.myName;
		},
		get ydoc() {
			return ydoc;
		},
		get myCitizenId() {
			return myCitizenId;
		},

		setupListeners,
		joinSession,
		leaveSession,
		syncData,

		onEditorsChanged(cb: (editors: CollabEditor[]) => void) {
			onEditorsChanged = cb;
		},
		onRemoteDataUpdate(cb: (dataType: string, data: any) => void) {
			onRemoteDataUpdate = cb;
		},
	};
}

export type CollabService = ReturnType<typeof createCollabService>;
