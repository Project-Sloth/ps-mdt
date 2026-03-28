import type { PlayerData } from "./../interfaces/IPlayerData";
import { fetchNui } from "../utils/fetchNui";
import { debugError } from "../utils/debug";
import { TIMING } from "../constants";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type { AuthUpdateData } from "../interfaces/IUser";
import type { JobType } from "../interfaces/IUser";

export interface AuthState {
	isAuthorized: boolean;
	isCheckingAuth: boolean;
	authError: string;
	playerData: PlayerData | null;
	isLEO: boolean;
	onDuty: boolean;
	showLoadingScreen: boolean;
	showInterface: boolean;
}

export interface PlayerInfo {
	rank: string;
	firstName: string;
	lastName: string;
	id: string;
	department: string;
}

export const MOCK_AUTH_DATA: AuthUpdateData = {
	authorized: true,
	playerData: {
		citizenid: "ABC12345",
		job: {
			name: "police",
			label: "Law Enforcement",
			grade: { name: "Officer", level: 1 },
			onduty: true,
			isboss: false,
		},
		charinfo: { firstname: "Mus", lastname: "Tashe" },
		metadata: { callsign: "69-420" },
	},
	isLEO: true,
	onDuty: true,
	permissions: [],
	isBoss: true,
	jobType: 'leo',
};

/** Creates the authentication service */
export function createAuthService() {
	let isAuthorized = $state(false);
	let isCheckingAuth = $state(true);
	let authError = $state("");
	let playerData = $state<PlayerData | null>(null);
	let isLEO = $state(false);
	let onDuty = $state(false);
	let showLoadingScreen = $state(false);
	let showInterface = $state(false);
	let permissions = $state<string[]>([]);
	let isBoss = $state(false);
	let jobType = $state<JobType>('leo');
	let isCivilian = $state(false);

	const playerInfo = $derived((): PlayerInfo => {
		if (!playerData) {
			return {
				rank: "Loading...",
				firstName: "",
				lastName: "",
				id: "",
				department: "",
			};
		}

		return {
			rank: playerData.job?.grade?.name || "Unknown",
			firstName: playerData.charinfo?.firstname || "",
			lastName: playerData.charinfo?.lastname || "",
			id: playerData.metadata?.callsign || playerData.citizenid || "",
			department: playerData.job?.label || "",
		};
	});

	function getAuthErrorMessage(authorized: boolean, isLEO: boolean): string {
		if (!authorized && isLEO) {
			return "You must be on duty to access the MDT system.";
		}
		if (!isLEO) {
			return "Access Denied: Authorized Personnel Only";
		}
		return "";
	}

	function processAuthData(data: AuthUpdateData): void {
		if (!data.playerData) {
			isAuthorized = false;
			authError = "Failed to load player data.";
			return;
		}

		// Update player data
		playerData = data.playerData;
		isLEO = data.isLEO || false;
		onDuty = data.onDuty || false;
		isAuthorized = data.authorized || false;
		permissions = data.permissions || [];
		isBoss = data.isBoss || false;
		jobType = data.jobType || 'leo';
		isCivilian = data.isCivilian || false;

		// Civilians are always authorized for their limited view
		if (isCivilian) {
			isAuthorized = true;
			onDuty = true;
		}

		// Set appropriate error message
		if (!isCivilian) {
			authError = getAuthErrorMessage(
				data.authorized || false,
				data.isLEO || false,
			);
		} else {
			authError = "";
		}
	}

	/** Updates authentication state from NUI event data */
	function updateAuthState(data: AuthUpdateData): void {
		processAuthData(data);
		isCheckingAuth = false;
		handleAuthComplete();
	}

	/** Performs initial authentication check with server */
	async function checkAuth(): Promise<void> {
		try {
			isCheckingAuth = true;
			const response: AuthUpdateData = await fetchNui(
				NUI_EVENTS.AUTH.CHECK_AUTH,
				{},
				MOCK_AUTH_DATA,
			);
			processAuthData(response);
		} catch (error) {
			debugError("Auth check failed:", error);
			authError = "Failed to verify authorization.";
			isAuthorized = false;
		} finally {
			isCheckingAuth = false;
			handleAuthComplete();
		}
	}

	let loadingTimeout: ReturnType<typeof setTimeout> | null = $state(null);

	function determineUIState(
		authorized: boolean,
		isLEO: boolean,
		onDuty: boolean,
	): {
		showInterface: boolean;
		showLoadingScreen: boolean;
	} {
		// Authorized and on duty - show main interface
		if (authorized && onDuty) {
			return { showInterface: true, showLoadingScreen: false };
		}

		// LEO but off duty - show temporary loading screen
		if (isLEO && !onDuty) {
			return { showInterface: false, showLoadingScreen: true };
		}

		// Not LEO - hide everything
		return { showInterface: false, showLoadingScreen: false };
	}

	function clearLoadingTimeout(): void {
		if (loadingTimeout) {
			clearTimeout(loadingTimeout);
			loadingTimeout = null;
		}
	}

	/** Handles auth completion and updates UI state */
	function handleAuthComplete(): void {
		// Clear any existing timeout
		clearLoadingTimeout();

		// Determine and set UI state
		const uiState = determineUIState(isAuthorized, isLEO, onDuty);
		showInterface = uiState.showInterface;
		showLoadingScreen = uiState.showLoadingScreen;

		// If showing loading screen, set timeout to hide it
		if (showLoadingScreen) {
			loadingTimeout = setTimeout(() => {
				showLoadingScreen = false;
				loadingTimeout = null;
			}, TIMING.offDutyLoadingDuration);
		}

		// Load permissions and color config after auth succeeds
		if (isAuthorized && onDuty) {
			loadPermissions();
			loadColorConfig();
		}
	}

	/** Fetches the current player's permissions from the server */
	async function loadPermissions(): Promise<void> {
		try {
			const response = await fetchNui<{ permissions?: string[]; isBoss?: boolean }>(
				NUI_EVENTS.AUTH.GET_MY_PERMISSIONS,
				{},
				{ permissions: [], isBoss: true },
			);
			permissions = response?.permissions || [];
			isBoss = response?.isBoss || false;
		} catch (error) {
			debugError("Failed to load permissions:", error);
			// On failure, default to no permissions (safe)
			permissions = [];
			isBoss = false;
		}
	}

	/** Loads department color config and applies CSS variable overrides */
	async function loadColorConfig(): Promise<void> {
		try {
			const config = await fetchNui<{ accent?: string; accentText?: string; background?: string; cardBackground?: string; buttonPrimary?: string } | null>(
				NUI_EVENTS.SETTINGS.GET_COLOR_CONFIG,
				{},
				null,
			);
			if (config && config.accent) {
				const root = document.documentElement;
				root.style.setProperty("--accent-rgb", config.accent);
				if (config.accentText) root.style.setProperty("--accent-text-rgb", config.accentText);
				if (config.background) root.style.setProperty("--dark-bg", `rgb(${config.background})`);
				if (config.cardBackground) root.style.setProperty("--card-dark-bg", `rgb(${config.cardBackground})`);
				if (config.buttonPrimary) root.style.setProperty("--btn-primary", `rgb(${config.buttonPrimary})`);
			}
		} catch {
			// Non-critical - default CSS variables will apply
		}
	}

	/** Sends request to go on duty */
	async function goOnDuty(): Promise<void> {
		try {
			// Clear loading screen immediately when user takes action
			clearLoadingTimeout();
			showLoadingScreen = false;

			await fetchNui(NUI_EVENTS.AUTH.GO_ON_DUTY);
		} catch (error) {
			debugError("Failed to go on duty:", error);
			// Don't manipulate loading screen here - let auth updates handle UI state
		}
	}

	/** Signs user out of MDT system */
	function signOut(): void {
		try {
			clearLoadingTimeout();
			fetchNui(NUI_EVENTS.AUTH.SIGN_OUT);
		} catch (error) {
			debugError("Failed to sign out:", error);
		}
	}

	/** Closes the MDT user interface */
	function closeUI(): void {
		clearLoadingTimeout();
		fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI);
	}

	/** Check if the current user has a specific permission */
	function hasPermission(perm: string): boolean {
		if (isBoss) return true;
		return permissions.includes(perm);
	}

	/** Check if the current user has any of the given permissions */
	function hasAnyPermission(...perms: string[]): boolean {
		if (isBoss) return true;
		return perms.some((p) => permissions.includes(p));
	}

	/** Check permission without boss override (used for tab_hidden_* checks) */
	function hasRawPermission(perm: string): boolean {
		return permissions.includes(perm);
	}

	return {
		// State
		get isAuthorized() {
			return isAuthorized;
		},
		get isCheckingAuth() {
			return isCheckingAuth;
		},
		get authError() {
			return authError;
		},
		get playerData() {
			return playerData;
		},
		get isLEO() {
			return isLEO;
		},
		get onDuty() {
			return onDuty;
		},
		get showLoadingScreen() {
			return showLoadingScreen;
		},
		get showInterface() {
			return showInterface;
		},
		get playerInfo() {
			return playerInfo;
		},
		get permissions() {
			return permissions;
		},
		get isBoss() {
			return isBoss;
		},
		get jobType() {
			return jobType;
		},
		get isCivilian() {
			return isCivilian;
		},

		// Actions
		/** Updates authentication state from NUI event data */
		updateAuthState,

		/** Performs initial authentication check with server */
		checkAuth,

		/** Handles auth completion and updates UI state */
		handleAuthComplete,

		/** Sends request to go on duty */
		goOnDuty,

		/** Signs user out of MDT system */
		signOut,

		/** Closes the MDT user interface */
		closeUI,

		/** Check if the current user has a specific permission */
		hasPermission,

		/** Check if the current user has any of the given permissions */
		hasAnyPermission,

		hasRawPermission,
	};
}

export interface AuthService {
	// State getters
	readonly isAuthorized: boolean;
	readonly isCheckingAuth: boolean;
	readonly authError: string;
	readonly playerData: PlayerData | null;
	readonly isLEO: boolean;
	readonly onDuty: boolean;
	readonly showLoadingScreen: boolean;
	readonly showInterface: boolean;
	readonly playerInfo: () => PlayerInfo;
	readonly permissions: string[];
	readonly isBoss: boolean;
	readonly jobType: JobType;
	readonly isCivilian: boolean;

	// Actions
	updateAuthState: (data: AuthUpdateData) => void;
	checkAuth: () => Promise<void>;
	handleAuthComplete: () => void;
	goOnDuty: () => Promise<void>;
	signOut: () => void;
	closeUI: () => void;
	hasPermission: (perm: string) => boolean;
	hasAnyPermission: (...perms: string[]) => boolean;
	hasRawPermission: (perm: string) => boolean;
}

export type AuthServiceType = ReturnType<typeof createAuthService>;
