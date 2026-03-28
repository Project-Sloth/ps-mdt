<script lang="ts">
	import { REPORT_TYPES } from "../constants";
	import type { Report } from "../interfaces/IReportEditor";

	export let report: Report;
	export let formatDate: (timestamp: number) => string;
	export let formatTime: (timestamp: number) => string;
</script>

<section class="report-metadata" aria-label="Report information">
	<div class="metadata-row">
		<div class="metadata-item">
			<label for="report-id" class="metadata-label">Report ID</label>
			<span id="report-id" class="metadata-value">{report.reportId}</span>
		</div>
		<div class="metadata-item">
			<label for="report-officer" class="metadata-label">Officer</label>
			<span id="report-officer" class="metadata-value"
				>{report.officer}</span
			>
		</div>
		<div class="metadata-item">
			<label for="report-type" class="metadata-label">Type</label>
			<select
				id="report-type"
				bind:value={report.type}
				class="type-select"
				aria-label="Report type"
			>
				{#each REPORT_TYPES as type}
					<option value={type}>{type}</option>
				{/each}
			</select>
		</div>
		<div class="metadata-item">
			<label for="report-created" class="metadata-label">Created</label>
			<span id="report-created" class="metadata-value">
				{formatDate(report.created)}
				{formatTime(report.created)}
			</span>
		</div>
		<div class="metadata-item">
			<label for="report-updated" class="metadata-label"
				>Last Updated</label
			>
			<span id="report-updated" class="metadata-value">
				{formatDate(report.lastUpdated)}
				{formatTime(report.lastUpdated)}
			</span>
		</div>
	</div>
</section>

<style>
	.report-metadata {
		padding: 1rem;
		background: var(--surface-elevated);
		border-radius: 0.5rem;
		margin-bottom: 1rem;
	}

	.metadata-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.metadata-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.metadata-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--text-secondary);
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.metadata-value {
		font-size: 0.875rem;
		color: var(--text-primary);
		padding: 0.25rem 0;
	}

	.type-select {
		padding: 0.375rem 1.75rem 0.375rem 0.75rem;
		font-size: 0.875rem;
	}
</style>
