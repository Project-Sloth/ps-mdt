<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { AuthService } from "../services/authService.svelte";

	interface CivilianProfile {
		citizenid: string;
		firstName: string;
		lastName: string;
		gender: string;
		dob: string;
		phone: string;
		fingerprint?: string;
		dna?: string;
		image?: string;
		arrests: number;
		activeWarrants?: any[];
		activeBolos?: any[];
		linkedReports?: any[];
		ownedVehicles?: any[];
		weapons?: any[];
		licenses?: { driver: boolean; weapon: boolean };
		customLicenses?: any[];
	}

	interface Charge {
		code: string;
		label: string;
		description: string;
		time: number;
		fine: number;
		type: string;
		category: string;
	}

	let { authService }: { authService: AuthService } = $props();

	let activeTab = $state<"profile" | "legislation">("profile");
	let profile = $state<CivilianProfile | null>(null);
	let charges = $state<Charge[]>([]);
	let loadingProfile = $state(true);
	let loadingCharges = $state(true);
	let searchQuery = $state("");

	let playerName = $derived(profile ? `${profile.firstName} ${profile.lastName}` : "Loading...");

	let filteredCharges = $derived(() => {
		if (!searchQuery.trim()) return charges;
		const q = searchQuery.toLowerCase();
		return charges.filter(c =>
			c.label.toLowerCase().includes(q) ||
			c.description.toLowerCase().includes(q) ||
			c.code.toLowerCase().includes(q)
		);
	});

	let chargesByType = $derived(() => {
		const grouped: Record<string, Charge[]> = { felony: [], misdemeanor: [], infraction: [] };
		for (const c of filteredCharges()) {
			const t = c.type || "infraction";
			if (!grouped[t]) grouped[t] = [];
			grouped[t].push(c);
		}
		return grouped;
	});

	onMount(async () => {
		await Promise.all([loadProfile(), loadCharges()]);
	});

	async function loadProfile() {
		loadingProfile = true;
		try {
			const result = await fetchNui<{ success: boolean; profile?: CivilianProfile }>(
				NUI_EVENTS.CIVILIAN.GET_MY_PROFILE,
				{},
				{
					success: true,
					profile: {
						citizenid: "ABC123", firstName: "John", lastName: "Doe",
						gender: "Male", dob: "1990-01-01", phone: "555-0100",
						arrests: 0, activeWarrants: [], linkedReports: [],
						ownedVehicles: [], weapons: [],
						licenses: { driver: true, weapon: false }, customLicenses: []
					}
				},
			);
			if (result?.success && result.profile) {
				profile = result.profile;
			}
		} catch { /* silent */ }
		finally { loadingProfile = false; }
	}

	async function loadCharges() {
		loadingCharges = true;
		try {
			const result = await fetchNui<Charge[]>(
				NUI_EVENTS.CHARGE.GET_CHARGES,
				{},
				[],
			);
			charges = result || [];
		} catch { charges = []; }
		finally { loadingCharges = false; }
	}

	function closeTerminal() {
		fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI);
	}

	const TYPE_LABELS: Record<string, string> = {
		felony: "Felony",
		misdemeanor: "Misdemeanor",
		infraction: "Infraction",
	};

	const TYPE_COLORS: Record<string, string> = {
		felony: "rgba(239, 68, 68, 0.8)",
		misdemeanor: "rgba(234, 179, 8, 0.8)",
		infraction: "rgba(34, 197, 94, 0.8)",
	};
</script>

<div class="civilian-view">
	<div class="civ-header">
		<div class="civ-header-left">
			<span class="material-icons civ-icon">person</span>
			<span class="civ-title">{playerName}</span>
			<span class="civ-badge">Civilian Access</span>
		</div>
		<div class="civ-tabs">
			<button class="civ-tab" class:active={activeTab === "profile"} onclick={() => activeTab = "profile"}>
				<span class="material-icons tab-icon">badge</span> My Profile
			</button>
			<button class="civ-tab" class:active={activeTab === "legislation"} onclick={() => activeTab = "legislation"}>
				<span class="material-icons tab-icon">gavel</span> Legislation
			</button>
		</div>
		<button class="close-btn" onclick={closeTerminal}>
			<span class="material-icons">close</span>
		</button>
	</div>

	<div class="civ-content">
		{#if activeTab === "profile"}
			{#if loadingProfile}
				<div class="loading-state">
					<div class="spinner"></div>
					<span>Loading profile...</span>
				</div>
			{:else if !profile}
				<div class="empty-state">
					<span class="material-icons">error_outline</span>
					<span>Could not load your profile</span>
				</div>
			{:else}
				<div class="profile-layout">
					<div class="profile-sidebar">
						<div class="profile-card">
							<div class="profile-avatar">
								{#if profile.image}
									<img src={profile.image} alt="Profile" class="avatar-img" />
								{:else}
									<span class="material-icons avatar-icon">person</span>
								{/if}
							</div>
							<h2 class="profile-name">{profile.firstName} {profile.lastName}</h2>
							<span class="profile-cid">{profile.citizenid}</span>
						</div>

						<div class="info-section">
							<div class="info-row"><span class="info-label">Gender</span><span class="info-value">{profile.gender}</span></div>
							<div class="info-row"><span class="info-label">Date of Birth</span><span class="info-value">{profile.dob}</span></div>
							<div class="info-row"><span class="info-label">Phone</span><span class="info-value">{profile.phone}</span></div>
							<div class="info-row"><span class="info-label">Fingerprint</span><span class="info-value">{profile.fingerprint || 'N/A'}</span></div>
							<div class="info-row"><span class="info-label">DNA</span><span class="info-value">{profile.dna || 'N/A'}</span></div>
							<div class="info-row"><span class="info-label">Arrests</span><span class="info-value">{profile.arrests}</span></div>
						</div>

						<div class="info-section">
							<h3 class="section-title">Licenses</h3>
							<div class="info-row">
								<span class="info-label">Driver</span>
								<span class="info-value license" class:active={profile.licenses?.driver}>{profile.licenses?.driver ? 'Active' : 'None'}</span>
							</div>
							<div class="info-row">
								<span class="info-label">Weapon</span>
								<span class="info-value license" class:active={profile.licenses?.weapon}>{profile.licenses?.weapon ? 'Active' : 'None'}</span>
							</div>
							{#if profile.customLicenses && profile.customLicenses.length > 0}
								{#each profile.customLicenses as lic}
									<div class="info-row">
										<span class="info-label">{lic.name}</span>
										<span class="info-value license" class:active={lic.active}>{lic.active ? 'Active' : 'None'}</span>
									</div>
								{/each}
							{/if}
						</div>
					</div>

					<div class="profile-main">
						{#if profile.activeWarrants && profile.activeWarrants.length > 0}
							<div class="section-card danger">
								<h3 class="section-header"><span class="material-icons">warning</span> Active Warrants</h3>
								{#each profile.activeWarrants as warrant}
									<div class="list-item">
										<span class="item-id">Report #{warrant.reportid}</span>
										<span class="item-name">Expires: {new Date(warrant.expirydate).toLocaleDateString()}</span>
									</div>
								{/each}
							</div>
						{/if}

						{#if profile.activeBolos && profile.activeBolos.length > 0}
							<div class="section-card danger">
								<h3 class="section-header"><span class="material-icons">notification_important</span> Active BOLOs</h3>
								{#each profile.activeBolos as bolo}
									<div class="list-item">
										<span class="item-id">#{bolo.reportId}</span>
										<span class="item-name">{bolo.notes || 'No details'}</span>
										<span class="item-tag">{bolo.type}</span>
									</div>
								{/each}
							</div>
						{/if}

						{#if profile.linkedReports && profile.linkedReports.length > 0}
							<div class="section-card">
								<h3 class="section-header"><span class="material-icons">description</span> Linked Reports</h3>
								{#each profile.linkedReports as report}
									<div class="list-item">
										<span class="item-id">#{report.id}</span>
										<span class="item-name">{report.title}</span>
										<span class="item-tag">{report.type}</span>
									</div>
								{/each}
							</div>
						{/if}

						{#if profile.ownedVehicles && profile.ownedVehicles.length > 0}
							<div class="section-card">
								<h3 class="section-header"><span class="material-icons">directions_car</span> Vehicles</h3>
								{#each profile.ownedVehicles as vehicle}
									<div class="list-item">
										<span class="item-id">{vehicle.plate}</span>
										<span class="item-name">{vehicle.vehicle}</span>
									</div>
								{/each}
							</div>
						{/if}

						{#if profile.weapons && profile.weapons.length > 0}
							<div class="section-card">
								<h3 class="section-header"><span class="material-icons">security</span> Registered Weapons</h3>
								{#each profile.weapons as weapon}
									<div class="list-item">
										<span class="item-id">{weapon.serial}</span>
										<span class="item-name">{weapon.weaponModel}</span>
									</div>
								{/each}
							</div>
						{/if}

						{#if !profile.activeWarrants?.length && !profile.activeBolos?.length && !profile.linkedReports?.length && !profile.ownedVehicles?.length && !profile.weapons?.length}
							<div class="empty-state">
								<span class="material-icons">check_circle</span>
								<span>No records on file</span>
							</div>
						{/if}
					</div>
				</div>
			{/if}

		{:else if activeTab === "legislation"}
			<div class="legislation-layout">
				<div class="search-bar">
					<span class="material-icons search-icon">search</span>
					<input type="text" placeholder="Search penal codes..." bind:value={searchQuery} />
				</div>

				{#if loadingCharges}
					<div class="loading-state">
						<div class="spinner"></div>
						<span>Loading penal codes...</span>
					</div>
				{:else}
					{#each Object.entries(chargesByType()) as [type, typeCharges]}
						{#if typeCharges.length > 0}
							<div class="charge-group">
								<h3 class="charge-group-title" style="color: {TYPE_COLORS[type] || '#fff'}">
									{TYPE_LABELS[type] || type} ({typeCharges.length})
								</h3>
								<div class="charge-table">
									<div class="charge-header-row">
										<span class="ch-code">Code</span>
										<span class="ch-label">Charge</span>
										<span class="ch-fine">Fine</span>
										<span class="ch-time">Jail</span>
									</div>
									{#each typeCharges as charge}
										<div class="charge-row">
											<span class="ch-code">{charge.code}</span>
											<span class="ch-label">
												<strong>{charge.label}</strong>
												{#if charge.description}
													<span class="ch-desc">{charge.description}</span>
												{/if}
											</span>
											<span class="ch-fine">${charge.fine.toLocaleString()}</span>
											<span class="ch-time">{charge.time} mo</span>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					{/each}
					{#if filteredCharges().length === 0}
						<div class="empty-state">
							<span class="material-icons">search_off</span>
							<span>No charges found</span>
						</div>
					{/if}
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.civilian-view {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--dark-bg, #111);
	}

	.civ-header {
		display: flex;
		align-items: center;
		padding: 0 20px;
		height: 44px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
		gap: 16px;
	}

	.civ-header-left {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.civ-icon { font-size: 18px; color: rgba(255, 255, 255, 0.5); }

	.civ-title {
		font-size: 13px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
	}

	.civ-badge {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		padding: 2px 8px;
		border-radius: 8px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.civ-tabs {
		display: flex;
		gap: 4px;
		margin-left: auto;
	}

	.civ-tab {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 6px 14px;
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		color: rgba(255, 255, 255, 0.4);
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.12s;
	}

	.civ-tab:hover { color: rgba(255, 255, 255, 0.6); }
	.civ-tab.active { color: rgba(255, 255, 255, 0.9); border-bottom-color: var(--accent-60); }
	.tab-icon { font-size: 14px; }

	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		transition: all 0.12s;
	}

	.close-btn:hover { color: rgba(255, 255, 255, 0.7); background: rgba(255, 255, 255, 0.04); }
	.close-btn .material-icons { font-size: 16px; }

	.civ-content {
		flex: 1;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	/* Profile Layout */
	.profile-layout {
		display: flex;
		height: 100%;
	}

	.profile-sidebar {
		width: 260px;
		min-width: 260px;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
		padding: 20px;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.profile-card {
		text-align: center;
		padding-bottom: 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		margin-bottom: 16px;
	}

	.profile-avatar {
		width: 60px;
		height: 60px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.04);
		border: 2px solid rgba(255, 255, 255, 0.08);
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 10px;
	}

	.avatar-icon { font-size: 28px; color: rgba(255, 255, 255, 0.3); }
	.avatar-img { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }

	.profile-name {
		font-size: 15px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin: 0 0 4px;
	}

	.profile-cid {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
		font-family: monospace;
	}

	.info-section {
		margin-bottom: 16px;
		padding-bottom: 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.info-section:last-child { border-bottom: none; }

	.section-title {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.5);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin: 0 0 8px;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		padding: 4px 0;
	}

	.info-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.4);
	}

	.info-value {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.75);
	}

	.info-value.license { font-weight: 500; color: rgba(239, 68, 68, 0.7); }
	.info-value.license.active { color: rgba(34, 197, 94, 0.8); }

	/* Profile Main */
	.profile-main {
		flex: 1;
		padding: 20px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 12px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.section-card {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		overflow: hidden;
	}

	.section-card.danger {
		border-color: rgba(239, 68, 68, 0.2);
		background: rgba(239, 68, 68, 0.03);
	}

	.section-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 14px;
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
		margin: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		background: rgba(255, 255, 255, 0.01);
	}

	.section-header .material-icons { font-size: 16px; color: rgba(255, 255, 255, 0.4); }
	.section-card.danger .section-header .material-icons { color: rgba(239, 68, 68, 0.7); }

	.list-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
	}

	.list-item:last-child { border-bottom: none; }

	.item-id {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
		min-width: 60px;
	}

	.item-name {
		flex: 1;
		color: rgba(255, 255, 255, 0.75);
	}

	.item-tag {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.4);
		background: rgba(255, 255, 255, 0.04);
		padding: 2px 6px;
		border-radius: 4px;
	}

	/* Legislation */
	.legislation-layout {
		padding: 20px;
	}

	.search-bar {
		position: relative;
		margin-bottom: 16px;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		font-size: 16px;
		color: rgba(255, 255, 255, 0.3);
	}

	.search-bar input {
		width: 100%;
		padding: 10px 12px 10px 38px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 13px;
		outline: none;
	}

	.search-bar input:focus { border-color: var(--accent-35); }
	.search-bar input::placeholder { color: rgba(255, 255, 255, 0.3); }

	.charge-group {
		margin-bottom: 20px;
	}

	.charge-group-title {
		font-size: 13px;
		font-weight: 600;
		margin: 0 0 8px;
		padding-bottom: 6px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.charge-table {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		overflow: hidden;
	}

	.charge-header-row {
		display: flex;
		padding: 8px 14px;
		background: rgba(255, 255, 255, 0.03);
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.charge-row {
		display: flex;
		padding: 8px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 12px;
		align-items: flex-start;
	}

	.charge-row:last-child { border-bottom: none; }
	.charge-row:hover { background: rgba(255, 255, 255, 0.02); }

	.ch-code { width: 70px; min-width: 70px; color: rgba(255, 255, 255, 0.35); font-family: monospace; font-size: 10px; }
	.ch-label { flex: 1; color: rgba(255, 255, 255, 0.8); }
	.ch-label strong { font-weight: 500; }
	.ch-desc { display: block; font-size: 10px; color: rgba(255, 255, 255, 0.35); margin-top: 2px; }
	.ch-fine { width: 80px; min-width: 80px; text-align: right; color: rgba(234, 179, 8, 0.7); font-size: 11px; }
	.ch-time { width: 60px; min-width: 60px; text-align: right; color: rgba(239, 68, 68, 0.6); font-size: 11px; }

	/* States */
	.loading-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 48px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 12px;
	}

	.empty-state .material-icons { font-size: 32px; color: rgba(255, 255, 255, 0.15); }

	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left-color: var(--accent-60);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
