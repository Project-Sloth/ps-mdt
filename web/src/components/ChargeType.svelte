<script lang="ts">
	import type { Charge } from "./../interfaces/ICharges";

	interface Props {
		type: Charge["type"];
		groupedCharges: Record<string, Charge[]>;
		collapsed: boolean;
		onToggle: () => void;
		onUpdate: (charge: Charge, payload: Partial<Charge>) => Promise<boolean>;
		colorClass?: string;
		isEditing?: boolean;
	}

	let {
		type,
		groupedCharges,
		collapsed,
		onToggle,
		onUpdate,
		colorClass = "",
		isEditing = false,
	}: Props = $props();

	// Track which row is being edited (by code)
	let editingCode: string | null = $state(null);
	let editValues = $state<{
		code: string;
		label: string;
		description: string;
		fine: number;
		time: number;
	}>({ code: "", label: "", description: "", fine: 0, time: 0 });
	let isSaving = $state(false);

	function startEdit(charge: Charge) {
		editingCode = charge.code || null;
		editValues = {
			code: charge.code || "",
			label: charge.label,
			description: charge.description,
			fine: getFineValue(charge),
			time: getTimeValue(charge),
		};
	}

	function cancelEdit() {
		editingCode = null;
	}

	async function saveEdit(charge: Charge) {
		if (isSaving) return;
		isSaving = true;

		const payload: Partial<Charge> = {};
		if (editValues.label !== charge.label) payload.label = editValues.label;
		if (editValues.description !== charge.description) payload.description = editValues.description;
		if (editValues.fine !== getFineValue(charge)) payload.fine = editValues.fine;
		if (editValues.time !== getTimeValue(charge)) payload.time = editValues.time;

		// Nothing changed
		if (Object.keys(payload).length === 0) {
			editingCode = null;
			isSaving = false;
			return;
		}

		const success = await onUpdate(charge, payload);
		if (success) {
			editingCode = null;
		}
		isSaving = false;
	}

	function handleKeydown(event: KeyboardEvent, charge: Charge) {
		if (event.key === "Enter") {
			saveEdit(charge);
		} else if (event.key === "Escape") {
			cancelEdit();
		}
	}

	function getNumericValue(
		charge: Charge,
		keys: Array<"fine" | "time" | "months">
	): number {
		for (const key of keys) {
			const value = (charge as unknown as Record<string, unknown>)[key];
			const numeric = Number(value);
			if (Number.isFinite(numeric) && numeric > 0) {
				return numeric;
			}
			if (numeric === 0) {
				return 0;
			}
		}
		return 0;
	}

	function getFineValue(charge: Charge) {
		return getNumericValue(charge, ["fine"]);
	}

	function getTimeValue(charge: Charge) {
		return getNumericValue(charge, ["time", "months"]);
	}

	function getTypePillClass(): string {
		switch (type) {
			case "felony": return "pill-red";
			case "misdemeanor": return "pill-orange";
			case "infraction": return "pill-green";
			default: return "pill-grey";
		}
	}

	function formatFine(value: number): string {
		return `$${value.toLocaleString()}`;
	}

	function formatTime(value: number): string {
		if (value === 0) return "-";
		return `${value}mo`;
	}
</script>

<div class="charge-section">
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div class="section-header" onclick={onToggle}>
		<span class="section-title">
			<span class="pill {getTypePillClass()}">{type.charAt(0).toUpperCase() + type.slice(1)}s</span>
			<span class="charge-count">{Object.values(groupedCharges).reduce((a, b) => a + b.length, 0)}</span>
		</span>
		<svg class="chevron" class:collapsed width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
	</div>

	{#if !collapsed}
		{#each Object.entries(groupedCharges) as [category, chargeList]}
			<div class="category-group">
				<div class="category-label">{category}</div>
				<div class="table-header">
					<span class="col-code">Code</span>
					<span class="col-label">Charge</span>
					<span class="col-desc">Description</span>
					<span class="col-fine">Fine</span>
					<span class="col-time">Time</span>
					{#if isEditing}
						<span class="col-actions"></span>
					{/if}
				</div>
				{#each chargeList as charge (charge.code || charge.label)}
					{@const isRowEditing = isEditing && editingCode === charge.code}
					{#if isRowEditing}
						<div class="charge-row editing" onkeydown={(e) => handleKeydown(e, charge)}>
							<span class="col-code">
								<span class="code-tag">{charge.code}</span>
							</span>
							<span class="col-label">
								<input
									type="text"
									class="edit-input"
									bind:value={editValues.label}
									placeholder="Charge name"
								/>
							</span>
							<span class="col-desc">
								<input
									type="text"
									class="edit-input"
									bind:value={editValues.description}
									placeholder="Description"
								/>
							</span>
							<span class="col-fine">
								<input
									type="number"
									class="edit-input edit-number"
									bind:value={editValues.fine}
									min="0"
								/>
							</span>
							<span class="col-time">
								<input
									type="number"
									class="edit-input edit-number"
									bind:value={editValues.time}
									min="0"
								/>
							</span>
							<span class="col-actions">
								<button
									class="btn-save"
									onclick={() => saveEdit(charge)}
									disabled={isSaving}
								>
									{isSaving ? "..." : "Save"}
								</button>
								<button
									class="btn-cancel"
									onclick={cancelEdit}
									disabled={isSaving}
								>
									Cancel
								</button>
							</span>
						</div>
					{:else}
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<!-- svelte-ignore a11y_no_static_element_interactions -->
						<div
							class="charge-row"
							class:clickable={isEditing}
							onclick={() => isEditing && startEdit(charge)}
						>
							<span class="col-code">
								{#if charge.code}
									<span class="code-tag">{charge.code}</span>
								{:else}
									<span class="muted">-</span>
								{/if}
							</span>
							<span class="col-label">{charge.label}</span>
							<span class="col-desc">{charge.description}</span>
							<span class="col-fine">{formatFine(getFineValue(charge))}</span>
							<span class="col-time">{formatTime(getTimeValue(charge))}</span>
							{#if isEditing}
								<span class="col-actions">
									<span class="material-icons edit-hint-icon">edit</span>
								</span>
							{/if}
						</div>
					{/if}
				{/each}
			</div>
		{/each}
	{/if}
</div>

<style>
	.charge-section {
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

	.charge-count {
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

	.pill {
		display: inline-flex;
		align-items: center;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
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

	.category-group {
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}

	.category-label {
		padding: 6px 16px;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		background: transparent;
	}

	.table-header {
		display: grid;
		grid-template-columns: 80px 1.2fr 2fr 80px 60px;
		gap: 8px;
		padding: 5px 16px;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.2);
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.charge-row {
		display: grid;
		grid-template-columns: 80px 1.2fr 2fr 80px 60px;
		gap: 8px;
		padding: 6px 16px;
		font-size: 11px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		align-items: center;
		transition: background 0.1s;
	}

	.charge-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.charge-row.clickable {
		cursor: pointer;
	}

	.charge-row.clickable:hover {
		background: rgba(var(--accent-rgb), 0.04);
	}

	.charge-row.editing {
		background: rgba(var(--accent-rgb), 0.04);
		border-bottom: 1px solid rgba(var(--accent-rgb), 0.08);
		grid-template-columns: 80px 1.2fr 2fr 80px 60px auto;
	}

	.charge-row:last-child {
		border-bottom: none;
	}

	/* When editing or actions column visible, adjust grid */
	.table-header:has(+ .charge-row.editing),
	:global(.category-group:has(.charge-row.editing)) .table-header {
		grid-template-columns: 80px 1.2fr 2fr 80px 60px auto;
	}

	.col-label {
		color: rgba(255, 255, 255, 0.8);
		font-weight: 500;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-desc {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-fine {
		color: rgba(255, 255, 255, 0.6);
		font-weight: 500;
		font-size: 11px;
		text-align: right;
	}

	.col-time {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		text-align: right;
	}

	.col-actions {
		display: flex;
		align-items: center;
		gap: 4px;
		justify-content: flex-end;
	}

	.code-tag {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
	}

	.muted {
		color: rgba(255, 255, 255, 0.1);
	}

	.edit-hint-icon {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.15);
	}

	.charge-row.clickable:hover .edit-hint-icon {
		color: rgba(var(--accent-text-rgb), 0.5);
	}

	.edit-input {
		width: 100%;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		padding: 3px 6px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		transition: border-color 0.1s;
	}

	.edit-input:focus {
		border-color: rgba(var(--accent-rgb), 0.4);
	}

	.edit-number {
		width: 60px;
		text-align: right;
	}

	/* Hide number input spinners */
	.edit-number::-webkit-outer-spin-button,
	.edit-number::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.btn-save {
		background: rgba(16, 185, 129, 0.08);
		border: 1px solid rgba(16, 185, 129, 0.15);
		border-radius: 3px;
		padding: 2px 8px;
		color: rgba(110, 231, 183, 0.8);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.btn-save:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.15);
	}

	.btn-save:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 2px 8px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.btn-cancel:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.6);
	}

	.btn-cancel:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}
</style>
