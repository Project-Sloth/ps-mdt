<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface CustomLicense {
		id: number;
		name: string;
		description: string;
	}

	let licenses: CustomLicense[] = $state([]);
	let isLoading = $state(false);
	let isSubmitting = $state(false);
	let statusMessage: { text: string; type: "success" | "error" } | null = $state(null);
	let editingId: number | null = $state(null);

	let formName = $state("");
	let formDesc = $state("");

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	function resetForm() {
		formName = "";
		formDesc = "";
		editingId = null;
	}

	function startEdit(license: CustomLicense) {
		editingId = license.id;
		formName = license.name;
		formDesc = license.description;
	}

	async function handleSave() {
		const name = formName.trim();
		const desc = formDesc.trim();
		if (!name) {
			showStatus("License name is required", "error");
			return;
		}

		const payload = { id: editingId, name, description: desc };

		if (isEnvBrowser()) {
			if (editingId) {
				licenses = licenses.map(l => l.id === editingId ? { ...l, ...payload } as CustomLicense : l);
			} else {
				licenses = [...licenses, { ...payload, id: Date.now() } as CustomLicense];
			}
			resetForm();
			return;
		}

		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.SETTINGS.SAVE_CUSTOM_LICENSE, payload, { success: false }
			);
			if (result?.success) {
				showStatus(editingId ? "License updated" : "License created");
				resetForm();
				await loadLicenses();
			} else {
				showStatus(result?.message || "Failed to save", "error");
			}
		} catch {
			showStatus("Failed to save license", "error");
		} finally {
			isSubmitting = false;
		}
	}

	async function handleDelete(license: CustomLicense) {
		if (isEnvBrowser()) {
			licenses = licenses.filter(l => l.id !== license.id);
			if (editingId === license.id) resetForm();
			return;
		}

		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.SETTINGS.DELETE_CUSTOM_LICENSE, { id: license.id }, { success: false }
			);
			if (result?.success) {
				showStatus("License deleted");
				if (editingId === license.id) resetForm();
				await loadLicenses();
			} else {
				showStatus("Failed to delete", "error");
			}
		} catch {
			showStatus("Failed to delete license", "error");
		}
	}

	async function loadLicenses() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<CustomLicense[]>(NUI_EVENTS.SETTINGS.GET_CUSTOM_LICENSES, {}, []);
			licenses = Array.isArray(response) ? response : [];
		} catch {
			licenses = [];
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		if (isEnvBrowser()) {
			licenses = [
				{ id: 1, name: "Hunting License", description: "Permits hunting of wildlife in designated areas" },
				{ id: 2, name: "Boating License", description: "Required for operating watercraft" },
				{ id: 3, name: "Pilot License", description: "Required for operating aircraft" },
			];
			return;
		}
		loadLicenses();
	});
</script>

<div class="licenses-panel">
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">{statusMessage.text}</div>
	{/if}

	<div class="info-section">
		<div class="info-row">
			<span class="material-icons info-icon">info</span>
			<span class="info-text">State licenses (Driver's License, Weapon License) are managed by the core framework. Create custom licenses below that officers can grant or revoke from citizen profiles.</span>
		</div>
	</div>

	<div class="form-section">
		<div class="form-row">
			<input class="form-input name-input" type="text" placeholder="License name..." bind:value={formName} maxlength="50" />
			<input class="form-input desc-input" type="text" placeholder="Description (optional)..." bind:value={formDesc} maxlength="150" />
			<div class="form-actions">
				{#if editingId}
					<button class="btn-save" onclick={handleSave} disabled={isSubmitting}>Update</button>
					<button class="btn-cancel" onclick={resetForm}>Cancel</button>
				{:else}
					<button class="btn-create" onclick={handleSave} disabled={!formName.trim() || isSubmitting}>
						{isSubmitting ? "..." : "+ Add"}
					</button>
				{/if}
			</div>
		</div>
	</div>

	{#if isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading licenses...</p>
		</div>
	{:else}
		<div class="licenses-list">
			<!-- State licenses (read-only) -->
			<div class="license-row state">
				<span class="material-icons row-icon">verified</span>
				<div class="row-info">
					<span class="row-name">Driver's License</span>
					<span class="row-desc">State-issued license for operating motor vehicles</span>
				</div>
				<span class="row-badge state-badge">STATE</span>
			</div>
			<div class="license-row state">
				<span class="material-icons row-icon">verified</span>
				<div class="row-info">
					<span class="row-name">Weapon License</span>
					<span class="row-desc">State-issued license for carrying firearms</span>
				</div>
				<span class="row-badge state-badge">STATE</span>
			</div>

			<!-- Custom licenses -->
			{#each licenses as license (license.id)}
				<div class="license-row" class:editing={editingId === license.id}>
					<span class="material-icons row-icon custom-icon">badge</span>
					<div class="row-info">
						<span class="row-name">{license.name}</span>
						{#if license.description}
							<span class="row-desc">{license.description}</span>
						{/if}
					</div>
					<span class="row-badge custom-badge">CUSTOM</span>
					<div class="row-actions">
						<button class="action-btn edit-btn" onclick={() => startEdit(license)} title="Edit">
							<span class="material-icons">edit</span>
						</button>
						<button class="action-btn delete-btn" onclick={() => handleDelete(license)} title="Delete">
							<span class="material-icons">delete</span>
						</button>
					</div>
				</div>
			{/each}

			{#if licenses.length === 0}
				<div class="empty-state">No custom licenses configured. Add one above.</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.licenses-panel {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
	}

	.status-toast {
		padding: 6px 12px;
		font-size: 10px;
		font-weight: 500;
		flex-shrink: 0;
		margin: 8px 16px 0;
		border-radius: 3px;
	}

	.status-toast.success {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-toast.error {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.info-section {
		padding: 10px 16px 0;
		flex-shrink: 0;
	}

	.info-row {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 8px 10px;
		background: rgba(var(--accent-rgb), 0.04);
		border: 1px solid rgba(var(--accent-rgb), 0.08);
		border-radius: 4px;
	}

	.info-icon {
		font-size: 14px;
		color: rgba(var(--accent-text-rgb), 0.5);
		flex-shrink: 0;
		margin-top: 1px;
	}

	.info-text {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
		line-height: 1.5;
	}

	.form-section {
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.form-row {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		min-width: 0;
	}

	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.12); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }

	.name-input { flex: 1; }
	.desc-input { flex: 2; }

	.form-actions {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
	}

	.btn-create, .btn-save {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
	}

	.btn-create:hover:not(:disabled), .btn-save:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-create:disabled, .btn-save:disabled { opacity: 0.3; cursor: not-allowed; }

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
	}

	.btn-cancel:hover { background: rgba(255, 255, 255, 0.04); color: rgba(255, 255, 255, 0.6); }

	.licenses-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.licenses-list::-webkit-scrollbar { width: 4px; }
	.licenses-list::-webkit-scrollbar-track { background: transparent; }
	.licenses-list::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.license-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 9px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}

	.license-row:hover { background: rgba(255, 255, 255, 0.02); }
	.license-row.editing { background: rgba(var(--accent-rgb), 0.03); }
	.license-row.state { opacity: 0.7; }

	.row-icon {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.25);
		flex-shrink: 0;
	}

	.row-icon.custom-icon { color: rgba(var(--accent-text-rgb), 0.4); }

	.row-info {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.row-name {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.75);
	}

	.row-desc {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
	}

	.row-badge {
		font-size: 8px;
		font-weight: 700;
		letter-spacing: 0.5px;
		padding: 2px 6px;
		border-radius: 3px;
		flex-shrink: 0;
	}

	.state-badge {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.6);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.custom-badge {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.6);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.row-actions {
		display: flex;
		gap: 2px;
		opacity: 0;
		transition: opacity 0.1s;
		flex-shrink: 0;
	}

	.license-row:hover .row-actions { opacity: 1; }

	.action-btn {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		padding: 3px;
		border-radius: 3px;
		display: flex;
		align-items: center;
		transition: all 0.1s;
	}

	.action-btn .material-icons { font-size: 13px; }

	.action-btn.edit-btn:hover { color: rgba(var(--accent-text-rgb), 0.7); background: rgba(var(--accent-rgb), 0.08); }
	.action-btn.delete-btn:hover { color: rgba(252, 165, 165, 0.7); background: rgba(239, 68, 68, 0.08); }

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 120px;
		color: rgba(255, 255, 255, 0.25);
		font-size: 11px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.4);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 8px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
