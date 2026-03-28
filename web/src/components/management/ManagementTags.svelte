<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import type { JobType } from "../../interfaces/IUser";

	type JobTypeFilter = "leo" | "ems" | "all";

	interface Props {
		jobType?: JobType;
	}

	let { jobType = 'leo' }: Props = $props();

	let isEMS = $derived(jobType === 'ems');

	interface Tag {
		id: number;
		name: string;
		type: "officer" | "report" | "both";
		color: string;
		job_type: JobTypeFilter;
		usage_count?: number;
		created_at?: string;
	}

	const TAG_COLORS = [
		{ value: "#3b82f6", label: "Blue" },
		{ value: "#10b981", label: "Green" },
		{ value: "#f59e0b", label: "Amber" },
		{ value: "#ef4444", label: "Red" },
		{ value: "#8b5cf6", label: "Purple" },
		{ value: "#ec4899", label: "Pink" },
		{ value: "#06b6d4", label: "Cyan" },
		{ value: "#f97316", label: "Orange" },
		{ value: "#6b7280", label: "Gray" },
	];

	let TAG_TYPES = $derived(isEMS ? [
		{ value: "officer", label: "Personnel" },
		{ value: "report", label: "Report" },
		{ value: "both", label: "Both" },
	] : [
		{ value: "officer", label: "Officer" },
		{ value: "report", label: "Report" },
		{ value: "both", label: "Both" },
	]);

	const JOB_TYPES = [
		{ value: "all", label: "All" },
		{ value: "leo", label: "LEO" },
		{ value: "ems", label: "EMS" },
	];

	let tags: Tag[] = $state([]);
	let newTagName: string = $state("");
	let newTagType: "officer" | "report" | "both" = $state("officer");
	let newTagColor: string = $state("#3b82f6");
	let newTagJobType: JobTypeFilter = $state(jobType as JobTypeFilter);
	let isLoading = $state(false);
	let isSubmitting = $state(false);
	let statusMessage: { text: string; type: "success" | "error" } | null = $state(null);
	let editingTag: Tag | null = $state(null);
	let editName: string = $state("");
	let editType: "officer" | "report" | "both" = $state("officer");
	let editColor: string = $state("#3b82f6");
	let editJobType: JobTypeFilter = $state("all");
	let filterType: "all" | "officer" | "report" | "both" = $state("all");
	let filterJobType: "all" | "leo" | "ems" = $state("all");
	let searchQuery: string = $state("");

	let filteredTags = $derived(
		tags.filter((tag) => {
			const matchesType = filterType === "all" || tag.type === filterType;
			const matchesJobType = filterJobType === "all" || tag.job_type === filterJobType || tag.job_type === "all";
			const matchesSearch = !searchQuery || tag.name.toLowerCase().includes(searchQuery.toLowerCase());
			return matchesType && matchesJobType && matchesSearch;
		})
	);

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	async function loadTags() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<Tag[]>(NUI_EVENTS.MANAGEMENT.GET_TAGS, { jobType }, []);
			tags = Array.isArray(response) ? response : [];
		} catch (error) {
			console.error("Failed to load tags:", error);
			tags = [];
		} finally {
			isLoading = false;
		}
	}

	async function handleCreate() {
		const name = newTagName.trim();
		if (!name) return;
		if (name.length > 25) {
			showStatus("Tag name must be 25 characters or less", "error");
			return;
		}

		if (isEnvBrowser()) {
			tags = [...tags, { id: Date.now(), name, type: newTagType, color: newTagColor, job_type: newTagJobType, usage_count: 0 }];
			newTagName = "";
			return;
		}

		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string; id?: number }>(
				NUI_EVENTS.MANAGEMENT.CREATE_TAG,
				{ name, type: newTagType, color: newTagColor, job_type: newTagJobType },
				{ success: false },
			);
			if (result?.success) {
				showStatus("Tag created");
				newTagName = "";
				await loadTags();
			} else {
				showStatus(result?.message || "Failed to create tag", "error");
			}
		} catch (error) {
			console.error("Failed to create tag:", error);
			showStatus("Failed to create tag", "error");
		} finally {
			isSubmitting = false;
		}
	}

	async function handleUpdate() {
		if (!editingTag) return;
		const name = editName.trim();
		if (!name) return;
		if (name.length > 25) {
			showStatus("Tag name must be 25 characters or less", "error");
			return;
		}

		if (isEnvBrowser()) {
			tags = tags.map((t) => t.id === editingTag!.id ? { ...t, name, type: editType, color: editColor, job_type: editJobType } : t);
			editingTag = null;
			return;
		}

		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.MANAGEMENT.UPDATE_TAG,
				{ id: editingTag.id, name, type: editType, color: editColor, job_type: editJobType },
				{ success: false },
			);
			if (result?.success) {
				showStatus("Tag updated");
				editingTag = null;
				await loadTags();
			} else {
				showStatus(result?.message || "Failed to update tag", "error");
			}
		} catch (error) {
			console.error("Failed to update tag:", error);
			showStatus("Failed to update tag", "error");
		} finally {
			isSubmitting = false;
		}
	}

	async function handleDelete(tag: Tag) {
		if (isEnvBrowser()) {
			tags = tags.filter((t) => t.id !== tag.id);
			return;
		}

		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.MANAGEMENT.DELETE_TAG,
				{ id: tag.id },
				{ success: false },
			);
			if (result?.success) {
				showStatus("Tag deleted");
				if (editingTag?.id === tag.id) editingTag = null;
				await loadTags();
			} else {
				showStatus(result?.message || "Failed to delete tag", "error");
			}
		} catch (error) {
			console.error("Failed to delete tag:", error);
			showStatus("Failed to delete tag", "error");
		}
	}

	function startEdit(tag: Tag) {
		editingTag = tag;
		editName = tag.name;
		editType = tag.type;
		editColor = tag.color || "#3b82f6";
		editJobType = isEMS ? (jobType as JobTypeFilter) : (tag.job_type || "all");
	}

	function cancelEdit() {
		editingTag = null;
	}

	function getTypeLabel(type: string): string {
		return TAG_TYPES.find((t) => t.value === type)?.label || type;
	}

	function getJobTypeLabel(jt: string): string {
		return JOB_TYPES.find((t) => t.value === jt)?.label || jt;
	}

	onMount(() => {
		if (isEnvBrowser()) {
			tags = [
				{ id: 1, name: "SWAT", type: "officer", color: "#3b82f6", job_type: "leo", usage_count: 3 },
				{ id: 2, name: "FTO", type: "officer", color: "#10b981", job_type: "leo", usage_count: 5 },
				{ id: 3, name: "Detective", type: "officer", color: "#8b5cf6", job_type: "leo", usage_count: 2 },
				{ id: 4, name: "Paramedic", type: "officer", color: "#ef4444", job_type: "ems", usage_count: 1 },
				{ id: 5, name: "Cardiac", type: "report", color: "#ef4444", job_type: "ems", usage_count: 4 },
				{ id: 6, name: "Gang Related", type: "report", color: "#ef4444", job_type: "leo", usage_count: 8 },
				{ id: 7, name: "High Priority", type: "both", color: "#f59e0b", job_type: "all", usage_count: 12 },
			];
			return;
		}
		loadTags();
	});
</script>

<div class="tags-panel">
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">
			{statusMessage.text}
		</div>
	{/if}

	<!-- Create new tag -->
	<div class="new-tag-section">
		<div class="new-tag-row">
			<input
				class="tag-name-input"
				type="text"
				placeholder="New tag name..."
				bind:value={newTagName}
				maxlength="25"
				onkeydown={(e) => e.key === "Enter" && handleCreate()}
			/>
			<select class="tag-select" bind:value={newTagType}>
				{#each TAG_TYPES as type}
					<option value={type.value}>{type.label}</option>
				{/each}
			</select>
			{#if !isEMS}
				<select class="tag-select" bind:value={newTagJobType}>
					{#each JOB_TYPES as jt}
						<option value={jt.value}>{jt.label}</option>
					{/each}
				</select>
			{/if}
			<div class="color-picker">
				{#each TAG_COLORS as color}
					<button
						class="color-dot"
						class:selected={newTagColor === color.value}
						style="background: {color.value}"
						title={color.label}
						onclick={() => (newTagColor = color.value)}
					></button>
				{/each}
			</div>
			<button
				class="btn-create"
				onclick={handleCreate}
				disabled={!newTagName.trim() || isSubmitting}
			>
				{isSubmitting ? "..." : "+ Add"}
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filter-bar">
		<input
			class="search-input"
			type="text"
			placeholder="Search tags..."
			bind:value={searchQuery}
		/>
		<div class="filter-pills">
			<button class="filter-pill" class:active={filterType === "all"} onclick={() => (filterType = "all")}>All</button>
			<button class="filter-pill" class:active={filterType === "officer"} onclick={() => (filterType = "officer")}>{isEMS ? 'Personnel' : 'Officer'}</button>
			<button class="filter-pill" class:active={filterType === "report"} onclick={() => (filterType = "report")}>Report</button>
			<button class="filter-pill" class:active={filterType === "both"} onclick={() => (filterType = "both")}>Both</button>
		</div>
		{#if !isEMS}
			<div class="filter-pills">
				<button class="filter-pill" class:active={filterJobType === "all"} onclick={() => (filterJobType = "all")}>All</button>
				<button class="filter-pill" class:active={filterJobType === "leo"} onclick={() => (filterJobType = "leo")}>LEO</button>
				<button class="filter-pill" class:active={filterJobType === "ems"} onclick={() => (filterJobType = "ems")}>EMS</button>
			</div>
		{/if}
		<span class="tag-count">{filteredTags.length} tag{filteredTags.length !== 1 ? "s" : ""}</span>
	</div>

	<!-- Tags list -->
	{#if isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading tags...</p>
		</div>
	{:else}
		<div class="tags-list">
			{#each filteredTags as tag (tag.id)}
				<div class="tag-row" class:editing={editingTag?.id === tag.id}>
					{#if editingTag?.id === tag.id}
						<!-- Edit mode -->
						<div class="tag-edit-form">
							<div class="edit-row">
								<div class="tag-color-indicator" style="background: {editColor}"></div>
								<input
									class="tag-name-input edit"
									type="text"
									bind:value={editName}
									maxlength="25"
									onkeydown={(e) => e.key === "Enter" && handleUpdate()}
								/>
								<select class="tag-select" bind:value={editType}>
									{#each TAG_TYPES as type}
										<option value={type.value}>{type.label}</option>
									{/each}
								</select>
								{#if !isEMS}
								<select class="tag-select" bind:value={editJobType}>
									{#each JOB_TYPES as jt}
										<option value={jt.value}>{jt.label}</option>
									{/each}
								</select>
							{/if}
							</div>
							<div class="edit-row">
								<div class="color-picker compact">
									{#each TAG_COLORS as color}
										<button
											class="color-dot"
											class:selected={editColor === color.value}
											style="background: {color.value}"
											title={color.label}
											onclick={() => (editColor = color.value)}
										></button>
									{/each}
								</div>
								<div class="edit-actions">
									<button class="btn-save" onclick={handleUpdate} disabled={!editName.trim() || isSubmitting}>Save</button>
									<button class="btn-cancel" onclick={cancelEdit}>Cancel</button>
								</div>
							</div>
						</div>
					{:else}
						<!-- Display mode -->
						<div class="tag-color-indicator" style="background: {tag.color || '#6b7280'}"></div>
						<div class="tag-info">
							<span class="tag-name">{tag.name}</span>
							<span class="tag-type-badge {tag.type}">{getTypeLabel(tag.type)}</span>
							<span class="tag-type-badge job-{tag.job_type || 'all'}">{getJobTypeLabel(tag.job_type || 'all')}</span>
						</div>
						{#if tag.usage_count !== undefined}
							<span class="tag-usage" title="Times used">{tag.usage_count} uses</span>
						{/if}
						<div class="tag-actions">
							<button class="action-btn edit-btn" onclick={() => startEdit(tag)} title="Edit">
								<span class="material-icons">edit</span>
							</button>
							<button class="action-btn delete-btn" onclick={() => handleDelete(tag)} title="Delete">
								<span class="material-icons">delete</span>
							</button>
						</div>
					{/if}
				</div>
			{:else}
				<div class="empty-state">
					{#if searchQuery || filterType !== "all"}
						No tags match your filter.
					{:else}
						No tags created yet. Add one above.
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.tags-panel {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: transparent;
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

	/* New tag section */
	.new-tag-section {
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.new-tag-row {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.tag-name-input {
		flex: 1;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		min-width: 0;
	}

	.tag-name-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.12);
	}

	.tag-name-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.tag-name-input.edit {
		flex: 1;
	}

	.tag-select {
		padding: 5px 24px 5px 8px;
		font-size: 10px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.7);
		outline: none;
	}

	.color-picker {
		display: flex;
		gap: 3px;
		align-items: center;
		flex-shrink: 0;
	}

	.color-picker.compact {
		gap: 3px;
	}

	.color-dot {
		width: 14px;
		height: 14px;
		border-radius: 50%;
		border: 2px solid transparent;
		cursor: pointer;
		transition: all 0.1s;
		padding: 0;
	}

	.color-dot:hover {
		transform: scale(1.15);
	}

	.color-dot.selected {
		border-color: rgba(255, 255, 255, 0.7);
		box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.3);
	}

	.btn-create {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
		white-space: nowrap;
	}

	.btn-create:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-create:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* Filter bar */
	.filter-bar {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.search-input {
		flex: 1;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		min-width: 0;
	}

	.search-input:focus {
		outline: none;
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.filter-pills {
		display: flex;
		gap: 0;
		flex-shrink: 0;
	}

	.filter-pill {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 2px 8px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.filter-pill:first-child {
		border-radius: 3px 0 0 3px;
	}

	.filter-pill:last-child {
		border-radius: 0 3px 3px 0;
	}

	.filter-pill:not(:last-child) {
		border-right: none;
	}

	.filter-pill:hover {
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.02);
	}

	.filter-pill.active {
		background: rgba(255, 255, 255, 0.05);
		color: rgba(255, 255, 255, 0.8);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.tag-count {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.2);
		flex-shrink: 0;
		white-space: nowrap;
	}

	/* Tags list */
	.tags-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.tags-list::-webkit-scrollbar {
		width: 4px;
	}

	.tags-list::-webkit-scrollbar-track {
		background: transparent;
	}

	.tags-list::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.tag-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 7px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}

	.tag-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.tag-row.editing {
		background: rgba(255, 255, 255, 0.02);
		padding: 8px 16px;
	}

	.tag-row:last-child {
		border-bottom: none;
	}

	.tag-color-indicator {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.tag-info {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 8px;
		min-width: 0;
	}

	.tag-name {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.8);
		font-weight: 500;
	}

	.tag-type-badge {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		padding: 1px 6px;
		border-radius: 3px;
		flex-shrink: 0;
	}

	.tag-type-badge.officer {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.tag-type-badge.report {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.7);
	}

	.tag-type-badge.both {
		background: rgba(139, 92, 246, 0.08);
		color: rgba(196, 181, 253, 0.7);
	}

	.tag-type-badge.job-leo {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.tag-type-badge.job-ems {
		background: rgba(220, 50, 50, 0.08);
		color: rgba(252, 165, 165, 0.7);
	}

	.tag-type-badge.job-all {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.7);
	}

	.tag-usage {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
	}

	.tag-actions {
		display: flex;
		gap: 2px;
		opacity: 0;
		transition: opacity 0.1s;
		flex-shrink: 0;
	}

	.tag-row:hover .tag-actions {
		opacity: 1;
	}

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

	.action-btn .material-icons {
		font-size: 13px;
	}

	.action-btn.edit-btn:hover {
		color: rgba(var(--accent-text-rgb), 0.7);
		background: rgba(var(--accent-rgb), 0.08);
	}

	.action-btn.delete-btn:hover {
		color: rgba(252, 165, 165, 0.7);
		background: rgba(239, 68, 68, 0.08);
	}

	/* Edit form */
	.tag-edit-form {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.edit-row {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.edit-actions {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
		margin-left: auto;
	}

	.btn-save {
		background: rgba(16, 185, 129, 0.08);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(110, 231, 183, 0.8);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-save:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.15);
	}

	.btn-save:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-cancel:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 200px;
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
</style>
