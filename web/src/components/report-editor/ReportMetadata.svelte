<script lang="ts">
	interface TemplateOption {
		id: number;
		name: string;
		type: string;
		content: string;
	}

	import { untrack } from "svelte";
	import { getReportTypesForJob } from "../../constants/index";
	import type { JobType } from "../../interfaces/IUser";

	interface Props {
		title: string;
		reportId: string;
		officer: string;
		type: string;
		created: number;
		lastUpdated: number;
		onTitleChange: (title: string) => void;
		onTypeChange: (type: string) => void;
		onInsertTemplate?: () => void;
		onSelectTemplate?: (template: TemplateOption) => void;
		availableTemplates?: TemplateOption[];
		showTemplateMenu?: boolean;
		jobType?: JobType;
	}

	let {
		title,
		reportId,
		officer,
		type,
		created,
		lastUpdated,
		onTitleChange,
		onTypeChange,
		onInsertTemplate,
		onSelectTemplate,
		availableTemplates = [],
		showTemplateMenu = false,
		jobType = 'leo',
	}: Props = $props();

	// Local state so parent re-renders don't reset inputs
	let localTitle = $state(title);
	let localType = $state(type);

	// Sync from parent only when the prop value actually differs from what we last sent
	$effect(() => { const t = title; untrack(() => { if (t !== localTitle) localTitle = t; }); });
	$effect(() => { const t = type; untrack(() => { if (t !== localType) localType = t; }); });

	function handleTitleInput() {
		onTitleChange(localTitle);
	}

	function handleTypeChange() {
		onTypeChange(localType);
	}

	let matchingTemplates = $derived(availableTemplates.filter((t) => t.type === localType));

	let reportTypes = $derived(getReportTypesForJob(jobType));

	function formatDate(timestamp: number): string {
		return new Date(timestamp).toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	function formatTime(timestamp: number): string {
		return new Date(timestamp).toLocaleTimeString("en-US", {
			hour: "2-digit",
			minute: "2-digit",
			hour12: false,
		});
	}
</script>

<div class="report-info">
	<input
		type="text"
		placeholder="Report Title"
		bind:value={localTitle}
		oninput={handleTitleInput}
		class="title-input"
	/>

	<div class="metadata-row">
		<div class="metadata-item">
			<span class="metadata-label">ID</span>
			<span class="metadata-value">{reportId}</span>
		</div>
		<div class="metadata-item">
			<span class="metadata-label">Officer</span>
			<span class="metadata-value officer-value">
				{#if officer.startsWith('NO CALLSIGN')}
					<span class="officer-badge no-callsign">NO CALLSIGN</span>
					<span>{officer.replace('NO CALLSIGN', '').trim()}</span>
				{:else if officer.includes(' ')}
					<span class="officer-badge">{officer.split(' ')[0]}</span>
					<span>{officer.split(' ').slice(1).join(' ')}</span>
				{:else}
					{officer}
				{/if}
			</span>
		</div>
		<div class="metadata-item">
			<label for="type-select" class="metadata-label">Type</label>
			<select
				id="type-select"
				bind:value={localType}
				onchange={handleTypeChange}
				class="type-select"
			>
				{#each reportTypes as reportType}
					<option value={reportType}>{reportType}</option>
				{/each}
			</select>
		</div>
		{#if onInsertTemplate && matchingTemplates.length > 0}
			<div class="metadata-item template-item">
				<span class="metadata-label">Template</span>
				<div class="template-wrapper">
					<button class="template-btn" onclick={onInsertTemplate} type="button">
						<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
						{matchingTemplates.length === 1 ? "Insert" : "Insert..."}
					</button>
					{#if showTemplateMenu && matchingTemplates.length > 1 && onSelectTemplate}
						<div class="template-dropdown">
							{#each matchingTemplates as tmpl (tmpl.id)}
								<button class="template-dropdown-item" onclick={() => onSelectTemplate(tmpl)} type="button">
									{tmpl.name}
								</button>
							{/each}
						</div>
					{/if}
				</div>
			</div>
		{/if}
		<div class="metadata-item">
			<span class="metadata-label">Created</span>
			<span class="metadata-value">
				{formatDate(created)} {formatTime(created)}
			</span>
		</div>
	</div>
</div>

<style>
	.report-info {
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.title-input {
		width: 100%;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.9);
		font-size: 15px;
		font-weight: 500;
		margin-bottom: 10px;
		padding: 2px 0 6px;
	}

	.title-input:focus {
		border-bottom-color: rgba(255, 255, 255, 0.1);
		outline: none;
	}

	.title-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.metadata-row {
		display: flex;
		align-items: flex-start;
		gap: 0;
	}

	.metadata-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 0 14px;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.metadata-item:first-child {
		padding-left: 0;
	}

	.metadata-item:last-child {
		border-right: none;
	}

	.metadata-item label,
	.metadata-item .metadata-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.metadata-value {
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		font-weight: 400;
	}

	.officer-value {
		display: flex;
		align-items: center;
		gap: 5px;
	}

	.officer-badge {
		background: rgba(var(--accent-rgb), 0.1);
		border: 1px solid rgba(var(--accent-rgb), 0.2);
		color: rgba(var(--accent-text-rgb), 0.8);
		font-size: 9px;
		font-weight: 600;
		padding: 1px 6px;
		border-radius: 3px;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.officer-badge.no-callsign {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
	}

	.type-select {
		padding: 2px 22px 2px 6px;
		font-size: 10px;
		font-weight: 500;
		border-radius: 3px;
	}

	.template-btn {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		background: transparent;
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 2px 7px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		white-space: nowrap;
		transition: all 0.1s;
	}

	.template-btn:hover {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.6);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.template-wrapper {
		position: relative;
	}

	.template-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		margin-top: 3px;
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		min-width: 140px;
		z-index: 20;
		padding: 2px;
		display: flex;
		flex-direction: column;
	}

	.template-dropdown-item {
		display: block;
		width: 100%;
		text-align: left;
		background: transparent;
		border: none;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.6);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		border-radius: 2px;
		transition: all 0.1s;
	}

	.template-dropdown-item:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.85);
	}

	@media (max-width: 1024px) {
		.metadata-row {
			flex-wrap: wrap;
		}
	}
</style>
