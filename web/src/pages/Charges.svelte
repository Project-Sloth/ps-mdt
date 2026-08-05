<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { debugError } from "../utils/debug";
	import { isEnvBrowser } from "../utils/misc";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { AuthService } from "../services/authService.svelte";

	import ChargeType from "../components/ChargeType.svelte";
	import SkeletonList from "../components/SkeletonList.svelte";

	import type { Charge, GroupedCharges } from "./../interfaces/ICharges";
	import { permissionHint } from "../utils/permissionHint";

	let { authService }: { authService?: AuthService } = $props();

	let charges = $state<Charge[]>([]);
	let hasLoadedCharges = $state(false);
	let searchQuery = $state("");
	let isLoading = $state(false);

	// Phase 3: full create/edit/delete modal + category management.
	type ChargeForm = {
		code: string;
		label: string;
		type: Charge["type"];
		category: string;
		fine: number;
		time: number;
		color: string;
		description: string;
	};
	let categories = $state<string[]>([]);
	let showModal = $state(false);
	let modalMode = $state<"create" | "edit">("create");
	let modalOriginalCode = $state("");
	let modalForm = $state<ChargeForm>({
		code: "", label: "", type: "misdemeanor", category: "",
		fine: 0, time: 0, color: "#6b7280", description: "",
	});
	let isSavingModal = $state(false);
	let confirmDelete = $state(false);
	let modalError = $state("");

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
		loadCategories();
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

	async function loadCategories() {
		if (isEnvBrowser()) {
			categories = ["Offenses against persons", "Offences against Public Safety"];
			return;
		}
		try {
			const res = await fetchNui<string[]>(NUI_EVENTS.CHARGE.GET_CHARGE_CATEGORIES, {}, []);
			categories = Array.isArray(res) ? res : [];
		} catch {
			categories = [];
		}
	}

	function openCreate() {
		modalMode = "create";
		modalOriginalCode = "";
		modalError = "";
		confirmDelete = false;
		modalForm = {
			code: "", label: "", type: "misdemeanor", category: "",
			fine: 0, time: 0, color: "#6b7280", description: "",
		};
		showModal = true;
	}

	function openManage(charge: Charge) {
		modalMode = "edit";
		modalOriginalCode = charge.code || "";
		modalError = "";
		confirmDelete = false;
		modalForm = {
			code: charge.code || "",
			label: charge.label,
			type: charge.type,
			category: charge.category || "",
			fine: Number(charge.fine) || 0,
			time: Number(charge.time) || 0,
			color: charge.color || "#6b7280",
			description: charge.description || "",
		};
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		confirmDelete = false;
	}

	async function saveModal() {
		modalError = "";
		const code = modalForm.code.trim();
		const label = modalForm.label.trim();
		if (!code || !label) {
			modalError = "Code and name are required.";
			return;
		}
		isSavingModal = true;
		try {
			if (modalMode === "create") {
				const res = await fetchNui<{ success: boolean; message?: string }>(
					NUI_EVENTS.CHARGE.ADD_CHARGE,
					{ ...modalForm, code, label },
				);
				if (!res?.success) {
					modalError = res?.message || "Failed to create charge.";
					return;
				}
			} else {
				const res = await fetchNui<{ success: boolean; message?: string; code?: string }>(
					NUI_EVENTS.CHARGE.UPDATE_CHARGE,
					{
						code: modalOriginalCode,
						newCode: code !== modalOriginalCode ? code : undefined,
						label,
						type: modalForm.type,
						category: modalForm.category,
						color: modalForm.color,
						fine: modalForm.fine,
						time: modalForm.time,
						description: modalForm.description,
					},
				);
				if (!res?.success) {
					modalError = res?.message || "Failed to update charge.";
					return;
				}
			}
			showModal = false;
			await loadCharges();
			await loadCategories();
		} catch (error) {
			debugError("Failed to save charge:", error);
			modalError = "Unexpected error saving charge.";
		} finally {
			isSavingModal = false;
		}
	}

	async function removeCharge(force = false) {
		isSavingModal = true;
		modalError = "";
		try {
			const res = await fetchNui<{ success: boolean; message?: string; inUse?: number }>(
				NUI_EVENTS.CHARGE.DELETE_CHARGE,
				{ code: modalOriginalCode, force },
			);
			if (!res?.success) {
				// Charge is in use — surface a confirm step instead of deleting silently.
				if (res?.inUse && !force) {
					confirmDelete = true;
					modalError = res.message || "";
					return;
				}
				modalError = res?.message || "Failed to delete charge.";
				return;
			}
			showModal = false;
			await loadCharges();
			await loadCategories();
		} catch (error) {
			debugError("Failed to delete charge:", error);
			modalError = "Unexpected error deleting charge.";
		} finally {
			isSavingModal = false;
		}
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
			<button class="add-charge-btn" use:permissionHint={canEdit ? null : "charges_edit"} onclick={openCreate}>
				<span class="material-icons" style="font-size: 12px;">add</span> New Charge
			</button>
		</div>
	</div>

	<div class="charges-content">
		{#if isLoading && charges.length === 0}
			<SkeletonList rows={9} thumb={false} columns={[2.4, 1, 0.8]} />
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
					onManage={openManage}
					canManage={canEdit}
				/>
			{/if}

			{#if hasCharges(groupedCharges.misdemeanor)}
				<ChargeType
					type="misdemeanor"
					groupedCharges={groupedCharges.misdemeanor}
					collapsed={collapsedState.misdemeanor}
					onToggle={() => toggleCollapse("misdemeanor")}
					colorClass="misdemeanor"
					onManage={openManage}
					canManage={canEdit}
				/>
			{/if}

			{#if hasCharges(groupedCharges.infraction)}
				<ChargeType
					type="infraction"
					groupedCharges={groupedCharges.infraction}
					collapsed={collapsedState.infraction}
					onToggle={() => toggleCollapse("infraction")}
					colorClass="infraction"
					onManage={openManage}
					canManage={canEdit}
				/>
			{/if}
		{/if}
	</div>
</div>

{#if showModal}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) closeModal(); }}>
		<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h3>{modalMode === "create" ? "New Charge" : "Edit Charge"}</h3>
				<button class="close-btn" aria-label="Close" onclick={closeModal}>
					<span class="material-icons" style="font-size: 14px;">close</span>
				</button>
			</div>
			<div class="modal-body form-body">
				<div class="form-group">
					<span class="field-label">Code</span>
					<input class="form-input" bind:value={modalForm.code} placeholder="PC-001" />
				</div>
				<div class="form-group">
					<span class="field-label">Class</span>
					<select class="form-input form-select" bind:value={modalForm.type}>
						<option value="felony">Felony</option>
						<option value="misdemeanor">Misdemeanor</option>
						<option value="infraction">Infraction</option>
					</select>
				</div>
				<div class="form-group form-full">
					<span class="field-label">Name</span>
					<input class="form-input" bind:value={modalForm.label} placeholder="Charge name" />
				</div>
				<div class="form-group form-full">
					<span class="field-label">Category</span>
					<input class="form-input" bind:value={modalForm.category} list="charge-category-list" placeholder="Type a new category or pick an existing one" />
					<datalist id="charge-category-list">
						{#each categories as cat}<option value={cat}></option>{/each}
					</datalist>
				</div>
				<div class="form-group">
					<span class="field-label">Fine ($)</span>
					<input class="form-input" type="number" min="0" bind:value={modalForm.fine} />
				</div>
				<div class="form-group">
					<span class="field-label">Jail (months)</span>
					<input class="form-input" type="number" min="0" bind:value={modalForm.time} />
				</div>
				<div class="form-group form-full">
					<span class="field-label">Color</span>
					<input class="form-input color-input" type="color" bind:value={modalForm.color} />
				</div>
				<div class="form-group form-full">
					<span class="field-label">Description</span>
					<textarea class="form-input" rows="3" bind:value={modalForm.description} placeholder="Description"></textarea>
				</div>
				{#if modalError}
					<div class="form-group form-full"><span class="modal-error">{modalError}</span></div>
				{/if}
			</div>
			<div class="modal-footer">
				<div class="modal-footer-left">
					{#if modalMode === "edit"}
						{#if confirmDelete}
							<button class="danger-btn" disabled={isSavingModal} onclick={() => removeCharge(true)}>Confirm delete</button>
						{:else}
							<button class="danger-ghost-btn" disabled={isSavingModal} onclick={() => removeCharge(false)}>Delete</button>
						{/if}
					{/if}
				</div>
				<div class="modal-footer-right">
					<button class="cancel-btn" disabled={isSavingModal} onclick={closeModal}>Cancel</button>
					<button class="primary-btn" disabled={isSavingModal} onclick={saveModal}>
						{isSavingModal ? "Saving..." : modalMode === "create" ? "Create" : "Save"}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.add-charge-btn {
		display: flex;
		align-items: center;
		gap: 3px;
		background: rgba(59, 130, 246, 0.06);
		border: 1px solid rgba(59, 130, 246, 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(147, 197, 253, 0.7);
		font-size: 9px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.12s;
		text-transform: none;
		letter-spacing: 0;
	}

	.add-charge-btn:hover {
		background: rgba(59, 130, 246, 0.12);
		color: rgba(147, 197, 253, 0.95);
	}

	.modal-backdrop { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 999; }
	.modal { background: var(--card-dark-bg); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 6px; width: min(540px, 92vw); max-height: 85vh; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5); }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-header h3 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.85); }
	.close-btn { display: flex; align-items: center; justify-content: center; background: transparent; color: rgba(255, 255, 255, 0.3); border: 1px solid rgba(255, 255, 255, 0.06); padding: 4px; border-radius: 3px; cursor: pointer; transition: all 0.1s; }
	.close-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.modal-body { padding: 14px 16px; overflow-y: auto; }
	.form-body { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
	.form-group { display: flex; flex-direction: column; gap: 3px; }
	.form-full { grid-column: 1 / -1; }
	.field-label { color: rgba(255, 255, 255, 0.35); font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; }
	.form-input { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 5px 8px; color: rgba(255, 255, 255, 0.8); font-size: 11px; transition: border-color 0.1s; font-family: inherit; }
	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }
	.form-select { cursor: pointer; }
	.color-input { padding: 2px; height: 28px; cursor: pointer; }
	textarea.form-input { resize: vertical; min-height: 60px; }
	.modal-error { color: #f87171; font-size: 10px; }
	.modal-footer { display: flex; justify-content: space-between; align-items: center; gap: 6px; padding: 10px 16px; border-top: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-footer-left { display: flex; gap: 6px; }
	.modal-footer-right { display: flex; gap: 6px; }
	.cancel-btn { background: transparent; color: rgba(255, 255, 255, 0.4); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 4px 10px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.cancel-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.primary-btn { background: rgba(16, 185, 129, 0.06); color: rgba(52, 211, 153, 0.7); border: 1px solid rgba(16, 185, 129, 0.1); border-radius: 3px; padding: 4px 12px; font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.primary-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }
	.primary-btn:disabled, .cancel-btn:disabled, .danger-btn:disabled, .danger-ghost-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.danger-btn { background: rgba(239, 68, 68, 0.12); color: rgba(248, 113, 113, 0.95); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 3px; padding: 4px 10px; font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.danger-ghost-btn { background: transparent; color: rgba(248, 113, 113, 0.7); border: 1px solid rgba(239, 68, 68, 0.15); border-radius: 3px; padding: 4px 10px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.danger-ghost-btn:hover { background: rgba(239, 68, 68, 0.1); color: rgba(248, 113, 113, 0.95); }

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


	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>