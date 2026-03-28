<script lang="ts">
	import { onMount, untrack } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";

	let cameras = $state<Camera[]>([]);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let groupedCameras = $state<Record<string, Camera[]>>({});
	let collapsedSections = $state<Record<string, boolean>>({});

	type Camera = {
		id: number | string;
		label: string;
		image: string;
		isOnline: boolean;
		type: string;
		viewerCount: number;
	};

	type GetCamerasResponse = {
		data?: Camera[];
		[key: string]: any;
	};

	let filteredCameras = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		return !query
			? cameras
			: cameras.filter(
					(camera) =>
						camera.label.toLowerCase().includes(query) ||
						camera.id.toString().toLowerCase().includes(query),
				);
	});

	function groupCamerasByType(cameraList: Camera[]) {
		const grouped: Record<string, Camera[]> = {};

		cameraList.forEach((camera) => {
			const type = camera.type || "Unknown";
			if (!grouped[type]) {
				grouped[type] = [];
			}
			grouped[type].push(camera);
		});

		Object.keys(grouped).forEach((type) => {
			grouped[type].sort((a, b) => a.label.localeCompare(b.label));
		});

		return grouped;
	}

	function syncCollapsedSections(types: string[]) {
		const current = collapsedSections;
		const nextState: Record<string, boolean> = { ...current };
		let changed = false;
		for (const type of types) {
			if (nextState[type] === undefined) {
				nextState[type] = false;
				changed = true;
			}
		}
		for (const key of Object.keys(nextState)) {
			if (!types.includes(key)) {
				delete nextState[key];
				changed = true;
			}
		}
		if (changed) {
			collapsedSections = nextState;
		}
	}

	function toggleSection(type: string) {
		collapsedSections = {
			...collapsedSections,
			[type]: !collapsedSections[type],
		};
	}

	function formatGroupLabel(type: string) {
		const raw = String(type || "Unknown").trim();
		if (!raw) return "Unknown Cameras";
		const withSpaces = raw.replace(/[_-]+/g, " ").replace(/\s+/g, " ");
		const titleCased = withSpaces
			.split(" ")
			.map((part) => {
				if (!part) return part;
				if (/^[0-9]+$/.test(part)) return part;
				if (part.toUpperCase() === part) return part;
				return part[0].toUpperCase() + part.slice(1).toLowerCase();
			})
			.join(" ");
		const lower = titleCased.toLowerCase();
		return /\bcameras?\b/.test(lower)
			? titleCased
			: `${titleCased} Cameras`;
	}

	async function loadCameras() {
		if (isEnvBrowser()) {
			return;
		}

		try {
			isLoading = true;
			const response = await fetchNui<GetCamerasResponse>(
				"getCameras",
				{},
				[],
			);
			cameras =
				response.data ??
				(Array.isArray(response) ? response : []) ??
				[];
			groupedCameras = groupCamerasByType(filteredCameras);
		} catch (error) {
			globalNotifications.error("Failed to load cameras");
			cameras = [];
			groupedCameras = {};
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		if (isEnvBrowser()) {
			cameras = [
				{
					id: "001",
					label: "Police Station Camera",
					image: "/images/camera-1.png",
					isOnline: true,
					type: "Government",
					viewerCount: 2,
				},
				{
					id: "002",
					label: "Police Station Camera - Inside",
					image: "/images/camera-2.png",
					isOnline: false,
					type: "Government",
					viewerCount: 0,
				},
				{
					id: "003",
					label: "Police Station Camera - Cells",
					image: "/images/camera-3.png",
					isOnline: true,
					type: "Government",
					viewerCount: 1,
				},
				{
					id: "004",
					label: "Bank Security Camera",
					image: "/images/camera-1.png",
					isOnline: false,
					type: "Bank",
					viewerCount: 0,
				},
				{
					id: "005",
					label: "24/7 Store Camera",
					image: "/images/camera-1.png",
					isOnline: false,
					type: "Store",
					viewerCount: 0,
				},
				{
					id: "006",
					label: "Hospital Emergency Camera",
					image: "/images/camera-1.png",
					isOnline: true,
					type: "Medical",
					viewerCount: 3,
				},
				{
					id: "007",
					label: "Custom Placed Camera",
					image: "...",
					isOnline: false,
					type: "Placed",
					viewerCount: 0,
				},
			];
			groupedCameras = groupCamerasByType(filteredCameras);
		} else {
			loadCameras();
		}
	});

	$effect(() => {
		const types = Object.keys(groupedCameras);
		if (!types.length) return;
		syncCollapsedSections(types);
	});

	$effect(() => {
		const grouped = groupCamerasByType(filteredCameras);
		groupedCameras = grouped;
	});

	function viewCamera(camera: any) {
		fetchNui(NUI_EVENTS.CAMERA.VIEW_CAMERA, camera.id);
	}
</script>

<div class="cameras-page">
	<div class="topbar">
		<input
			type="text"
			placeholder="Search cameras..."
			bind:value={searchQuery}
			class="search-input"
		/>
		<div class="topbar-right">
			<span class="result-count">{filteredCameras.length} camera{filteredCameras.length !== 1 ? "s" : ""}</span>
			<button
				class="btn-secondary"
				onclick={loadCameras}
				disabled={isLoading}
			>
				{isLoading ? "Loading..." : "Refresh"}
			</button>
		</div>
	</div>

	<div class="cameras-content">
		{#if isLoading && cameras.length === 0}
			<div class="empty-state">
				<div class="loading-spinner"></div>
				<p>Loading cameras...</p>
			</div>
		{:else if filteredCameras.length === 0}
			<div class="empty-state">
				<p class="empty-title">No Cameras Found</p>
				<p class="empty-sub">
					{searchQuery
						? "No cameras match your search criteria."
						: "No cameras have been loaded yet."}
				</p>
			</div>
		{:else}
			{#each Object.entries(groupedCameras).sort(([a], [b]) =>
				formatGroupLabel(a).localeCompare(formatGroupLabel(b)),
			) as [type, typeCameras]}
				<div class="camera-section">
					<!-- svelte-ignore a11y_click_events_have_key_events -->
					<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
					<div class="section-header" onclick={() => toggleSection(type)}>
						<span class="section-title">
							<span class="section-label">{formatGroupLabel(type)}</span>
							<span class="section-count">{typeCameras.length}</span>
						</span>
						<svg class="chevron" class:collapsed={collapsedSections[type]} width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
					</div>
					{#if !collapsedSections[type]}
						<div class="table-header">
							<span class="col-id">ID</span>
							<span class="col-label">Camera</span>
							<span class="col-status">Status</span>
							<span class="col-viewers">Viewers</span>
							<span class="col-action"></span>
						</div>
						{#each typeCameras as camera (camera.id)}
							<div class="camera-row">
								<span class="col-id">
									<span class="id-tag">{camera.id}</span>
								</span>
								<span class="col-label">{camera.label}</span>
								<span class="col-status">
									{#if camera.isOnline}
										<span class="pill pill-green">Online</span>
									{:else}
										<span class="pill pill-grey">Offline</span>
									{/if}
								</span>
								<span class="col-viewers">
									{#if camera.viewerCount > 0}
										<span class="viewer-count">{camera.viewerCount}</span>
									{:else}
										<span class="muted">0</span>
									{/if}
								</span>
								<span class="col-action">
									{#if camera.isOnline}
										<button class="view-btn" onclick={() => viewCamera(camera)}>
											<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
											View
										</button>
									{/if}
								</span>
							</div>
						{/each}
					{/if}
				</div>
			{/each}
		{/if}
	</div>
</div>

<style>
	.cameras-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.search-input {
		flex: 1;
		max-width: 360px;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
	}

	.search-input:focus {
		outline: none;
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.topbar-right {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
	}

	.result-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.btn-secondary {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-secondary:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-secondary:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.cameras-content {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.cameras-content::-webkit-scrollbar {
		width: 4px;
	}

	.cameras-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.cameras-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.camera-section {
		background: transparent;
		border: none;
		border-radius: 0;
		overflow: hidden;
		margin-bottom: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 16px;
		cursor: pointer;
		transition: background 0.1s;
	}

	.section-header:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.section-title {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.section-label {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
	}

	.section-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.chevron {
		color: rgba(255, 255, 255, 0.35);
		transition: transform 0.15s ease;
	}

	.chevron.collapsed {
		transform: rotate(-90deg);
	}

	.table-header {
		display: grid;
		grid-template-columns: 70px 1fr 80px 70px 80px;
		gap: 8px;
		padding: 5px 16px;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.2);
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.camera-row {
		display: grid;
		grid-template-columns: 70px 1fr 80px 70px 80px;
		gap: 8px;
		padding: 6px 16px;
		font-size: 11px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		align-items: center;
		transition: background 0.1s;
	}

	.camera-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.camera-row:last-child {
		border-bottom: none;
	}

	.col-label {
		color: rgba(255, 255, 255, 0.8);
		font-weight: 500;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-viewers {
		text-align: center;
	}

	.col-action {
		text-align: right;
	}

	.id-tag {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
	}

	.pill {
		display: inline-flex;
		align-items: center;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
	}

	.pill-green {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.pill-grey {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	.viewer-count {
		color: rgba(255, 255, 255, 0.6);
		font-weight: 500;
		font-size: 11px;
	}

	.muted {
		color: rgba(255, 255, 255, 0.15);
	}

	.view-btn {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.view-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		text-align: center;
		color: rgba(255, 255, 255, 0.35);
	}

	.empty-title {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		margin: 0 0 4px;
	}

	.empty-sub {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
