<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface ColorConfig {
		accent: string;
		accentText: string;
		background: string;
		cardBackground: string;
		buttonPrimary: string;
	}

	const DEFAULT_LEO: ColorConfig = {
		accent: "59, 130, 246",
		accentText: "147, 197, 253",
		background: "23, 23, 23",
		cardBackground: "14, 15, 15",
		buttonPrimary: "41, 158, 109",
	};

	interface Theme {
		name: string;
		config: ColorConfig;
	}

	const THEMES: Theme[] = [
		{ name: "Default Blue", config: { ...DEFAULT_LEO } },
		{ name: "LSPD Classic", config: { accent: "59, 130, 246", accentText: "147, 197, 253", background: "18, 20, 28", cardBackground: "12, 14, 22", buttonPrimary: "59, 130, 246" } },
		{ name: "BCSO Gold", config: { accent: "234, 179, 8", accentText: "253, 224, 71", background: "20, 18, 12", cardBackground: "14, 12, 8", buttonPrimary: "180, 140, 10" } },
		{ name: "State Trooper", config: { accent: "16, 185, 129", accentText: "167, 243, 208", background: "14, 22, 18", cardBackground: "8, 16, 12", buttonPrimary: "16, 185, 129" } },
		{ name: "FBI Dark", config: { accent: "100, 100, 120", accentText: "180, 180, 200", background: "12, 12, 14", cardBackground: "8, 8, 10", buttonPrimary: "80, 80, 100" } },
		{ name: "EMS Red", config: { accent: "220, 50, 50", accentText: "252, 165, 165", background: "22, 16, 16", cardBackground: "16, 10, 10", buttonPrimary: "200, 60, 60" } },
		{ name: "GTA V", config: { accent: "114, 204, 68", accentText: "180, 230, 150", background: "16, 20, 14", cardBackground: "10, 14, 8", buttonPrimary: "114, 204, 68" } },
		{ name: "GTA VI", config: { accent: "255, 90, 150", accentText: "255, 170, 200", background: "22, 14, 24", cardBackground: "16, 8, 18", buttonPrimary: "220, 70, 130" } },
		{ name: "Cyberpunk", config: { accent: "255, 205, 0", accentText: "255, 230, 100", background: "10, 10, 16", cardBackground: "6, 6, 12", buttonPrimary: "0, 200, 255" } },
		{ name: "Purple Haze", config: { accent: "139, 92, 246", accentText: "196, 181, 253", background: "18, 14, 26", cardBackground: "12, 8, 20", buttonPrimary: "139, 92, 246" } },
	];

	interface ColorField {
		key: keyof ColorConfig;
		label: string;
		description: string;
	}

	const COLOR_FIELDS: ColorField[] = [
		{ key: "accent", label: "Accent Color", description: "Main theme color used across navigation, badges, and highlights" },
		{ key: "accentText", label: "Accent Text", description: "Lighter variant used for text over dark backgrounds" },
		{ key: "background", label: "Background", description: "Primary MDT background color" },
		{ key: "cardBackground", label: "Card Background", description: "Background for cards and panels" },
		{ key: "buttonPrimary", label: "Primary Button", description: "Color for save, confirm, and primary action buttons" },
	];

	let config: ColorConfig = $state({ ...DEFAULT_LEO });
	let savedConfig: ColorConfig = $state({ ...DEFAULT_LEO });
	let isLoading = $state(false);
	let isSaving = $state(false);
	let statusMsg: { text: string; type: "success" | "error" } | null = $state(null);

	let selectedTheme: string | null = $state(null);

	let hasChanges = $derived(
		config.accent !== savedConfig.accent ||
		config.accentText !== savedConfig.accentText ||
		config.background !== savedConfig.background ||
		config.cardBackground !== savedConfig.cardBackground ||
		config.buttonPrimary !== savedConfig.buttonPrimary
	);

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMsg = { text, type };
		setTimeout(() => { statusMsg = null; }, 3000);
	}

	function rgbToHex(rgb: string): string {
		const parts = rgb.split(",").map((p) => parseInt(p.trim(), 10));
		if (parts.length !== 3 || parts.some(isNaN)) return "#3b82f6";
		return "#" + parts.map((p) => Math.max(0, Math.min(255, p)).toString(16).padStart(2, "0")).join("");
	}

	function hexToRgb(hex: string): string {
		const h = hex.replace("#", "");
		const r = parseInt(h.substring(0, 2), 16);
		const g = parseInt(h.substring(2, 4), 16);
		const b = parseInt(h.substring(4, 6), 16);
		return `${r}, ${g}, ${b}`;
	}

	function updateField(key: keyof ColorConfig, hex: string) {
		config[key] = hexToRgb(hex);
		selectedTheme = null;
		applyPreview();
	}

	function applyTheme(theme: Theme) {
		config = { ...theme.config };
		selectedTheme = theme.name;
		applyPreview();
	}

	function applyPreview() {
		const root = document.documentElement;
		root.style.setProperty("--accent-rgb", config.accent);
		root.style.setProperty("--accent-text-rgb", config.accentText);
		root.style.setProperty("--dark-bg", `rgb(${config.background})`);
		root.style.setProperty("--card-dark-bg", `rgb(${config.cardBackground})`);
		root.style.setProperty("--btn-primary", `rgb(${config.buttonPrimary})`);
	}

	function resetToSaved() {
		config = { ...savedConfig };
		selectedTheme = null;
		applyPreview();
	}

	async function revertToDefault() {
		config = { ...DEFAULT_LEO };
		selectedTheme = "Default Blue";
		applyPreview();
		await saveConfig();
	}

	async function loadConfig() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<ColorConfig | null>(
				NUI_EVENTS.SETTINGS.GET_COLOR_CONFIG,
				{},
				null,
			);
			if (response && typeof response === "object" && response.accent) {
				config = { ...DEFAULT_LEO, ...response };
				savedConfig = { ...config };
				applyPreview();
			}
		} catch (error) {
			console.error("Failed to load color config:", error);
		} finally {
			isLoading = false;
		}
	}

	async function saveConfig() {
		if (isEnvBrowser()) {
			savedConfig = { ...config };
			showStatus("Colors saved");
			return;
		}
		try {
			isSaving = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.SETTINGS.SAVE_COLOR_CONFIG,
				config,
				{ success: false },
			);
			if (result?.success) {
				savedConfig = { ...config };
				showStatus("Colors saved - applies to all officers on next MDT open");
			} else {
				showStatus(result?.message || "Failed to save colors", "error");
			}
		} catch (error) {
			console.error("Failed to save color config:", error);
			showStatus("Failed to save colors", "error");
		} finally {
			isSaving = false;
		}
	}

	onMount(() => {
		loadConfig();
	});
</script>

<div class="colors-page">
	{#if isLoading}
		<div class="colors-loading">Loading...</div>
	{:else}
		<div class="colors-body">
			<!-- Custom Colors - horizontal -->
			<div class="section">
				<span class="card-label">Custom Colors</span>
				<div class="colors-hz">
					{#each COLOR_FIELDS as field}
						<div class="color-tile">
							<input
								type="color"
								value={rgbToHex(config[field.key])}
								oninput={(e) => updateField(field.key, (e.target as HTMLInputElement).value)}
							/>
							<span class="tile-name">{field.label}</span>
							<span class="tile-desc">{field.description}</span>
						</div>
					{/each}
				</div>
			</div>

			<!-- Themes - horizontal scroll -->
			<div class="section">
				<span class="card-label">Themes</span>
				<div class="themes-hz">
					{#each THEMES as theme}
						<button
							class="theme-card"
							class:active={selectedTheme === theme.name}
							onclick={() => applyTheme(theme)}
						>
							<div class="theme-preview" style="background: rgb({theme.config.background})">
								<div class="theme-sidebar" style="background: rgb({theme.config.cardBackground})">
									<div class="theme-nav-active" style="background: rgba({theme.config.accent}, 0.25)"></div>
									<div class="theme-nav-line"></div>
									<div class="theme-nav-line"></div>
								</div>
								<div class="theme-content">
									<div class="theme-bar" style="background: rgba({theme.config.accent}, 0.3)"></div>
									<div class="theme-cards-row">
										<div class="theme-mini-card" style="background: rgb({theme.config.cardBackground}); border-color: rgba({theme.config.accent}, 0.15)">
											<div class="theme-card-dot" style="background: rgb({theme.config.accentText})"></div>
										</div>
										<div class="theme-mini-card" style="background: rgb({theme.config.cardBackground}); border-color: rgba({theme.config.accent}, 0.15)">
											<div class="theme-card-dot" style="background: rgb({theme.config.accentText})"></div>
										</div>
									</div>
									<div class="theme-btn-row">
										<div class="theme-mini-btn" style="background: rgb({theme.config.buttonPrimary})"></div>
									</div>
								</div>
							</div>
							<span class="theme-name">{theme.name}</span>
						</button>
					{/each}
				</div>
			</div>

			<!-- Preview -->
			<div class="section">
				<span class="card-label">Preview</span>
				<div class="preview-mockup" style="background: rgb({config.background})">
					<div class="mock-sidebar" style="background: rgb({config.cardBackground})">
						<div class="mock-nav-item active" style="background: rgba({config.accent}, 0.15); color: rgb({config.accentText})">
							<span class="material-icons mock-icon">dashboard</span>
							<span>Dashboard</span>
						</div>
						<div class="mock-nav-item">
							<span class="material-icons mock-icon">people</span>
							<span>Citizens</span>
						</div>
						<div class="mock-nav-item">
							<span class="material-icons mock-icon">description</span>
							<span>Reports</span>
						</div>
						<div class="mock-nav-item">
							<span class="material-icons mock-icon">folder</span>
							<span>Cases</span>
						</div>
						<div class="mock-nav-item">
							<span class="material-icons mock-icon">gavel</span>
							<span>Warrants</span>
						</div>
					</div>
					<div class="mock-main">
						<div class="mock-stats-bar" style="border-bottom: 1px solid rgba(255,255,255,0.06)">
							<div class="mock-stat">
								<span class="material-icons mock-icon" style="color: rgba({config.accent}, 0.7)">military_tech</span>
								<div class="mock-stat-text">
									<span class="mock-stat-value" style="color: rgb({config.accentText})">Sergeant</span>
									<span class="mock-stat-sub">$450/HR</span>
								</div>
							</div>
							<div class="mock-stat">
								<span class="material-icons mock-icon" style="color: rgba({config.accent}, 0.7)">description</span>
								<div class="mock-stat-text">
									<span class="mock-stat-value">12</span>
									<span class="mock-stat-sub">REPORTS</span>
								</div>
							</div>
							<div class="mock-stat">
								<span class="material-icons mock-icon" style="color: rgba({config.accent}, 0.7)">groups</span>
								<div class="mock-stat-text">
									<span class="mock-stat-value">8</span>
									<span class="mock-stat-label" style="background: rgb({config.buttonPrimary}); color: #fff; padding: 1px 4px; border-radius: 3px; font-size: 6px;">ON DUTY</span>
								</div>
							</div>
							<button class="mock-action-btn" style="background: rgba({config.accent}, 0.1); border: 1px solid rgba({config.accent}, 0.2)">
								<span class="material-icons mock-icon" style="color: rgb({config.accentText})">logout</span>
							</button>
						</div>
						<div class="mock-columns">
							<div class="mock-col">
								<div class="mock-col-header">
									<span>WARRANTS</span>
									<span class="mock-count" style="color: rgb({config.accentText})">2</span>
								</div>
								<div class="mock-list-item" style="border-left: 2px solid rgba({config.accent}, 0.5)">
									<span class="mock-item-name">Marcus Johnson</span>
									<span class="mock-item-sub">Exp. Invalid Date</span>
								</div>
								<div class="mock-list-item" style="border-left: 2px solid rgba({config.accent}, 0.5)">
									<span class="mock-item-name">James Miller</span>
									<span class="mock-item-sub">Exp. Invalid Date</span>
								</div>
							</div>
							<div class="mock-col" style="border-left: 1px solid rgba(255,255,255,0.04); border-right: 1px solid rgba(255,255,255,0.04)">
								<div class="mock-col-header">
									<span>RECENT REPORTS</span>
									<span class="mock-count" style="color: rgb({config.accentText})">3</span>
								</div>
								<div class="mock-list-item">
									<span class="mock-item-name">Armed Robbery at Fleeca</span>
									<span class="mock-item-sub">1 · Ofc. Smith · 3/21/2026</span>
								</div>
								<div class="mock-list-item">
									<span class="mock-item-name">Traffic Stop - Suspended</span>
									<span class="mock-item-sub">2 · Ofc. Johnson · 3/20/2026</span>
								</div>
							</div>
							<div class="mock-col">
								<div class="mock-col-header">
									<span>DISPATCHES</span>
									<span class="mock-count" style="color: rgb({config.accentText})">3</span>
								</div>
								<div class="mock-dispatch">
									<span class="mock-dispatch-dot" style="background: #ef4444"></span>
									<span class="mock-item-sub">· 1 hour ago</span>
								</div>
								<div class="mock-dispatch">
									<span class="mock-dispatch-dot" style="background: rgb({config.buttonPrimary})"></span>
									<span class="mock-item-sub">· 30 minutes ago</span>
								</div>
								<div class="mock-dispatch">
									<span class="mock-dispatch-dot" style="background: #ef4444"></span>
									<span class="mock-item-sub">· 5 minutes ago</span>
								</div>
							</div>
						</div>
						<div class="mock-bolos-section">
							<div class="mock-col-header">
								<span>BOLOS</span>
								<span class="mock-count" style="color: rgb({config.accentText})">2</span>
							</div>
							<div class="mock-bolo-row">
								<div class="mock-list-item" style="flex: 1">
									<span class="mock-item-name">Marcus Johnson</span>
									<span class="mock-item-sub">#RPT-001 · <span style="background: rgba({config.accent}, 0.2); color: rgb({config.accentText}); padding: 0 3px; border-radius: 2px; font-size: 6px;">citizen</span></span>
								</div>
								<div class="mock-list-item" style="flex: 1">
									<span class="mock-item-name">Black Kuruma</span>
									<span class="mock-item-sub">#RPT-003 · <span style="background: rgba({config.accent}, 0.2); color: rgb({config.accentText}); padding: 0 3px; border-radius: 2px; font-size: 6px;">vehicle</span></span>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<div class="save-bar">
		{#if hasChanges}
			<button class="btn-reset" onclick={resetToSaved}>
				<span class="material-icons btn-icon">undo</span>
				Reset
			</button>
		{/if}
		<button class="btn-save" onclick={saveConfig} disabled={isSaving || !hasChanges}>
			<span class="material-icons btn-icon">save</span>
			{isSaving ? "Saving..." : "Save Colors"}
		</button>
		<button class="btn-default" onclick={revertToDefault} disabled={isSaving}>
			<span class="material-icons btn-icon">restart_alt</span>
			Revert to Default
		</button>
		{#if statusMsg}
			<span class="save-status" class:error={statusMsg.type === "error"}>{statusMsg.text}</span>
		{/if}
	</div>
</div>

<style>
	.colors-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
	}

	.colors-loading {
		color: rgba(255, 255, 255, 0.4);
		font-size: 12px;
		padding: 20px;
	}

	.colors-body {
		flex: 1;
		overflow-y: auto;
		padding: 12px 16px;
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	.colors-body::-webkit-scrollbar {
		width: 4px;
	}

	.colors-body::-webkit-scrollbar-track {
		background: transparent;
	}

	.colors-body::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.section {
		display: flex;
		flex-direction: column;
	}

	.card-label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		margin-bottom: 8px;
		padding-bottom: 6px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	/* Custom Colors - horizontal */
	.colors-hz {
		display: flex;
		gap: 6px;
	}

	.color-tile {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 3px;
		padding: 6px 4px;
		border-radius: 4px;
		border: 1px solid rgba(255, 255, 255, 0.04);
		transition: background 0.1s;
	}

	.color-tile:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.color-tile input[type="color"] {
		width: 30px;
		height: 30px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 5px;
		cursor: pointer;
		padding: 2px;
		background: transparent;
	}

	.color-tile input[type="color"]::-webkit-color-swatch-wrapper {
		padding: 0;
	}

	.color-tile input[type="color"]::-webkit-color-swatch {
		border: none;
		border-radius: 4px;
	}

	.tile-name {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
		text-align: center;
		white-space: nowrap;
	}

	.tile-desc {
		font-size: 8px;
		color: rgba(255, 255, 255, 0.3);
		text-align: center;
		line-height: 1.2;
	}

	/* Themes - wrapping horizontal */
	.themes-hz {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
	}

	.theme-card {
		display: flex;
		flex-direction: column;
		gap: 0;
		padding: 0;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.15s;
		overflow: hidden;
		flex-shrink: 0;
		width: 120px;
	}

	.theme-card:hover {
		border-color: rgba(255, 255, 255, 0.15);
	}

	.theme-card.active {
		border-color: rgba(var(--accent-rgb), 0.5);
		box-shadow: 0 0 0 1px rgba(var(--accent-rgb), 0.2);
	}

	.theme-preview {
		display: flex;
		height: 52px;
		overflow: hidden;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.theme-sidebar {
		width: 28px;
		padding: 6px 4px;
		display: flex;
		flex-direction: column;
		gap: 3px;
		border-right: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.theme-nav-active {
		height: 5px;
		border-radius: 2px;
	}

	.theme-nav-line {
		height: 4px;
		border-radius: 2px;
		background: rgba(255, 255, 255, 0.06);
	}

	.theme-content {
		flex: 1;
		padding: 6px 8px;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.theme-bar {
		height: 4px;
		border-radius: 2px;
		width: 60%;
	}

	.theme-cards-row {
		display: flex;
		gap: 3px;
		flex: 1;
	}

	.theme-mini-card {
		flex: 1;
		border-radius: 2px;
		border: 1px solid;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.theme-card-dot {
		width: 4px;
		height: 4px;
		border-radius: 50%;
	}

	.theme-btn-row {
		display: flex;
	}

	.theme-mini-btn {
		height: 5px;
		width: 20px;
		border-radius: 2px;
	}

	.theme-name {
		font-size: 9px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.6);
		padding: 2px 6px 5px;
		text-align: left;
	}

	.theme-card.active .theme-name {
		color: rgba(255, 255, 255, 0.9);
	}

	/* Preview mockup */
	.preview-mockup {
		display: flex;
		border-radius: 6px;
		border: 1px solid rgba(255, 255, 255, 0.08);
		overflow: hidden;
		height: 180px;
	}

	.mock-icon {
		font-size: 12px !important;
	}

	.mock-sidebar {
		width: 90px;
		padding: 6px 4px;
		display: flex;
		flex-direction: column;
		gap: 1px;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.mock-nav-item {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 4px 6px;
		border-radius: 3px;
		font-size: 8px;
		color: rgba(255, 255, 255, 0.35);
		font-weight: 500;
	}

	.mock-nav-item.active {
		font-weight: 600;
	}

	.mock-main {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.mock-stats-bar {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 6px 10px;
		flex-shrink: 0;
	}

	.mock-stat {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.mock-stat-text {
		display: flex;
		flex-direction: column;
	}

	.mock-stat-value {
		font-size: 8px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
	}

	.mock-stat-sub {
		font-size: 6px;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
	}

	.mock-stat-label {
		font-size: 6px;
		font-weight: 600;
	}

	.mock-action-btn {
		margin-left: auto;
		width: 22px;
		height: 22px;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: default;
	}

	.mock-columns {
		display: flex;
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}

	.mock-col {
		flex: 1;
		padding: 6px 8px;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.mock-col-header {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 7px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.4);
		letter-spacing: 0.5px;
		text-transform: uppercase;
		padding-bottom: 4px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.mock-count {
		font-size: 7px;
		font-weight: 700;
	}

	.mock-list-item {
		display: flex;
		flex-direction: column;
		gap: 1px;
		padding: 3px 6px;
	}

	.mock-item-name {
		font-size: 8px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.75);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.mock-item-sub {
		font-size: 7px;
		color: rgba(255, 255, 255, 0.3);
	}

	.mock-dispatch {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 3px 6px;
	}

	.mock-dispatch-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.mock-bolos-section {
		padding: 4px 8px 6px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.mock-bolo-row {
		display: flex;
		gap: 8px;
	}

	/* Save bar */
	.save-bar {
		display: flex;
		align-items: center;
		gap: 10px;
		flex-shrink: 0;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.btn-save {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-save:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-save:disabled {
		opacity: 0.35;
		cursor: not-allowed;
	}

	.btn-reset {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-reset:hover {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.7);
	}

	.btn-default {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(239, 68, 68, 0.06);
		border: 1px solid rgba(239, 68, 68, 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(252, 165, 165, 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		margin-left: auto;
	}

	.btn-default:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.12);
		color: rgba(252, 165, 165, 0.9);
	}

	.btn-default:disabled {
		opacity: 0.35;
		cursor: not-allowed;
	}

	.btn-icon {
		font-size: 13px;
	}

	.save-status {
		font-size: 10px;
		color: rgba(110, 231, 183, 0.8);
		animation: fadeIn 0.2s ease-out;
	}

	.save-status.error {
		color: rgba(239, 68, 68, 0.8);
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}
</style>
