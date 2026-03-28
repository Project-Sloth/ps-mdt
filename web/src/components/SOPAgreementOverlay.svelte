<script lang="ts">
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { APP_INFO } from "../constants";
	import type { AuthService } from "../services/authService.svelte";

	interface Props {
		authService: AuthService;
		onAcknowledged: () => void;
		introduction: string;
		missionStatement?: string;
	}

	let { authService, onAcknowledged, introduction, missionStatement = "" }: Props = $props();

	let agreed = $state(false);
	let submitting = $state(false);

	let info = $derived(APP_INFO[authService.jobType] || APP_INFO.leo);

	async function handleAcknowledge() {
		if (!agreed || submitting) return;
		submitting = true;
		try {
			const result = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.SOP.ACKNOWLEDGE_SOP,
				{},
				{ success: true },
			);
			if (result?.success) {
				onAcknowledged();
			}
		} catch {
			// retry allowed
		} finally {
			submitting = false;
		}
	}
</script>

<div class="sop-overlay">
	<div class="sop-card">
		<!-- Top badge bar -->
		<div class="sop-badge-bar">
			<span class="material-icons badge-icon">{info.icon}</span>
			<span class="badge-dept">{info.title}</span>
		</div>

		<!-- Title area -->
		<div class="sop-header">
			<h2 class="sop-title">Standard Operating Procedures</h2>
			<p class="sop-subtitle">Review the following before accessing the terminal</p>
		</div>

		<!-- Scrollable content -->
		<div class="sop-body">
			{#if missionStatement}
				<div class="sop-section mission-section">
					<div class="section-label">
						<span class="material-icons label-icon">flag</span>
						<span>Mission Statement</span>
					</div>
					<div class="section-card">
						<div class="section-content">
							{@html missionStatement}
						</div>
					</div>
				</div>
			{/if}

			{#if introduction}
				<div class="sop-section intro-section">
					<div class="section-label">
						<span class="material-icons label-icon">gavel</span>
						<span>Terms of Access</span>
					</div>
					<div class="section-card intro-card">
						<div class="section-content">
							{@html introduction}
						</div>
					</div>
				</div>
			{:else}
				<div class="sop-section intro-section">
					<div class="section-label">
						<span class="material-icons label-icon">gavel</span>
						<span>Terms of Access</span>
					</div>
					<div class="section-card intro-card">
						<div class="section-content">
							<p>The Standard Operating Procedures have been updated. By acknowledging below, you confirm that you have read, understand, and agree to comply with all department policies and procedures.</p>
						</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Fixed bottom -->
		<div class="sop-footer">
			<label class="sop-agree-row">
				<input type="checkbox" bind:checked={agreed} class="sop-checkbox" />
				<span class="agree-text">I have read, understand, and agree to abide by the Standard Operating Procedures</span>
			</label>

			<button
				class="sop-btn"
				class:disabled={!agreed || submitting}
				disabled={!agreed || submitting}
				onclick={handleAcknowledge}
			>
				{#if submitting}
					<div class="btn-spinner"></div>
					Processing...
				{:else}
					<span class="material-icons btn-icon">verified</span>
					Acknowledge & Continue
				{/if}
			</button>
		</div>
	</div>
</div>

<style>
	.sop-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		display: flex;
		z-index: 1000;
		animation: fadeIn 0.5s ease-out;
	}

	.sop-card {
		background: var(--dark-bg, #111);
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		animation: fadeIn 0.4s ease-out;
		overflow: hidden;
	}

	/* Badge bar */
	.sop-badge-bar {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 14px 24px;
		background: rgba(255, 255, 255, 0.02);
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
		flex-shrink: 0;
	}

	.badge-icon {
		font-size: 18px;
		color: var(--accent-70);
	}

	.badge-dept {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.5);
		text-transform: uppercase;
		letter-spacing: 1.5px;
	}

	/* Header */
	.sop-header {
		padding: 20px 36px 16px;
		text-align: center;
		flex-shrink: 0;
	}

	.sop-title {
		color: rgba(255, 255, 255, 0.95);
		margin: 0 0 4px 0;
		font-size: 18px;
		font-weight: 700;
		letter-spacing: -0.3px;
	}

	.sop-subtitle {
		color: rgba(255, 255, 255, 0.35);
		font-size: 12px;
		margin: 0;
	}

	/* Body */
	.sop-body {
		flex: 1;
		overflow-y: auto;
		padding: 0 36px 20px;
		display: flex;
		gap: 16px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	/* Sections */
	.sop-section {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
	}

	.section-label {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 10px;
		font-weight: 700;
		color: var(--accent-70);
		text-transform: uppercase;
		letter-spacing: 1px;
		margin-bottom: 8px;
		padding-left: 2px;
	}

	.label-icon {
		font-size: 13px;
	}

	.section-card {
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 10px;
		padding: 18px 22px;
		flex: 1;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.intro-card {
		background: rgba(var(--accent-rgb, 59, 130, 246), 0.03);
		border-color: rgba(var(--accent-rgb, 59, 130, 246), 0.1);
	}

	.section-content {
		color: rgba(255, 255, 255, 0.75);
		font-size: 12.5px;
		line-height: 1.75;
	}

	.section-content :global(strong) {
		color: rgba(255, 255, 255, 0.95);
		font-weight: 600;
	}

	.section-content :global(em) {
		color: rgba(255, 255, 255, 0.65);
	}

	.section-content :global(p) {
		margin: 6px 0;
	}

	.section-content :global(p:first-child) {
		margin-top: 0;
	}

	.section-content :global(p:last-child) {
		margin-bottom: 0;
	}

	.section-content :global(ul),
	.section-content :global(ol) {
		padding-left: 18px;
		margin: 6px 0;
	}

	.section-content :global(li) {
		margin: 3px 0;
	}

	/* Footer */
	.sop-footer {
		padding: 16px 36px 20px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		flex-shrink: 0;
		background: rgba(255, 255, 255, 0.01);
	}

	.sop-agree-row {
		display: flex;
		align-items: center;
		gap: 10px;
		cursor: pointer;
		padding: 10px 16px;
		background: rgba(255, 255, 255, 0.025);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		flex: 1;
		max-width: 520px;
		transition: border-color 0.15s;
	}

	.sop-agree-row:hover {
		border-color: rgba(255, 255, 255, 0.12);
	}

	.sop-checkbox {
		accent-color: var(--accent-70);
		width: 16px;
		height: 16px;
		flex-shrink: 0;
		cursor: pointer;
	}

	.agree-text {
		font-size: 11.5px;
		color: rgba(255, 255, 255, 0.6);
		line-height: 1.4;
	}

	.sop-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 11px 32px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		background: var(--accent-15);
		color: var(--accent-text);
		border: 1px solid var(--accent-20);
		transition: all 0.15s ease;
		min-width: 220px;
	}

	.sop-btn:hover:not(.disabled) {
		background: var(--accent-25);
		border-color: var(--accent-35);
	}

	.sop-btn.disabled {
		opacity: 0.35;
		cursor: not-allowed;
	}

	.btn-icon {
		font-size: 17px;
	}

	.btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.15);
		border-left-color: var(--accent-60);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes fadeIn {
		0% { opacity: 0; }
		100% { opacity: 1; }
	}

	@keyframes slideUp {
		0% { opacity: 0; transform: translateY(16px); }
		100% { opacity: 1; transform: translateY(0); }
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
