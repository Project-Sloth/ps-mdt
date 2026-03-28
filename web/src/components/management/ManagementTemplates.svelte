<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import { getReportTypesForJob } from "../../constants/index";
	import type { JobType } from "../../interfaces/IUser";

	interface ReportTemplate {
		id: number;
		name: string;
		type: string;
		content: string;
		job_type?: string;
	}

	let { jobType = 'leo' as JobType }: { jobType?: JobType } = $props();

	let REPORT_TYPES = $derived(getReportTypesForJob(jobType));

	let templates: ReportTemplate[] = $state([]);
	let isLoading = $state(false);
	let isSaving = $state(false);
	let statusMsg: { text: string; type: "success" | "error" } | null = $state(null);

	let editingTemplate: ReportTemplate | null = $state(null);
	let isCreating = $state(false);

	let formName = $state("");
	let defaultType = $derived(REPORT_TYPES[0] || "Incident Report");
	let formType = $state("");
	let formContent = $state("");

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMsg = { text, type };
		setTimeout(() => { statusMsg = null; }, 3000);
	}

	async function loadTemplates() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<ReportTemplate[]>(
				NUI_EVENTS.SETTINGS.GET_REPORT_TEMPLATES,
				{ jobType },
				[],
			);
			if (Array.isArray(response)) {
				templates = response;
			}
		} catch (error) {
			console.error("Failed to load templates:", error);
		} finally {
			isLoading = false;
		}
	}

	async function saveTemplate() {
		if (!formName.trim()) {
			showStatus("Template name is required", "error");
			return;
		}
		if (!formContent.trim()) {
			showStatus("Template content is required", "error");
			return;
		}

		if (isEnvBrowser()) {
			if (editingTemplate) {
				const idx = templates.findIndex((t) => t.id === editingTemplate!.id);
				if (idx >= 0) {
					templates[idx] = { ...editingTemplate, name: formName.trim(), type: formType, content: formContent };
					templates = [...templates];
				}
			} else {
				templates = [...templates, { id: Date.now(), name: formName.trim(), type: formType, content: formContent }];
			}
			cancelEdit();
			showStatus("Template saved");
			return;
		}

		try {
			isSaving = true;
			const payload = {
				id: editingTemplate?.id || null,
				name: formName.trim(),
				type: formType,
				content: formContent,
				jobType,
			};
			const result = await fetchNui<{ success: boolean; message?: string; template?: ReportTemplate }>(
				NUI_EVENTS.SETTINGS.SAVE_REPORT_TEMPLATE,
				payload,
				{ success: false },
			);
			if (result?.success) {
				showStatus(editingTemplate ? "Template updated" : "Template created");
				cancelEdit();
				await loadTemplates();
			} else {
				showStatus(result?.message || "Failed to save template", "error");
			}
		} catch (error) {
			console.error("Failed to save template:", error);
			showStatus("Failed to save template", "error");
		} finally {
			isSaving = false;
		}
	}

	async function deleteTemplate(id: number) {
		if (isEnvBrowser()) {
			templates = templates.filter((t) => t.id !== id);
			showStatus("Template deleted");
			return;
		}

		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.SETTINGS.DELETE_REPORT_TEMPLATE,
				{ id },
				{ success: false },
			);
			if (result?.success) {
				showStatus("Template deleted");
				await loadTemplates();
			} else {
				showStatus(result?.message || "Failed to delete template", "error");
			}
		} catch (error) {
			console.error("Failed to delete template:", error);
			showStatus("Failed to delete template", "error");
		}
	}

	function startCreate() {
		editingTemplate = null;
		isCreating = true;
		formName = "";
		formType = defaultType;
		formContent = "";
	}

	function startEdit(template: ReportTemplate) {
		editingTemplate = template;
		isCreating = true;
		formName = template.name;
		formType = template.type;
		formContent = template.content;
	}

	function cancelEdit() {
		editingTemplate = null;
		isCreating = false;
		formName = "";
		formType = defaultType;
		formContent = "";
	}

	function getTypeCount(type: string): number {
		return templates.filter((t) => t.type === type).length;
	}

	if (isEnvBrowser()) {
		templates = [
			{ id: 1, name: "Standard Incident", type: "Incident Report", content: "<h2>Incident Summary</h2>\n<p>On [DATE] at approximately [TIME]...</p>" },
			{ id: 2, name: "Traffic Stop", type: "Traffic Report", content: "<h2>Traffic Incident Summary</h2>\n<p>On [DATE] at approximately [TIME]...</p>" },
			{ id: 3, name: "Full Investigation", type: "Investigation Report", content: "<h2>Case Overview</h2>\n<p><strong>Case Number:</strong> [CASE #]</p>" },
			{ id: 4, name: "Standard Arrest", type: "Arrest Report", content: "<h2>Arrest Summary</h2>\n<p>On [DATE] at approximately [TIME]...</p>" },
			{ id: 5, name: "Evidence Collection", type: "Evidence Report", content: "<h2>Evidence Report Summary</h2>\n<p><strong>Related Case:</strong> [CASE #]</p>" },
		];
	}

	onMount(() => {
		loadTemplates();
	});
</script>

<div class="templates-page">
	<div class="templates-card">
		<div class="card-title-row">
			<span class="card-label">Report Templates</span>
			<div class="template-actions">
				{#if !isCreating}
					<button class="action-btn create-btn" onclick={startCreate}>
						<span class="material-icons" style="font-size: 11px;">add</span>
						New Template
					</button>
				{/if}
			</div>
		</div>
		<p class="card-subtitle">Configure templates available when creating reports. Each template is linked to a report type.</p>

		{#if isLoading}
			<div class="templates-loading">
				<div class="loading-spinner"></div>
				<p>Loading templates...</p>
			</div>
		{:else if isCreating}
			<div class="template-form">
				<div class="form-row">
					<div class="form-group">
						<label class="form-label" for="tmpl-name">Template Name</label>
						<input id="tmpl-name" type="text" class="form-input" placeholder="e.g. Standard Incident" bind:value={formName} />
					</div>
					<div class="form-group">
						<label class="form-label" for="tmpl-type">Report Type</label>
						<select id="tmpl-type" class="form-select" bind:value={formType}>
							{#each REPORT_TYPES as rt}
								<option value={rt}>{rt}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-group">
					<label class="form-label" for="tmpl-content">Template Content <span class="form-hint">(HTML)</span></label>
					<textarea id="tmpl-content" class="form-textarea" placeholder="Enter HTML template content..." bind:value={formContent} rows={12}></textarea>
				</div>

				<div class="form-actions">
					<button class="btn-cancel" onclick={cancelEdit}>Cancel</button>
					<button class="btn-save" onclick={saveTemplate} disabled={isSaving}>
						<span class="material-icons btn-save-icon">save</span>
						{isSaving ? "Saving..." : editingTemplate ? "Update Template" : "Create Template"}
					</button>
				</div>
			</div>
		{:else}
			<div class="templates-scroll">
				{#if templates.length === 0}
					<div class="empty-state">
						<span class="material-icons" style="font-size: 20px; color: rgba(255,255,255,0.15); margin-bottom: 6px;">description</span>
						<p>No templates configured</p>
						<p class="empty-hint">Create a template to get started</p>
					</div>
				{:else}
					<div class="templates-list">
						{#each templates as template (template.id)}
							<div class="template-row">
								<div class="template-info">
									<span class="template-name">{template.name}</span>
									<span class="template-type">{template.type}</span>
								</div>
								<div class="template-row-actions">
									<button class="row-btn edit-btn" onclick={() => startEdit(template)} aria-label="Edit">
										<span class="material-icons">edit</span>
									</button>
									<button class="row-btn delete-btn" onclick={() => deleteTemplate(template.id)} aria-label="Delete">
										<span class="material-icons">delete</span>
									</button>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	{#if statusMsg}
		<div class="save-bar">
			<span class="save-status {statusMsg.type}">{statusMsg.text}</span>
		</div>
	{/if}
</div>

<style>
	.templates-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.templates-card {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 12px 16px;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.card-title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.card-label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.45);
	}

	.card-subtitle {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		margin: 6px 0 12px 0;
		padding-bottom: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.template-actions {
		display: flex;
		gap: 4px;
	}

	.action-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		display: inline-flex;
		align-items: center;
		gap: 3px;
	}

	.action-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.create-btn {
		background: rgba(var(--accent-rgb), 0.06);
		border-color: rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.create-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	/* Loading */
	.templates-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 100px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
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

	/* Template list */
	.templates-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.templates-scroll::-webkit-scrollbar {
		width: 4px;
	}

	.templates-scroll::-webkit-scrollbar-track {
		background: transparent;
	}

	.templates-scroll::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.templates-list {
		display: flex;
		flex-direction: column;
	}

	.template-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.template-row:last-child {
		border-bottom: none;
	}

	.template-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.template-name {
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-weight: 500;
	}

	.template-type {
		color: rgba(var(--accent-text-rgb), 0.5);
		font-size: 10px;
	}

	.template-row-actions {
		display: flex;
		gap: 2px;
	}

	.row-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 22px;
		height: 22px;
		background: transparent;
		border: none;
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		transition: all 0.1s;
	}

	.row-btn .material-icons {
		font-size: 13px;
	}

	.row-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	.delete-btn:hover {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
	}

	/* Empty state */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 120px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.empty-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.15);
		margin-top: 2px;
	}

	/* Form */
	.template-form {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.template-form::-webkit-scrollbar {
		width: 4px;
	}

	.template-form::-webkit-scrollbar-track {
		background: transparent;
	}

	.template-form::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.form-row {
		display: flex;
		gap: 10px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 3px;
		flex: 1;
	}

	.form-label {
		font-size: 10px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.35);
	}

	.form-hint {
		font-weight: 400;
		color: rgba(255, 255, 255, 0.2);
	}

	.form-input,
	.form-select {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
	}

	.form-input:focus,
	.form-select:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}

	.form-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.form-select {
		cursor: pointer;
		appearance: none;
		-webkit-appearance: none;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8' viewBox='0 0 24 24'%3E%3Cpath fill='rgba(255,255,255,0.3)' d='M7 10l5 5 5-5z'/%3E%3C/svg%3E");
		background-repeat: no-repeat;
		background-position: right 6px center;
		padding-right: 20px;
	}

	.form-select option {
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.8);
	}

	.form-textarea {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 10px;
		font-family: "JetBrains Mono", "Fira Code", "Cascadia Code", monospace;
		line-height: 1.5;
		outline: none;
		resize: vertical;
		min-height: 120px;
		flex: 1;
	}

	.form-textarea:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}

	.form-textarea::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.form-actions {
		display: flex;
		align-items: center;
		gap: 6px;
		padding-top: 6px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.4);
		padding: 4px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-cancel:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.btn-save {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 16px;
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
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-save-icon {
		font-size: 13px;
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

	.save-status {
		font-size: 10px;
		animation: fadeIn 0.2s ease-out;
	}

	.save-status.success { color: rgba(110, 231, 183, 0.8); }
	.save-status.error { color: rgba(252, 165, 165, 0.8); }

	@keyframes fadeIn {
		0% { opacity: 0; }
		100% { opacity: 1; }
	}
</style>
