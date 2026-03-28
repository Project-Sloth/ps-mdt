<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { debugError } from "../utils/debug";
	import { isEnvBrowser } from "../utils/misc";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { AuthService } from "../services/authService.svelte";

	import ChargeType from "../components/ChargeType.svelte";

	import type { Charge, GroupedCharges } from "./../interfaces/ICharges";

	let { authService }: { authService?: AuthService } = $props();

	let charges = $state<Charge[]>([]);
	let hasLoadedCharges = $state(false);
	let searchQuery = $state("");
	let isLoading = $state(false);
	let isEditing = $state(false);

	let canEdit = $derived(authService?.hasPermission("charges_edit") ?? false);

	const collapsedState = $state({
		felony: false,
		misdemeanor: false,
		infraction: false,
	});

	let filteredCharges = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		return !query
			? charges
			: charges.filter(({ label, description, category }) =>
					[label, description, category].some((val) =>
						val.toLowerCase().includes(query),
					),
				);
	});

	let groupedCharges = $derived.by(() => {
		const grouped: GroupedCharges = {
			felony: {},
			misdemeanor: {},
			infraction: {},
		};

		if (Array.isArray(filteredCharges)) {
			for (const charge of filteredCharges) {
				const category = charge.category || "Uncategorized";
				const type = charge.type as keyof GroupedCharges;

				if (!grouped[type][category]) {
					grouped[type][category] = [];
				}

				grouped[type][category].push(charge);
			}
		}

		return grouped;
	});

	onMount(() => {
		if (isEnvBrowser()) {
			charges = [
				{
					code: "PC-001",
					label: "Speeding",
					description: "Driving over the speed limit",
					time: 0,
					fine: 250,
					type: "infraction",
					category: "Offences against Public Safety",
				},
				{
					code: "PC-002",
					label: "Simple Assault",
					description: "When a person intentionally or knowingly causes physical contact with another (without a weapon)",
					time: 7,
					fine: 500,
					type: "misdemeanor",
					category: "Offenses against persons",
				},
				{
					code: "PC-003",
					label: "Aggravated Assault",
					description: "When a person unintentionally, and recklessly causes bodily injury to another as a result of a confrontation AND causes bodily injury",
					time: 20,
					fine: 1250,
					type: "felony",
					category: "Offenses against persons",
				},
			];
		} else {
			loadCharges();
		}
	});

	function normalizeCharge(raw: Charge): Charge {
		const source = raw as Charge & { months?: number | string; fine?: number | string };
		const timeValue = Number(source.time ?? source.months ?? 0);
		const fineValue = Number(source.fine ?? 0);
		return {
			...source,
			time: Number.isFinite(timeValue) ? timeValue : 0,
			fine: Number.isFinite(fineValue) ? fineValue : 0,
		};
	}

	useNuiEvent<Charge[]>(NUI_EVENTS.CHARGE.GET_CHARGES, (data: Charge[]) => {
		const nextCharges = Array.isArray(data) ? data.map(normalizeCharge) : [];
		charges = nextCharges;
		hasLoadedCharges = true;
	});

	function toggleCollapse(type: Charge["type"]) {
		collapsedState[type] = !collapsedState[type];
	}

	async function saveChargeUpdate(charge: Charge, payload: Partial<Charge>) {
		try {
			const result = await fetchNui(NUI_EVENTS.CHARGE.UPDATE_CHARGE, {
				code: charge.code,
				label: payload.label ?? charge.label,
				fine: payload.fine ?? charge.fine,
				time: payload.time ?? charge.time,
				description: payload.description ?? charge.description,
			});
			if (result?.success) {
				charges = charges.map((item) =>
					item.code === charge.code
						? {
								...item,
								label: payload.label ?? item.label,
								fine: payload.fine ?? item.fine,
								time: payload.time ?? item.time,
								description: payload.description ?? item.description,
							}
						: item,
				);
				return true;
			}
			return false;
		} catch (error) {
			debugError("Failed to update charge:", error);
			return false;
		}
	}

	function hasCharges<K extends keyof GroupedCharges>(
		group: GroupedCharges[K],
	): boolean {
		return Object.keys(group).length > 0;
	}

	async function loadCharges() {
		try {
			isLoading = true;
			const response = await fetchNui<Charge[]>(NUI_EVENTS.CHARGE.GET_CHARGES);

			const nextCharges = Array.isArray(response)
				? response.map(normalizeCharge)
				: [];
			charges = nextCharges;
			hasLoadedCharges = true;
		} catch (error) {
			debugError("Failed to load charges:", error);
			charges = [];
		} finally {
			isLoading = false;
		}
	}

	function toggleEdit() {
		isEditing = !isEditing;
	}
</script>

<div class="charges-page">
	<div class="topbar">
		<input
			type="text"
			placeholder="Search charges..."
			bind:value={searchQuery}
			class="search-input"
		/>
		<div class="topbar-right">
			<span class="result-count">{filteredCharges.length} charge{filteredCharges.length !== 1 ? "s" : ""}</span>
			<button
				class="btn-secondary"
				onclick={loadCharges}
				disabled={isLoading}
			>
				{isLoading ? "Loading..." : "Refresh"}
			</button>
			{#if canEdit}
				<button
					class="btn-edit"
					class:active={isEditing}
					onclick={toggleEdit}
				>
					<span class="material-icons btn-edit-icon">{isEditing ? "check" : "edit"}</span>
					{isEditing ? "Done" : "Edit Charges"}
				</button>
			{/if}
		</div>
	</div>

	<div class="charges-content">
		{#if isLoading && charges.length === 0}
			<div class="empty-state">
				<div class="loading-spinner"></div>
				<p>Loading charges...</p>
			</div>
		{:else if filteredCharges.length === 0}
			<div class="empty-state">
				<p class="empty-title">No Charges Found</p>
				<p class="empty-sub">
					{searchQuery
						? "No charges match your search criteria."
						: "No charges have been loaded yet."}
				</p>
			</div>
		{:else}
			{#if hasCharges(groupedCharges.felony)}
				<ChargeType
					type="felony"
					groupedCharges={groupedCharges.felony}
					collapsed={collapsedState.felony}
					onToggle={() => toggleCollapse("felony")}
					colorClass="felony"
					onUpdate={saveChargeUpdate}
					{isEditing}
				/>
			{/if}

			{#if hasCharges(groupedCharges.misdemeanor)}
				<ChargeType
					type="misdemeanor"
					groupedCharges={groupedCharges.misdemeanor}
					collapsed={collapsedState.misdemeanor}
					onToggle={() => toggleCollapse("misdemeanor")}
					colorClass="misdemeanor"
					onUpdate={saveChargeUpdate}
					{isEditing}
				/>
			{/if}

			{#if hasCharges(groupedCharges.infraction)}
				<ChargeType
					type="infraction"
					groupedCharges={groupedCharges.infraction}
					collapsed={collapsedState.infraction}
					onToggle={() => toggleCollapse("infraction")}
					colorClass="infraction"
					onUpdate={saveChargeUpdate}
					{isEditing}
				/>
			{/if}
		{/if}
	</div>
</div>

<style>
	.charges-page {
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

	.btn-edit {
		display: inline-flex;
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

	.btn-edit:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-edit.active {
		background: rgba(var(--accent-rgb), 0.06);
		border-color: rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.btn-edit-icon {
		font-size: 12px;
	}

	.charges-content {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.charges-content::-webkit-scrollbar {
		width: 4px;
	}

	.charges-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.charges-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
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
