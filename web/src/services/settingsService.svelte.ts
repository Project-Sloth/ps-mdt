import { fetchNui } from "@/utils/fetchNui";
import { NUI_EVENTS } from "@/constants/nuiEvents";
import { debugError } from "@/utils/debug";

export interface ColorConfig {
	accent: string;
	accentText: string;
	background: string;
	cardBackground: string;
	buttonPrimary: string;
}

export function createSettingsService() {
	let colorConfig = $state<ColorConfig | null>(null);
	let isLoading = $state(false);
	let error = $state<string | null>(null);

	function applyThemeColors(config: ColorConfig) {
		const root = document.documentElement;
		if (config.accent)
			root.style.setProperty("--accent-rgb", config.accent);
		if (config.accentText)
			root.style.setProperty("--accent-text-rgb", config.accentText);
		if (config.background)
			root.style.setProperty("-dark-bg", config.background);
		if (config.cardBackground)
			root.style.setProperty("--card-dark-bg", config.cardBackground);
		if (config.buttonPrimary)
			root.style.setProperty("--btn-primary", config.buttonPrimary);
	}

	async function loadColorConfig(): Promise<void> {
		if (isLoading) return;
		try {
			isLoading = true;
			error = null;
			const config = await fetchNui<ColorConfig | null>(
				NUI_EVENTS.SETTINGS.GET_COLOR_CONFIG,
				{},
				null,
			);

			if (config && config.accent) {
				colorConfig = config;
				applyThemeColors(config);
			}
		} catch (err) {
			error = "Failed to load color config";
			debugError("Failed to load color config:", err);
		} finally {
			isLoading = false;
		}
	}

	function setColorConfig(config: ColorConfig): void {
		colorConfig = config;
		applyThemeColors(config);
	}

	return {
		get colorConfig() {
			return colorConfig;
		},
		get isLoading() {
			return isLoading;
		},
		get error() {
			return error;
		},
		loadColorConfig,
		setColorConfig,
	};
}

export const settingsService = createSettingsService();
