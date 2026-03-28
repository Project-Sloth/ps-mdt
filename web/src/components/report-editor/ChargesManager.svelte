<script lang="ts">
	import type { ReportCharge, Suspect } from "../../interfaces/IReportEditor";
	import type { Charge } from "../../interfaces/ICharges";

	interface Props {
		charges: ReportCharge[];
		suspects: Suspect[];
		penalCodes: Charge[];
		reductionOffers?: number[];
		onAddCharge: (charge: ReportCharge) => void;
		onRemoveCharge: (id: string) => void;
		onUpdateCharge: (charge: ReportCharge) => void;
		onSendToJail: (citizenid: string, months: number) => void;
		onGiveCitation: (citizenid: string, fine: number) => void;
	}

	let {
		charges,
		suspects,
		penalCodes,
		reductionOffers = [],
		onAddCharge,
		onRemoveCharge,
		onUpdateCharge,
		onSendToJail,
		onGiveCitation,
	}: Props = $props();

	let chargeSearch = $state("");
	let selectedSuspect = $state("");
	let showPicker = $state(false);

	// Reduction state
	let reductionTarget: string | null = $state(null); // citizenid of suspect being offered reduction
	let selectedReduction: number | null = $state(null);

	let filteredPenalCodes = $derived.by(() => {
		if (!chargeSearch.trim()) return penalCodes.slice(0, 20);
		const q = chargeSearch.toLowerCase();
		return penalCodes.filter(
			(c) =>
				(c.label || "").toLowerCase().includes(q) ||
				(c.description || "").toLowerCase().includes(q) ||
				(c.category || "").toLowerCase().includes(q),
		).slice(0, 20);
	});

	// Group charges by suspect
	let chargesBySuspect = $derived.by(() => {
		const map = new Map<string, ReportCharge[]>();
		for (const charge of charges) {
			const key = charge.citizenid || "unknown";
			if (!map.has(key)) map.set(key, []);
			map.get(key)!.push(charge);
		}
		return map;
	});

	// Totals
	let totalFine = $derived(charges.reduce((sum, c) => sum + c.fine * c.count, 0));
	let totalMonths = $derived(charges.reduce((sum, c) => sum + c.time * c.count, 0));

	function getSuspectName(citizenid: string): string {
		const suspect = suspects.find((s) => s.citizenid === citizenid);
		return suspect?.fullName || citizenid;
	}

	function getSuspectTotalFine(citizenid: string): number {
		return charges.filter((c) => c.citizenid === citizenid).reduce((sum, c) => sum + c.fine * c.count, 0);
	}

	function getSuspectTotalMonths(citizenid: string): number {
		return charges.filter((c) => c.citizenid === citizenid).reduce((sum, c) => sum + c.time * c.count, 0);
	}

	function getReducedFine(citizenid: string, percent: number): number {
		const full = getSuspectTotalFine(citizenid);
		return Math.round(full * (1 - percent / 100));
	}

	function getReducedMonths(citizenid: string, percent: number): number {
		const full = getSuspectTotalMonths(citizenid);
		return Math.max(1, Math.round(full * (1 - percent / 100)));
	}

	function openReduction(citizenid: string) {
		reductionTarget = citizenid;
		selectedReduction = null;
	}

	function closeReduction() {
		reductionTarget = null;
		selectedReduction = null;
	}

	function applyReductionJail() {
		if (!reductionTarget || !selectedReduction) return;
		const months = getReducedMonths(reductionTarget, selectedReduction);
		onSendToJail(reductionTarget, months);
		closeReduction();
	}

	function applyReductionFine() {
		if (!reductionTarget || !selectedReduction) return;
		const fine = getReducedFine(reductionTarget, selectedReduction);
		onGiveCitation(reductionTarget, fine);
		closeReduction();
	}

	function applyReductionBoth() {
		if (!reductionTarget || !selectedReduction) return;
		const months = getReducedMonths(reductionTarget, selectedReduction);
		const fine = getReducedFine(reductionTarget, selectedReduction);
		if (months > 0) onSendToJail(reductionTarget, months);
		if (fine > 0) onGiveCitation(reductionTarget, fine);
		closeReduction();
	}

	function addChargeFromPenal(penal: Charge) {
		if (!selectedSuspect) return;
		const suspect = suspects.find((s) => s.citizenid === selectedSuspect);
		onAddCharge({
			id: `CHG-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
			citizenid: selectedSuspect,
			suspectName: suspect?.fullName || selectedSuspect,
			charge: penal.label,
			count: 1,
			time: penal.time || 0,
			fine: penal.fine || 0,
		});
		showPicker = false;
		chargeSearch = "";
	}

	function updateCount(charge: ReportCharge, delta: number) {
		const newCount = Math.max(1, charge.count + delta);
		onUpdateCharge({ ...charge, count: newCount });
	}
</script>

<div class="charges-section">
	<div class="section-header">
		<span class="section-label">CHARGES</span>
		<div class="header-actions">
			{#if suspects.length > 0}
				<select class="suspect-select" bind:value={selectedSuspect}>
					<option value="">Select suspect...</option>
					{#each suspects as suspect}
						<option value={suspect.citizenid}>{suspect.fullName || suspect.citizenid}</option>
					{/each}
				</select>
				<button class="add-btn" onclick={() => { if (selectedSuspect) showPicker = !showPicker; }} disabled={!selectedSuspect}>
					+ Add Charge
				</button>
			{:else}
				<span class="hint-text">Add a suspect first</span>
			{/if}
		</div>
	</div>

	<!-- Charge Picker -->
	{#if showPicker}
		<div class="charge-picker">
			<input
				type="text"
				class="picker-search"
				placeholder="Search charges..."
				bind:value={chargeSearch}
			/>
			<div class="picker-list">
				{#each filteredPenalCodes as penal}
					<button class="picker-item" onclick={() => addChargeFromPenal(penal)}>
						<div class="picker-item-top">
							<span class="picker-label">{penal.label}</span>
							<span class="picker-type type-{penal.type}">{penal.type}</span>
						</div>
						<div class="picker-item-bottom">
							<span class="picker-meta">{penal.category}</span>
							<span class="picker-values">
								{#if penal.time > 0}{penal.time}mo{/if}
								{#if penal.fine && penal.fine > 0} ${penal.fine.toLocaleString()}{/if}
							</span>
						</div>
					</button>
				{/each}
				{#if filteredPenalCodes.length === 0}
					<p class="no-results">No charges found.</p>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Charges grouped by suspect -->
	{#if charges.length === 0}
		<p class="empty-text">No charges added.</p>
	{:else}
		{#each [...chargesBySuspect.entries()] as [citizenid, suspectCharges]}
			<div class="suspect-group">
				<div class="suspect-header">
					<span class="suspect-name">{getSuspectName(citizenid)}</span>
					<span class="suspect-id">{citizenid}</span>
				</div>
				<div class="charge-list">
					{#each suspectCharges as charge}
						<div class="charge-item">
							<div class="charge-info">
								<span class="charge-label">{charge.charge}</span>
								<div class="charge-values">
									<span class="charge-time">{charge.time * charge.count}mo</span>
									<span class="charge-fine">${(charge.fine * charge.count).toLocaleString()}</span>
								</div>
							</div>
							<div class="charge-controls">
								<button class="count-btn" onclick={() => updateCount(charge, -1)}>-</button>
								<span class="count-value">x{charge.count}</span>
								<button class="count-btn" onclick={() => updateCount(charge, 1)}>+</button>
								<button class="remove-charge-btn" onclick={() => onRemoveCharge(charge.id)} aria-label="Remove charge">
									<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
								</button>
							</div>
						</div>
					{/each}
				</div>
				<!-- Per-suspect totals and actions -->
				<div class="suspect-footer">
					<div class="suspect-totals">
						<span class="total-item">{getSuspectTotalMonths(citizenid)} months</span>
						<span class="total-item">${getSuspectTotalFine(citizenid).toLocaleString()}</span>
					</div>
					<div class="suspect-actions">
						<button
							class="action-btn jail-btn"
							onclick={() => onSendToJail(citizenid, getSuspectTotalMonths(citizenid))}
							disabled={!citizenid || getSuspectTotalMonths(citizenid) <= 0}
						>
							Send to Jail
						</button>
						<button
							class="action-btn fine-btn"
							onclick={() => onGiveCitation(citizenid, getSuspectTotalFine(citizenid))}
							disabled={!citizenid || getSuspectTotalFine(citizenid) <= 0}
						>
							Issue Fine
						</button>
						{#if reductionOffers.length > 0}
							<button
								class="action-btn reduction-btn"
								onclick={() => openReduction(citizenid)}
								disabled={!citizenid || (getSuspectTotalFine(citizenid) <= 0 && getSuspectTotalMonths(citizenid) <= 0)}
							>
								Reduction
							</button>
						{/if}
					</div>
				</div>

				<!-- Reduction panel -->
				{#if reductionTarget === citizenid}
					<div class="reduction-panel">
						<div class="reduction-header">
							<span class="reduction-title">Offer Reduction</span>
							<button class="reduction-close" onclick={closeReduction}>
								<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
							</button>
						</div>

						<div class="reduction-options">
							{#each reductionOffers as pct}
								<button
									class="reduction-option"
									class:selected={selectedReduction === pct}
									onclick={() => selectedReduction = pct}
								>
									{pct}% off
								</button>
							{/each}
						</div>

						{#if selectedReduction}
							<div class="reduction-preview">
								<div class="reduction-preview-row">
									<span class="preview-label">Jail</span>
									<span class="preview-original">{getSuspectTotalMonths(citizenid)}mo</span>
									<span class="preview-arrow">→</span>
									<span class="preview-reduced">{getReducedMonths(citizenid, selectedReduction)}mo</span>
									<span class="preview-saved">(-{getSuspectTotalMonths(citizenid) - getReducedMonths(citizenid, selectedReduction)}mo)</span>
								</div>
								<div class="reduction-preview-row">
									<span class="preview-label">Fine</span>
									<span class="preview-original">${getSuspectTotalFine(citizenid).toLocaleString()}</span>
									<span class="preview-arrow">→</span>
									<span class="preview-reduced">${getReducedFine(citizenid, selectedReduction).toLocaleString()}</span>
									<span class="preview-saved">(-${(getSuspectTotalFine(citizenid) - getReducedFine(citizenid, selectedReduction)).toLocaleString()})</span>
								</div>
							</div>

							<div class="reduction-actions">
								<button
									class="action-btn jail-btn"
									onclick={applyReductionJail}
									disabled={getSuspectTotalMonths(citizenid) <= 0}
								>
									Jail ({getReducedMonths(citizenid, selectedReduction)}mo)
								</button>
								<button
									class="action-btn fine-btn"
									onclick={applyReductionFine}
									disabled={getSuspectTotalFine(citizenid) <= 0}
								>
									Fine (${getReducedFine(citizenid, selectedReduction).toLocaleString()})
								</button>
								<button
									class="action-btn both-btn"
									onclick={applyReductionBoth}
									disabled={getSuspectTotalMonths(citizenid) <= 0 && getSuspectTotalFine(citizenid) <= 0}
								>
									Jail & Fine
								</button>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		{/each}

		<!-- Grand totals -->
		<div class="grand-totals">
			<div class="grand-total-item">
				<span class="grand-label">Total Jail Time</span>
				<span class="grand-value">{totalMonths} months</span>
			</div>
			<div class="grand-total-item">
				<span class="grand-label">Total Fines</span>
				<span class="grand-value">${totalFine.toLocaleString()}</span>
			</div>
		</div>
	{/if}
</div>

<style>
	.charges-section {
		padding-bottom: 12px;
		margin-bottom: 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}

	.section-label {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 5px;
	}

	.suspect-select {
		padding: 3px 22px 3px 6px;
		font-size: 10px;
		font-weight: 500;
		max-width: 150px;
		border-radius: 3px;
	}

	.add-btn {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		font-size: 10px;
		font-weight: 500;
		padding: 2px 6px;
		transition: color 0.1s;
	}

	.add-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.5);
	}

	.add-btn:disabled {
		opacity: 0.3;
		cursor: default;
	}

	.hint-text {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.2);
		font-style: italic;
	}

	/* Charge Picker */
	.charge-picker {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 3px;
		padding: 8px;
		margin-bottom: 8px;
	}

	.picker-search {
		width: 100%;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		padding: 6px 8px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 11px;
		margin-bottom: 6px;
		box-sizing: border-box;
	}

	.picker-search:focus {
		outline: none;
		border-color: rgba(var(--accent-rgb), 0.4);
	}

	.picker-search::placeholder {
		color: rgba(255, 255, 255, 0.3);
	}

	.picker-list {
		max-height: 200px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.picker-item {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 4px;
		padding: 6px 8px;
		cursor: pointer;
		text-align: left;
		color: inherit;
		font: inherit;
		width: 100%;
		transition: background 0.1s;
	}

	.picker-item:hover {
		background: rgba(255, 255, 255, 0.04);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.picker-item-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
	}

	.picker-label {
		font-size: 11px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.85);
	}

	.picker-type {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		padding: 1px 5px;
		border-radius: 3px;
	}

	.type-felony {
		background: rgba(239, 68, 68, 0.15);
		color: #f87171;
	}

	.type-misdemeanor {
		background: rgba(245, 158, 11, 0.15);
		color: #fbbf24;
	}

	.type-infraction {
		background: rgba(107, 114, 128, 0.15);
		color: #9ca3af;
	}

	.picker-item-bottom {
		display: flex;
		justify-content: space-between;
		margin-top: 2px;
	}

	.picker-meta {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	.picker-values {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.5);
		font-weight: 500;
	}

	.no-results {
		text-align: center;
		color: rgba(255, 255, 255, 0.3);
		font-size: 11px;
		padding: 12px;
	}

	/* Empty */
	.empty-text {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		text-align: center;
		padding: 10px;
		background: transparent;
		border: 1px dashed rgba(255, 255, 255, 0.04);
		border-radius: 3px;
	}

	/* Suspect groups */
	.suspect-group {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		margin-bottom: 0;
		padding-bottom: 4px;
		overflow: hidden;
	}

	.suspect-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 6px 0;
		background: transparent;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.suspect-name {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.suspect-id {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
	}

	/* Charge items */
	.charge-list {
		padding: 4px 0;
	}

	.charge-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 4px 10px;
		gap: 8px;
	}

	.charge-item:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.charge-info {
		display: flex;
		justify-content: space-between;
		flex: 1;
		min-width: 0;
		gap: 8px;
	}

	.charge-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.75);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.charge-values {
		display: flex;
		gap: 8px;
		flex-shrink: 0;
	}

	.charge-time {
		font-size: 10px;
		color: rgba(245, 158, 11, 0.7);
		font-weight: 500;
	}

	.charge-fine {
		font-size: 10px;
		color: rgba(16, 185, 129, 0.7);
		font-weight: 500;
	}

	.charge-controls {
		display: flex;
		align-items: center;
		gap: 4px;
		flex-shrink: 0;
	}

	.count-btn {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.5);
		width: 18px;
		height: 18px;
		font-size: 12px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
	}

	.count-btn:hover {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.8);
	}

	.count-value {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.6);
		font-weight: 600;
		min-width: 20px;
		text-align: center;
	}

	.remove-charge-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 16px;
		height: 16px;
		background: rgba(239, 68, 68, 0.12);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
		margin-left: 4px;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.charge-item:hover .remove-charge-btn {
		opacity: 1;
	}

	.remove-charge-btn:hover {
		background: rgba(239, 68, 68, 0.3);
	}

	/* Suspect footer */
	.suspect-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 6px 10px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		background: rgba(255, 255, 255, 0.01);
	}

	.suspect-totals {
		display: flex;
		gap: 12px;
	}

	.total-item {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.6);
	}

	.suspect-actions {
		display: flex;
		gap: 4px;
	}

	.action-btn {
		padding: 3px 8px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.12s ease;
	}

	.action-btn:disabled {
		opacity: 0.3;
		cursor: default;
	}

	.jail-btn {
		background: rgba(239, 68, 68, 0.12);
		color: #f87171;
		border-color: rgba(239, 68, 68, 0.2);
	}

	.jail-btn:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.2);
	}

	.fine-btn {
		background: rgba(16, 185, 129, 0.12);
		color: #34d399;
		border-color: rgba(16, 185, 129, 0.2);
	}

	.fine-btn:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.2);
	}

	.both-btn {
		background: rgba(59, 130, 246, 0.12);
		color: #60a5fa;
		border-color: rgba(59, 130, 246, 0.2);
	}

	.both-btn:hover:not(:disabled) {
		background: rgba(59, 130, 246, 0.2);
	}

	.reduction-btn {
		background: rgba(168, 85, 247, 0.12);
		color: #c084fc;
		border-color: rgba(168, 85, 247, 0.2);
	}

	.reduction-btn:hover:not(:disabled) {
		background: rgba(168, 85, 247, 0.2);
	}

	/* Reduction Panel */
	.reduction-panel {
		padding: 8px 10px 10px;
		border-top: 1px solid rgba(168, 85, 247, 0.15);
		background: rgba(168, 85, 247, 0.03);
	}

	.reduction-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}

	.reduction-title {
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(192, 132, 252, 0.8);
	}

	.reduction-close {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 18px;
		height: 18px;
		background: rgba(255, 255, 255, 0.04);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.4);
		cursor: pointer;
	}

	.reduction-close:hover {
		background: rgba(255, 255, 255, 0.1);
		color: rgba(255, 255, 255, 0.8);
	}

	.reduction-options {
		display: flex;
		gap: 4px;
		margin-bottom: 8px;
	}

	.reduction-option {
		padding: 4px 10px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
		border: 1px solid rgba(168, 85, 247, 0.15);
		background: rgba(168, 85, 247, 0.06);
		color: rgba(192, 132, 252, 0.7);
		transition: all 0.12s ease;
	}

	.reduction-option:hover {
		background: rgba(168, 85, 247, 0.15);
		color: #c084fc;
	}

	.reduction-option.selected {
		background: rgba(168, 85, 247, 0.25);
		border-color: rgba(168, 85, 247, 0.4);
		color: #d8b4fe;
	}

	.reduction-preview {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: 8px;
		padding: 6px 8px;
		background: rgba(0, 0, 0, 0.2);
		border-radius: 4px;
	}

	.reduction-preview-row {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 11px;
	}

	.preview-label {
		font-weight: 600;
		color: rgba(255, 255, 255, 0.5);
		width: 30px;
	}

	.preview-original {
		color: rgba(255, 255, 255, 0.4);
		text-decoration: line-through;
	}

	.preview-arrow {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.preview-reduced {
		color: rgba(255, 255, 255, 0.9);
		font-weight: 600;
	}

	.preview-saved {
		color: rgba(16, 185, 129, 0.7);
		font-size: 10px;
	}

	.reduction-actions {
		display: flex;
		gap: 4px;
	}

	/* Grand totals */
	.grand-totals {
		display: flex;
		gap: 16px;
		padding: 8px 0;
		margin-top: 6px;
		background: transparent;
		border: none;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
	}

	.grand-total-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.grand-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.35);
	}

	.grand-value {
		font-size: 14px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.9);
	}
</style>
