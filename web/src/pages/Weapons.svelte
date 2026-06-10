<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import Pagination from "../components/Pagination.svelte";

	interface Weapon {
		id: number;
		serial: string;
		scratched: boolean;
		owner: string;
		information: string;
		weaponClass: string;
		weaponModel: string;
		name: string;
		image: string;
		type: string;
		seenIn: number;
		flags: string[];
		tint: string;
	}

	interface WeaponHistoryEntry {
		id: number;
		serial: string;
		owner: string | null;
		weapon_model: string | null;
		weapon_class: string | null;
		information: string | null;
		changed_by: string | null;
		reason: string | null;
		created_at: string;
	}

	let weapons = $state<Weapon[]>([]);
	let searchQuery = $state("");
	let loading = $state(false);
	let selectedWeapon = $state<Weapon | null>(null);
	let weaponHistory = $state<WeaponHistoryEntry[]>([]);
	let historyLoading = $state(false);

	let weaponPage = $state(1);
	let weaponPerPage = $state(25);

	let allFilteredWeapons = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		return !query
			? weapons
			: weapons.filter(
					({ serial, owner, weaponClass, name, type, tint }) =>
						[serial, owner, weaponClass, name, type, tint].some(
							(val) => val?.toLowerCase().includes(query),
						),
				);
	});

	let filteredWeapons = $derived.by(() => {
		const start = (weaponPage - 1) * weaponPerPage;
		return allFilteredWeapons.slice(start, start + weaponPerPage);
	});

	$effect(() => {
		searchQuery;
		weaponPage = 1;
	});

	function getFlagClass(flag: string): string {
		switch (flag) {
			case "Active Warrant":
			case "Dangerous":
				return "pill pill-red";
			case "Bolo":
			case "Flight Risk":
				return "pill pill-orange";
			default:
				return "pill pill-grey";
		}
	}

	async function viewWeapon(weaponId: number) {
		const weapon = weapons.find((item) => item.id === weaponId) || null;
		selectedWeapon = weapon;
		weaponHistory = [];
		if (!weapon || !weapon.serial) return;
		if (isEnvBrowser()) {
			weaponHistory = [
				{ id: 1, serial: weapon.serial, owner: weapon.owner, weapon_model: weapon.weaponModel, weapon_class: weapon.weaponClass, information: null, changed_by: 'System', reason: 'Registered', created_at: '2025-01-15T10:30:00Z' },
			];
			return;
		}
		historyLoading = true;
		try {
			const response = await fetchNui<WeaponHistoryEntry[]>(
				"getWeaponOwnershipHistory" as unknown as typeof NUI_EVENTS.WEAPON.GET_WEAPONS,
				{ serial: weapon.serial },
				[],
			);
			weaponHistory = Array.isArray(response) ? response : [];
		} catch (error) {
			globalNotifications.error("Failed to load weapon history");
			weaponHistory = [];
		} finally {
			historyLoading = false;
		}
	}

	function closeWeapon() {
		selectedWeapon = null;
		weaponHistory = [];
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			weapons = [
				{ id: 1, serial: 'WPN-48291', scratched: false, owner: 'Marcus Johnson', information: 'Registered service weapon', weaponClass: 'Pistol', weaponModel: 'WEAPON_PISTOL', name: 'Pistol', image: '', type: 'Handgun', seenIn: 3, flags: [], tint: 'Default' },
				{ id: 2, serial: 'WPN-73820', scratched: true, owner: 'Unknown', information: 'Serial scratched off - found at crime scene', weaponClass: 'SMG', weaponModel: 'WEAPON_SMG', name: 'SMG', image: '', type: 'Submachine Gun', seenIn: 1, flags: ['Dangerous'], tint: 'Army' },
				{ id: 3, serial: 'WPN-55194', scratched: false, owner: 'Sarah Williams', information: 'Licensed for personal protection', weaponClass: 'Pistol', weaponModel: 'WEAPON_COMBATPISTOL', name: 'Combat Pistol', image: '', type: 'Handgun', seenIn: 0, flags: [], tint: 'Default' },
				{ id: 4, serial: 'WPN-10477', scratched: false, owner: 'David Chen', information: 'Hunting rifle, valid license', weaponClass: 'Rifle', weaponModel: 'WEAPON_MUSKET', name: 'Musket', image: '', type: 'Rifle', seenIn: 2, flags: ['Bolo'], tint: 'Default' },
			];
			loading = false;
			return;
		}
		loading = true;
		try {
			const response = await fetchNui(NUI_EVENTS.WEAPON.GET_WEAPONS);
			weapons = Array.isArray(response.weapons) ? response.weapons : [];
		} catch (error) {
			globalNotifications.error("Failed to load weapons");
			weapons = [];
		}
		loading = false;
	});

	async function refreshWeapons() {
		if (isEnvBrowser()) return;
		loading = true;
		try {
			const response = await fetchNui(NUI_EVENTS.WEAPON.GET_WEAPONS);
			weapons = Array.isArray(response.weapons) ? response.weapons : [];
		} catch (error) {
			globalNotifications.error("Failed to load weapons");
			weapons = [];
		}
		loading = false;
	}
</script>

{#if selectedWeapon}
	<!-- Weapon Detail View -->
	<div class="weapons-page">
		<div class="topbar">
			<button class="back-btn" onclick={closeWeapon}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
				Back
			</button>
			<div class="topbar-info">
				<span class="topbar-name">{selectedWeapon.name}</span>
				<span class="topbar-serial">{selectedWeapon.serial}</span>
			</div>
			<div class="topbar-flags">
				{#if selectedWeapon.scratched}
					<span class="pill pill-red">Scratched</span>
				{/if}
				{#each selectedWeapon.flags as flag}
					<span class={getFlagClass(flag)}>{flag}</span>
				{/each}
			</div>
		</div>

		<div class="detail-scroll">
			<!-- Weapon Info Grid -->
			<div class="info-grid">
				<div class="info-card">
					<div class="info-card-icon">
						{#if selectedWeapon.image}
							<img src={selectedWeapon.image} alt="Weapon" class="info-card-img" />
						{:else}
							<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
						{/if}
					</div>
					<div class="info-card-body">
						<span class="info-card-label">Owner</span>
						<span class="info-card-value">{selectedWeapon.owner}</span>
					</div>
				</div>
				<div class="info-item"><span class="info-label">Serial</span><span class="info-value mono">{selectedWeapon.serial}</span></div>
				<div class="info-item"><span class="info-label">Name</span><span class="info-value">{selectedWeapon.name}</span></div>
				<div class="info-item"><span class="info-label">Class</span><span class="info-value">{selectedWeapon.weaponClass}</span></div>
				<div class="info-item"><span class="info-label">Type</span><span class="info-value">{selectedWeapon.type}</span></div>
				<div class="info-item"><span class="info-label">Tint</span><span class="info-value">{selectedWeapon.tint || 'Default'}</span></div>
				<div class="info-item"><span class="info-label">Reports</span><span class="info-value">{selectedWeapon.seenIn}</span></div>
				<div class="info-item"><span class="info-label">Scratched</span><span class="info-value" class:accent-red={selectedWeapon.scratched}>{selectedWeapon.scratched ? 'Yes' : 'No'}</span></div>
				<div class="info-item"><span class="info-label">Model</span><span class="info-value mono">{selectedWeapon.weaponModel}</span></div>
			</div>

			{#if selectedWeapon.information}
				<div class="section">
					<div class="section-title">Information</div>
					<p class="section-text">{selectedWeapon.information}</p>
				</div>
			{/if}

			{#if selectedWeapon.flags && selectedWeapon.flags.length}
				<div class="section">
					<div class="section-title">Flags</div>
					<div class="flags-row">
						{#each selectedWeapon.flags as flag}
							<span class={getFlagClass(flag)}>{flag}</span>
						{/each}
					</div>
				</div>
			{/if}

			<div class="section">
				<div class="section-title">Ownership History</div>
				{#if historyLoading}
					<div class="section-empty">Loading history...</div>
				{:else if weaponHistory.length === 0}
					<div class="section-empty">No ownership history found.</div>
				{:else}
					<div class="history-list">
						{#each weaponHistory as entry}
							<div class="history-item">
								<div class="history-item-main">
									<span class="history-owner">{entry.owner || 'Unknown'}</span>
									<span class="history-meta">
										{entry.weapon_model || ''}
										{entry.weapon_class ? ` · ${entry.weapon_class}` : ''}
									</span>
								</div>
								<div class="history-item-side">
									<span class="history-date">{new Date(entry.created_at).toLocaleDateString()}</span>
									{#if entry.reason}
										<span class="history-reason">{entry.reason}</span>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>
	</div>
{:else}
	<!-- Weapon List View -->
	<div class="weapons-page">
		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" bind:value={searchQuery} placeholder="Search by name, serial, owner, class, tint or type..." />
			</div>
			<button class="refresh-btn" onclick={refreshWeapons} disabled={loading}>
				{loading ? "Loading..." : "Refresh"}
			</button>
		</div>

		<div class="list-panel">
			<div class="list-header">
				<span class="col-name">Weapon</span>
				<span class="col-serial">Serial</span>
				<span class="col-owner">Owner</span>
				<span class="col-class">Class</span>
				<span class="col-type">Type</span>
				<span class="col-tint">Tint</span>
				<span class="col-flags">Flags</span>
			</div>
			<div class="list-body">
				{#if loading}
					<div class="empty-state">Loading weapons...</div>
				{:else if filteredWeapons.length === 0}
					<div class="empty-state">{searchQuery ? "No weapons match your search." : "No weapons found."}</div>
				{:else}
					{#each filteredWeapons as weapon}
						<button class="weapon-row" onclick={() => viewWeapon(weapon.id)}>
							<span class="col-name">
								{weapon.name}
								{#if weapon.scratched}<span class="scratched-badge">Scratched</span>{/if}
							</span>
							<span class="col-serial mono">{weapon.serial}</span>
							<span class="col-owner">{weapon.owner}</span>
							<span class="col-class">{weapon.weaponClass}</span>
							<span class="col-type">{weapon.type}</span>
							<span class="col-tint">{weapon.tint || 'Default'}</span>
							<span class="col-flags">
								{#each weapon.flags as flag}
									<span class={getFlagClass(flag)}>{flag}</span>
								{/each}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Pagination
				currentPage={weaponPage}
				totalItems={allFilteredWeapons.length}
				perPage={weaponPerPage}
				onPageChange={(p) => { weaponPage = p; }}
				onPerPageChange={(pp) => { weaponPerPage = pp; weaponPage = 1; }}
			/>
		</div>
	</div>
{/if}

<style>
	/* ===== Page ===== */
	.weapons-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	/* ===== Topbar ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-info {
		display: flex;
		align-items: baseline;
		gap: 8px;
	}

	.topbar-name {
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		font-weight: 600;
	}

	.topbar-serial {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-family: monospace;
	}

	.topbar-flags {
		display: flex;
		gap: 4px;
		margin-left: auto;
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 5px;
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

	.back-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		flex: 1;
		max-width: 400px;
		color: rgba(255, 255, 255, 0.2);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.refresh-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		margin-left: auto;
	}

	.refresh-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.refresh-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ===== List Panel ===== */
	.list-panel {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		background: transparent;
		border: none;
		border-radius: 0;
	}

	.list-header {
		display: grid;
		grid-template-columns: 1.8fr 1fr 1.5fr 0.8fr 0.9fr 0.7fr 1.2fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		flex-shrink: 0;
	}

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.list-body::-webkit-scrollbar { width: 4px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.weapon-row {
		display: grid;
		grid-template-columns: 1.8fr 1fr 1.5fr 0.8fr 0.9fr 0.7fr 1.2fr;
		gap: 8px;
		padding: 7px 16px;
		align-items: center;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		cursor: pointer;
		transition: background 0.1s;
		width: 100%;
		text-align: left;
		font: inherit;
		color: inherit;
	}

	.weapon-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.weapon-row:last-child {
		border-bottom: none;
	}

	.col-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.scratched-badge {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
		padding: 1px 5px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		flex-shrink: 0;
	}

	.col-serial {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.col-owner {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-class, .col-type, .col-tint {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
	}

	.col-flags { display: flex; gap: 4px; flex-wrap: wrap; }

	.mono { font-family: monospace; letter-spacing: 0.5px; }

	/* ===== Pills ===== */
	.pill {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		white-space: nowrap;
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.pill-orange {
		background: rgba(249, 115, 22, 0.08);
		color: rgba(253, 186, 116, 0.8);
		border: 1px solid rgba(249, 115, 22, 0.1);
	}

	.pill-grey {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	/* ===== Empty State ===== */
	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 300px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	/* ===== Detail View ===== */
	.detail-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.detail-scroll::-webkit-scrollbar { width: 4px; }
	.detail-scroll::-webkit-scrollbar-track { background: transparent; }
	.detail-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	/* Info Grid */
	.info-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 0;
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.info-card {
		grid-column: 1 / -1;
		display: flex;
		align-items: center;
		gap: 12px;
		padding-bottom: 10px;
		margin-bottom: 8px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.info-card-icon {
		width: 36px;
		height: 36px;
		border-radius: 3px;
		background: rgba(255, 255, 255, 0.03);
		display: flex;
		align-items: center;
		justify-content: center;
		color: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
		overflow: hidden;
	}

	.info-card-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.info-card-body {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.info-card-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.info-card-value {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 600;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 3px;
		padding: 8px 8px 8px 0;
	}

	.info-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.info-value {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 500;
	}

	.info-value.mono { font-family: monospace; letter-spacing: 0.5px; font-size: 10px; }

	.accent-red { color: rgba(252, 165, 165, 0.8) !important; }

	/* ===== Sections ===== */
	.section {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.section-title {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 8px;
	}

	.section-text {
		margin: 0;
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		line-height: 1.5;
	}

	.section-empty {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		text-align: center;
		padding: 16px;
	}

	.flags-row {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	/* ===== History ===== */
	.history-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.history-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
		padding: 8px 0;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.history-item:last-child {
		border-bottom: none;
	}

	.history-item-main {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.history-owner {
		color: rgba(255, 255, 255, 0.75);
		font-size: 11px;
		font-weight: 500;
	}

	.history-meta {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.history-item-side {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 1px;
	}

	.history-date {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.history-reason {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}
</style>
