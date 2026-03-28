<script lang="ts">
	import { APP_INFO } from "../constants";
	import type { AuthService } from "../services/authService.svelte";

	interface Props {
		authService: AuthService;
	}

	let { authService }: Props = $props();

	let info = $derived(APP_INFO[authService.jobType] || APP_INFO.leo);
</script>

<div class="login-overlay">
	<div class="login-card">
		<div class="login-header">
			<span class="material-icons badge-icon">{info.icon}</span>
			<h2 class="dept-name">{info.title}</h2>
			<span class="dept-subtitle">{info.subtitle}</span>
		</div>

		{#if authService.isCheckingAuth}
			<div class="login-body">
				<div class="loading-spinner"></div>
				<span class="body-title">Authenticating</span>
				<span class="body-desc">Verifying credentials...</span>
			</div>
		{:else if !authService.isLEO}
			<div class="login-body">
				<span class="material-icons status-icon error">block</span>
				<span class="body-title error">Access Denied</span>
				<span class="body-desc">This terminal is restricted to authorized personnel</span>
				<div class="login-actions">
					<button class="btn btn-outline" onclick={authService.closeUI}>
						Close Terminal
					</button>
				</div>
			</div>
		{:else if authService.isLEO && !authService.onDuty}
			<div class="login-body">
				<span class="material-icons status-icon warning">warning_amber</span>
				<span class="body-title warning">Off Duty</span>
				<span class="body-desc">You must be on duty to access the MDT system</span>
				<div class="login-actions">
					<button class="btn btn-primary" onclick={authService.goOnDuty}>
						<span class="material-icons btn-icon">login</span>
						Go On Duty
					</button>
					<button class="btn btn-outline" onclick={authService.closeUI}>
						Close Terminal
					</button>
				</div>
			</div>
		{:else}
			<div class="login-body">
				<span class="material-icons status-icon error">error_outline</span>
				<span class="body-title error">Authentication Error</span>
				<span class="body-desc">{authService.authError}</span>
				<div class="login-actions">
					<button class="btn btn-outline" onclick={authService.closeUI}>
						Close Terminal
					</button>
				</div>
			</div>
		{/if}

		<div class="login-footer">
			<span class="footer-version">{info.version}</span>
			<span class="footer-notice">{info.footerSubtext}</span>
		</div>
	</div>
</div>

<style>
	.login-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.85);
		backdrop-filter: blur(12px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.login-card {
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 16px;
		padding: 40px 48px;
		text-align: center;
		min-width: 380px;
		max-width: 440px;
		animation: fadeIn 0.4s ease-out;
	}

	:global([data-job-type="ems"]) .login-card {
		background: rgb(16, 12, 12);
		border-color: rgba(220, 50, 50, 0.12);
	}

	/* Header */
	.login-header {
		margin-bottom: 28px;
		padding-bottom: 24px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.badge-icon {
		font-size: 42px;
		color: var(--accent-70);
		display: block;
		margin-bottom: 16px;
	}

	.dept-name {
		color: rgba(255, 255, 255, 0.95);
		margin: 0 0 6px 0;
		font-size: 20px;
		font-weight: 700;
		letter-spacing: -0.3px;
	}

	.dept-subtitle {
		color: rgba(255, 255, 255, 0.4);
		font-size: 13px;
		font-weight: 400;
		letter-spacing: 0.5px;
	}

	/* Body */
	.login-body {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 6px;
		margin-bottom: 28px;
	}

	.status-icon {
		font-size: 36px;
		margin-bottom: 8px;
	}

	.status-icon.warning {
		color: rgba(234, 179, 8, 0.8);
	}

	.status-icon.error {
		color: rgba(239, 68, 68, 0.7);
	}

	.body-title {
		font-size: 18px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
	}

	.body-title.warning {
		color: rgba(234, 179, 8, 0.9);
	}

	.body-title.error {
		color: rgba(239, 68, 68, 0.8);
	}

	.body-desc {
		font-size: 13px;
		color: rgba(255, 255, 255, 0.45);
		line-height: 1.5;
		max-width: 300px;
	}

	/* Actions */
	.login-actions {
		display: flex;
		gap: 10px;
		margin-top: 18px;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 10px 22px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		border: none;
	}

	.btn-icon {
		font-size: 16px;
	}

	.btn-primary {
		background: var(--accent-15);
		color: var(--accent-text);
		border: 1px solid var(--accent-20);
	}

	.btn-primary:hover {
		background: var(--accent-25);
		border-color: var(--accent-35);
	}

	.btn-outline {
		background: transparent;
		color: rgba(255, 255, 255, 0.5);
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.btn-outline:hover {
		color: rgba(255, 255, 255, 0.8);
		background: rgba(255, 255, 255, 0.04);
		border-color: rgba(255, 255, 255, 0.15);
	}

	/* Loading */
	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid rgba(255, 255, 255, 0.06);
		border-left: 3px solid var(--accent-60);
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 12px;
	}

	/* Footer */
	.login-footer {
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		padding-top: 18px;
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.footer-version {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		font-weight: 500;
	}

	.footer-notice {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
		text-transform: uppercase;
		letter-spacing: 1px;
		font-weight: 600;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@keyframes fadeIn {
		0% { opacity: 0; transform: translateY(12px); }
		100% { opacity: 1; transform: translateY(0); }
	}
</style>
