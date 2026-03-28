<script lang="ts">
	import type { DashboardData } from "../../interfaces/IDashboard";

	let {
		report,
		isExpanded = false,
		onToggle,
		onNavigate,
	}: {
		report: DashboardData["recentReports"][0];
		isExpanded?: boolean;
		onToggle: (id: number) => void;
		onNavigate: (id: number) => void;
	} = $props();
</script>

<div class="report-item" class:expanded={isExpanded}>
	<div class="report-row">
		<div class="report-main">
			<div class="report-title">{report.title}</div>
			<div class="report-meta">
				<span class="report-id">{report.id}</span>
				<span class="dot"></span>
				<span class="report-author">{report.author}</span>
				<span class="dot"></span>
				<span class="report-date">{new Date(report.datecreated).toLocaleDateString()}</span>
			</div>
		</div>
		<div class="report-actions">
			<button class="action-btn" onclick={() => onToggle(report.id)} title={isExpanded ? "Hide preview" : "Quick view"}>
				<span class="material-icons">{isExpanded ? "visibility_off" : "visibility"}</span>
			</button>
			<button class="action-btn goto" onclick={() => onNavigate(report.id)} title="Go to report">
				<span class="material-icons">open_in_new</span>
			</button>
		</div>
	</div>
	{#if isExpanded}
		<div class="report-body">
			<div class="body-label">Details</div>
			<div class="body-content">{@html report.contentplaintext}</div>
		</div>
	{/if}
</div>

<style>
	.report-item {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 9px 10px;
		transition: background 0.1s;
		flex-shrink: 0;
	}

	.report-item:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.report-item.expanded {
		background: rgba(255, 255, 255, 0.03);
	}

	.report-row {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.report-main {
		flex: 1;
		min-width: 0;
	}

	.report-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 600;
		margin-bottom: 3px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.report-meta {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 11px;
	}

	.report-id {
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
	}

	.report-author {
		color: rgba(255, 255, 255, 0.35);
	}

	.report-date {
		color: rgba(255, 255, 255, 0.35);
	}

	.dot {
		width: 2px;
		height: 2px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
	}

	.report-actions {
		display: flex;
		align-items: center;
		gap: 2px;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.report-item:hover .report-actions {
		opacity: 1;
	}

	.action-btn {
		background: transparent;
		color: rgba(255, 255, 255, 0.35);
		border: none;
		padding: 4px;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.1s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.action-btn .material-icons {
		font-size: 16px;
	}

	.action-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		background: rgba(255, 255, 255, 0.04);
	}

	.action-btn.goto:hover {
		color: rgba(var(--accent-rgb), 0.8);
	}

	.report-body {
		margin-top: 8px;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}

	.body-label {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		margin-bottom: 5px;
	}

	.body-content {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		line-height: 1.5;
	}
</style>
