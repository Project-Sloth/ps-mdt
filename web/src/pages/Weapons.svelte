<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import Pagination from "../components/Pagination.svelte";
	import type { createTabService } from "../services/tabService.svelte";
	import type { SearchResult } from "../interfaces/IReportEditor";
	import PersonSearchModal from "../components/report-editor/PersonSearchModal.svelte";
	import { createSearchService } from "../services/searchService.svelte";
	import type { AuthService } from "../services/authService.svelte";

	interface WeaponFlag {
		type: string;
		info: string;
	}

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
		flags: WeaponFlag[];
		tint: string;
	}

	interface WeaponHistoryEntry {
		id: number;
		serial: string;
		owner: string | null;
		owner_name?: string;
		changed_by_name?: string;
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

	let newFlag = $state({ type: "", info: "" });
	const PRESET_FLAGS = ["Stolen", "Wanted"];
	
	const FLAG_TEMPLATES: Record<string, string> = {
		"Stolen": "Reported stolen on [DATE] by [NAME].",
		"Wanted": "Wanted in connection with [CASE/REASON] as of [DATE].",
	};
	let weaponPage = $state(1);
	let weaponPerPage = $state(25);

	// ── Add Weapon modal ──
	let showAddWeaponModal = $state(false);
	let showWeaponOwnerSearch = $state(false);
	
	interface Props {
		tabService: ReturnType<typeof createTabService>;
		authService: AuthService;
	}

	let { tabService, authService }: Props = $props();

	let canAddWeapon = $derived(authService?.hasPermission('weapons_add') ?? false);

	let weaponOptions = $state<{ model: string; label: string }[]>([]);
	let addWeaponForm = $state({
		weaponModel: "",
		serial: "",
		owner: "",      // citizenid
		ownerName: "",  // display name
		notes: "The weapon was purchased on [DATE] in [PLACE].",
	});
	const searchService = createSearchService();

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

	function onFlagTypeChange() {
		newFlag.info = FLAG_TEMPLATES[newFlag.type] ?? "";
	}

	function getFlagClass(flag: WeaponFlag): string {
		switch (flag.type) {
			case "Stolen":
			case "Wanted":
				return "pill pill-red";
			default:
				return "pill pill-grey";
		}
	}

	async function handleWeaponOwnerSearch(query: string) {
		if (!query.trim()) {
			searchService.clearResults();
			return;
		}
		try {
			await searchService.searchPlayers(query);
		} catch {
			globalNotifications.error("Search failed");
		}
	}

	function selectWeaponOwner(result: SearchResult) {
		addWeaponForm.owner = result.citizenid ?? "";
		addWeaponForm.ownerName = result.fullName ?? "";
		showWeaponOwnerSearch = false;
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
				NUI_EVENTS.WEAPON.GET_WEAPON_HISTORY,
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

	async function addFlag() {
		if (!newFlag.type || !selectedWeapon) return;

		const currentFlags = selectedWeapon.flags ?? [];
		if (currentFlags.some(f => f.type === newFlag.type)) return;

		const updated = [...currentFlags, { type: newFlag.type, info: newFlag.info.trim() }];

		if (isEnvBrowser()) {
			selectedWeapon = { ...selectedWeapon, flags: updated };
			newFlag = { type: "", info: "" };
			return;
		}

		const response = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.WEAPON.SAVE_WEAPON_FLAGS,
			{ serial: selectedWeapon.serial, flags: updated },
		);
		if (response?.success) {
			selectedWeapon = { ...selectedWeapon, flags: updated };
			newFlag = { type: "", info: "" };
		} else {
			globalNotifications.error("Failed to save flag");
		}
	}

	async function removeFlag(type: string) {
		if (!selectedWeapon) return;
		const currentFlags = selectedWeapon.flags ?? [];
		const updated = currentFlags.filter(f => f.type !== type);

		if (isEnvBrowser()) {
			selectedWeapon = { ...selectedWeapon, flags: updated };
			return;
		}

		const response = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.WEAPON.SAVE_WEAPON_FLAGS,
			{ serial: selectedWeapon.serial, flags: updated },
		);
		if (response?.success) {
			selectedWeapon = { ...selectedWeapon, flags: updated };
		} else {
			globalNotifications.error("Failed to remove flag");
		}
	}

	function closeWeapon() {
		refreshWeapons()
		selectedWeapon = null;
		weaponHistory = [];
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			weapons = [
				{ id: 1, serial: 'WPN-48291', scratched: false, owner: 'Marcus Johnson', information: 'Registered service weapon', weaponClass: 'Pistol', weaponModel: 'WEAPON_PISTOL', name: 'Pistol', image: '', type: 'Handgun', seenIn: 3, flags: [{ type: "Stolen", info: "reported Stolen" }], tint: 'Default' },
				{ id: 2, serial: 'WPN-73820', scratched: true, owner: 'Unknown', information: 'Serial scratched off - found at crime scene', weaponClass: 'SMG', weaponModel: 'WEAPON_SMG', name: 'SMG', image: '', type: 'Submachine Gun', seenIn: 1, flags: [{ type: "Stolen", info: "reported Stolen" }], tint: 'Army' },
				{ id: 3, serial: 'WPN-55194', scratched: false, owner: 'Sarah Williams', information: 'Licensed for personal protection', weaponClass: 'Pistol', weaponModel: 'WEAPON_COMBATPISTOL', name: 'Combat Pistol', image: '', type: 'Handgun', seenIn: 0, flags: [], tint: 'Default' },
				{ id: 4, serial: 'WPN-10477', scratched: false, owner: 'David Chen', information: 'Hunting rifle, valid license', weaponClass: 'Rifle', weaponModel: 'WEAPON_MUSKET', name: 'Musket', image: '', type: 'Rifle', seenIn: 2, flags: [{ type: "Wanted", info: "Found Bullets - Report #1337" }], tint: 'Default' },
			];
			loading = false;
			return;
		}
		loading = true;
		try {
			const [weaponsRes, configRes] = await Promise.all([
				fetchNui(NUI_EVENTS.WEAPON.GET_WEAPONS),
				fetchNui<{ weapons: { model: string; label: string }[] }>(NUI_EVENTS.WEAPON.GET_WEAPON_CONFIG, {}, { weapons: [] }),
			]);
			weapons = Array.isArray(weaponsRes?.weapons) ? weaponsRes.weapons : [];
			weaponOptions = configRes?.weapons ?? [];
		} catch (error) {
			globalNotifications.error("Failed to load weapons #1");
			weapons = [];
		}
		loading = false;
	});

	async function refreshWeapons() {
		if (isEnvBrowser()) return;
		loading = true;
		try {
			const response = await fetchNui(NUI_EVENTS.WEAPON.GET_WEAPONS);
			weapons = Array.isArray(response?.weapons) ? response.weapons : [];
		} catch (error) {
			globalNotifications.error("Failed to load weapons #2");
			weapons = [];
		}
		loading = false;
	}

	async function addWeapon() {
		if (!addWeaponForm.weaponModel.trim() || !addWeaponForm.serial.trim()) return;

		if (isEnvBrowser()) {
			addWeaponForm = { weaponModel: "", serial: "", owner: "", ownerName: "", notes: addWeaponForm.notes.trim() };
			showAddWeaponModal = false;
			return;
		}

		const response = await fetchNui<{ success: boolean; message?: string }>(
			NUI_EVENTS.WEAPON.SAVE_WEAPON_INFO,
			{
				serial: addWeaponForm.serial.trim(),
				owner: addWeaponForm.owner,
				weapModel: addWeaponForm.weaponModel.trim().toUpperCase(),
				notes: addWeaponForm.notes.trim(),
			}
		);

		if (response?.success) {
			globalNotifications.success("Weapon saved successfully");
			refreshWeapons()
			addWeaponForm = { weaponModel: "", serial: "", owner: "", ownerName: "", notes: addWeaponForm.notes.trim() };
			showAddWeaponModal = false;
		} else {
			globalNotifications.error(response?.message || "Failed to save weapon");
		}
	}
</script>

<PersonSearchModal
    show={showWeaponOwnerSearch}
    title="Search Owner"
    searchResults={searchService.state.results}
    onSearch={handleWeaponOwnerSearch}
    onSelect={selectWeaponOwner}
    onClose={() => (showWeaponOwnerSearch = false)}
/>

{#if showAddWeaponModal}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) showAddWeaponModal = false; }}>
        <div class="modal" role="dialog" aria-modal="true" tabindex="-1">
            <div class="modal-header">
                <h3>Add Weapon</h3>
                <button class="close-btn" aria-label="Close" onclick={() => (showAddWeaponModal = false)}>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>
            <div class="modal-body form-body">
                <div class="form-group">
                    <span class="field-label">Weapon Name</span>
					<select class="form-input form-select" bind:value={addWeaponForm.weaponModel}>
						<option value="">-- Select --</option>
						{#each weaponOptions as w}
							<option value={w.model}>{w.label}</option>
						{/each}
					</select>
                </div>
				<div class="form-group form-full">
					<span class="field-label">Serial Number</span>
					<input class="form-input" bind:value={addWeaponForm.serial} placeholder="e.g. AB-123456" />
					<span class="add-weapon-description" class:visible={addWeaponForm.serial.trim().length > 0}>
						If this serial number already exists in the database, the existing record will be updated with the new information.
					</span>
				</div>
				<div class="form-group">
					<span class="field-label">Owner</span>
					<button
						class="form-input"
						style="text-align: left; cursor: pointer;"
						onclick={() => (showWeaponOwnerSearch = true)}
					>
						{addWeaponForm.ownerName
							? `${addWeaponForm.ownerName} (${addWeaponForm.owner})`
							: "Search citizen..."}
					</button>
				</div>
                <div class="form-group form-full">
                    <span class="field-label">Notes</span>
                    <textarea class="form-input" rows="4" bind:value={addWeaponForm.notes}></textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button class="cancel-btn" onclick={() => (showAddWeaponModal = false)}>Cancel</button>
                <button class="primary-btn" onclick={addWeapon}>Add Weapon</button>
            </div>
        </div>
    </div>
{/if}

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
					<span class={getFlagClass(flag)}>{flag.type}</span>
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

			<div class="section">
				<div class="section-title">Flags</div>

				{#if selectedWeapon.flags?.length}
					<div class="flags-row" style="margin-bottom: 8px;">
						{#each selectedWeapon.flags as flag}
							<span class={getFlagClass(flag)} style="display:inline-flex;align-items:center;gap:6px;">
								<span>{flag.type}</span>
								{#if flag.info}
									<span style="opacity:0.6;font-weight:400;">— {flag.info}</span>
								{/if}
								<button class="tag-remove" onclick={() => removeFlag(flag.type)} aria-label="Remove flag">
									<svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
								</button>
							</span>
						{/each}
					</div>
				{/if}

				<div class="flag-add-row">
					<select class="form-select" bind:value={newFlag.type} onchange={onFlagTypeChange}>
						<option value="">-- Select --</option>
						{#each PRESET_FLAGS as preset}
							<option value={preset} disabled={selectedWeapon.flags?.some(f => f.type === preset)}>
								{preset}
							</option>
						{/each}
					</select>
					<input
						class="form-input"
						bind:value={newFlag.info}
						placeholder="Additional info..."
						onkeydown={(e) => { if (e.key === 'Enter') addFlag(); }}
					/>
					<button class="add-tag-btn" onclick={addFlag} disabled={!newFlag.type.trim()}>
						+ Add
					</button>
				</div>
			</div>

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
									<span class="history-owner">
										{entry.owner_name ?? entry.owner ?? 'Unknown'}
										{#if entry.owner_name && entry.owner}
											<span class="history-meta">({entry.owner})</span>
										{/if}
									</span>
									<span class="history-meta">
										- Model: {entry.weapon_model || ''}
										{entry.weapon_class ? ` · ${entry.weapon_class}` : ''}
									</span>
									{#if entry.information}
										<span class="history-meta">- Notes: {entry.information}</span>
									{/if}
								</div>
								<div class="history-item-side">
									<span class="history-date">{new Date(entry.created_at).toLocaleDateString()}</span>
									{#if entry.reason}
										<span class="history-reason">{entry.reason}</span>
									{/if}
									{#if entry.changed_by_name ?? entry.changed_by}
										<span class="history-meta">logged by {entry.changed_by_name ?? entry.changed_by}</span>
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
			{#if canAddWeapon}
				<button class="add-weapon-btn" onclick={() => (showAddWeaponModal = true)}>
					<span class="material-icons" style="font-size: 12px;">add</span> Add Weapon
				</button>
			{/if}
		</div>

		<div class="list-panel">
			<div class="list-header">
				<span></span>
				<span>Weapon</span>
				<span>Serial</span>
				<span>Owner</span>
				<span>Class</span>
				<span>Type</span>
				<span>Tint</span>
				<span>Flags</span>
			</div>
			<div class="list-body">
				{#if loading}
					<div class="empty-state">Loading weapons...</div>
				{:else if filteredWeapons.length === 0}
					<div class="empty-state">{searchQuery ? "No weapons match your search." : "No weapons found."}</div>
				{:else}
					{#each filteredWeapons as weapon}
						<button class="weapon-row" onclick={() => viewWeapon(weapon.id)}>
							<div class="weapon-avatar">
								<img src={weapon.image} alt="" />
							</div>
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
								{#each weapon.flags || [] as flag}
									<span class={getFlagClass(flag)}>{flag.type}</span>
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

	.weapon-avatar { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.04); display: grid; place-items: center; overflow: hidden; flex-shrink: 0; }
	.weapon-avatar img { width: 100%; height: 100%; object-fit: cover; }

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

	/* Add Weapon button */
	.add-weapon-btn { display: flex; align-items: center; gap: 3px; background: rgba(59,130,246,0.06); border: 1px solid rgba(59,130,246,0.1); border-radius: 3px; padding: 4px 10px; color: rgba(147,197,253,0.7); font-size: 9px; font-weight: 600; cursor: pointer; transition: all 0.12s; text-transform: none; letter-spacing: 0; }
	.add-weapon-btn:hover { background: rgba(59,130,246,0.12); color: rgba(147,197,253,0.9); }

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

	.list-header { display: grid; grid-template-columns: 24px 1.8fr 1fr 1.5fr 0.8fr 0.9fr 0.7fr 1.2fr; gap: 8px; padding: 8px 16px; border-bottom: 1px solid rgba(255,255,255,0.06); color: rgba(255,255,255,0.35); font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; flex-shrink: 0; }

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.list-body::-webkit-scrollbar { width: 4px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.weapon-row { display: grid; grid-template-columns: 24px 1.8fr 1fr 1.5fr 0.8fr 0.9fr 0.7fr 1.2fr; gap: 8px; padding: 7px 16px; align-items: center; border: none; border-bottom: 1px solid rgba(255,255,255,0.03); background: transparent; cursor: pointer; transition: background 0.1s; width: 100%; text-align: left; font: inherit; color: inherit; }


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
		width: 108px;
		height: 108px;
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

	/* ===== Tags/Flags ===== */
	.flags-row {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	.tag-remove {
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: none;
		color: inherit;
		opacity: 0.4;
		cursor: pointer;
		padding: 0;
		transition: opacity 0.1s;
		line-height: 1;
	}

	.tag-remove:hover {
		opacity: 1;
	}

	.flag-add-row {
		display: flex;
		gap: 6px;
		align-items: center;
		margin-top: 8px;
	}

	.flag-add-row .form-select {
		width: 120px;
		flex-shrink: 0;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 10px;
		font-family: inherit;
	}

	.flag-add-row .form-select:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.flag-add-row .form-input {
		flex: 1;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
	}

	.flag-add-row .form-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.flag-add-row .form-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.add-tag-btn {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.add-tag-btn:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.add-tag-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
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

	.add-weapon-description { font-size: 10px; color: rgba(255,255,255,0.35); line-height: 1.3; overflow: hidden; text-overflow: ellipsis; max-height: 0; opacity: 0; transition: max-height 0.8s ease, opacity 0.8s ease; }
	.add-weapon-description.visible { max-height: 40px; opacity: 1; }

	/* Modal shared */
	.modal-backdrop { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 999; }
	.modal { background: var(--card-dark-bg); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 6px; width: min(540px, 92vw); max-height: 85vh; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5); }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-header h3 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.85); }
	.close-btn { display: flex; align-items: center; justify-content: center; background: transparent; color: rgba(255, 255, 255, 0.3); border: 1px solid rgba(255, 255, 255, 0.06); padding: 4px; border-radius: 3px; cursor: pointer; transition: all 0.1s; }
	.close-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }

	.modal-body { padding: 14px 16px; overflow-y: auto; }
	.modal-top { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
	.modal-name { color: rgba(255, 255, 255, 0.85); font-size: 14px; font-weight: 700; }
	.modal-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 12px; }
	.modal-field { display: flex; flex-direction: column; gap: 2px; }
	.field-label { color: rgba(255, 255, 255, 0.35); font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; }
	.field-value { color: rgba(255, 255, 255, 0.7); font-size: 11px; font-weight: 500; }
	.modal-notes { background: transparent; border: none; border-top: 1px solid rgba(255, 255, 255, 0.04); border-radius: 0; padding: 10px 0 0; }
	.notes-body { margin: 4px 0 0; font-size: 11px; line-height: 1.5; color: rgba(255, 255, 255, 0.5); }

	.modal-footer { display: flex; justify-content: space-between; align-items: center; gap: 6px; padding: 10px 16px; border-top: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-footer-left { display: flex; gap: 6px; }
	.modal-footer-right { display: flex; gap: 6px; }
	.resolve-btn { display: flex; align-items: center; gap: 4px; background: rgba(34, 197, 94, 0.06); color: rgba(74, 222, 128, 0.7); border: 1px solid rgba(34, 197, 94, 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.resolve-btn:hover { background: rgba(34, 197, 94, 0.12); color: rgba(74, 222, 128, 0.9); }
	.delete-btn { display: flex; align-items: center; gap: 4px; background: transparent; color: rgba(248, 113, 113, 0.5); border: 1px solid rgba(239, 68, 68, 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.delete-btn:hover { background: rgba(239, 68, 68, 0.08); color: rgba(252, 165, 165, 0.8); }
	.action-btn { background: rgba(var(--accent-rgb), 0.06); color: rgba(var(--accent-text-rgb), 0.7); border: 1px solid rgba(var(--accent-rgb), 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.action-btn:hover { background: rgba(var(--accent-rgb), 0.12); color: rgba(var(--accent-text-rgb), 0.9); }
	.cancel-btn { background: transparent; color: rgba(255, 255, 255, 0.4); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 4px 10px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.cancel-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.primary-btn { background: rgba(16, 185, 129, 0.06); color: rgba(52, 211, 153, 0.7); border: 1px solid rgba(16, 185, 129, 0.1); border-radius: 3px; padding: 4px 12px; font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.primary-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }

	/* Form */
	.form-body { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
	.form-group { display: flex; flex-direction: column; gap: 3px; }
	.form-full { grid-column: 1 / -1; }
	.form-input { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 5px 8px; color: rgba(255, 255, 255, 0.8); font-size: 11px; transition: border-color 0.1s; font-family: inherit; }
	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }
	.form-select { padding-right: 22px; font-size: 10px; }
	textarea.form-input { resize: vertical; min-height: 60px; }
</style>