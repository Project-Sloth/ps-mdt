import { writable } from "svelte/store";

interface MDTState {
	debugMode: boolean;
	isVisible: boolean;
	currentTab: string;
	playerData: any | null;
}

const initialState: MDTState = {
	debugMode: false,
	isVisible: false,
	currentTab: "Dashboard",
	playerData: null,
};

function init() {
	const { subscribe, set, update } = writable<MDTState>(initialState);

	return {
		subscribe,
		setDebugMode: (debugMode: boolean) =>
			update((state) => ({ ...state, debugMode })),
		setVisible: (isVisible: boolean) =>
			update((state) => ({ ...state, isVisible })),
		setCurrentTab: (currentTab: string) =>
			update((state) => ({ ...state, currentTab })),
		setPlayerData: (playerData: any) =>
			update((state) => ({ ...state, playerData })),
		reset: () => set(initialState),
	};
}

export const mdtStore = init();
