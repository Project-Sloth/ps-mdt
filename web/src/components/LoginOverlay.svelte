<script lang="ts">
	import { getAppInfo } from "../constants";
	import type { AuthService } from "../services/authService.svelte";

	interface Props {
		authService: AuthService;
	}

	let { authService }: Props = $props();

	let info = $derived(getAppInfo(authService.jobType));

	/** The job the character is actually holding, for the no-access case. */
	let currentJob = $derived(authService.playerData?.job?.label ?? "");

	/**
	 * One state drives the whole card: band colour, eyebrow, icon and copy.
	 * Deriving it once keeps the markup from re-testing the same conditions
	 * in four places.
	 */
	type LoginState = "checking" | "denied" | "offduty" | "error";

	let state = $derived<LoginState>(
		authService.isCheckingAuth
			? "checking"
			: !authService.isLEO
				? "denied"
				: !authService.onDuty
					? "offduty"
					: "error",
	);

	/** Detail rows, skipping anything the server didn't send. */
	let identity = $derived(
		[
			{ label: "Rank", value: authService.playerData?.job?.grade?.name ?? "" },
			{ label: "Callsign", value: authService.playerData?.metadata?.callsign ?? "" },
			{ label: "Department", value: currentJob },
		].filter((row) => row.value),
	);
</script>

<div class="overlay">
	<div class="panel state-{state}">
		<div class="band" aria-hidden="true"></div>

		<header class="dept">
			<span class="material-icons dept-icon">{info.icon}</span>
			<div class="dept-text">
				<span class="dept-name">{info.title}</span>
				<span class="dept-sub">{info.subtitle}</span>
			</div>
		</header>

		{#if state === "checking"}
			<div class="status">
				<div class="spinner"></div>
				<div class="status-text">
					<span class="eyebrow">Terminal</span>
					<h2 class="title">Authenticating</h2>
				</div>
			</div>
			<p class="lede">Verifying your credentials with the department server.</p>
		{:else if state === "denied"}
			<div class="status">
				<span class="material-icons status-icon">block</span>
				<div class="status-text">
					<span class="eyebrow">Access withheld</span>
					<h2 class="title">No terminal access</h2>
				</div>
			</div>
			<p class="lede">
				This terminal is issued to law enforcement, EMS and DOJ personnel.
				{#if currentJob}Your current job is <strong>{currentJob}</strong>.{/if}
			</p>
			<footer class="actions">
				<button class="btn" onclick={authService.closeUI}>Close terminal</button>
			</footer>
		{:else if state === "offduty"}
			<div class="status">
				<span class="material-icons status-icon">badge</span>
				<div class="status-text">
					<span class="eyebrow">Terminal locked</span>
					<h2 class="title">Off duty</h2>
				</div>
			</div>
			<p class="lede">
				Sign on to open the terminal — your session starts the moment you go on duty.
			</p>

			{#if identity.length > 0}
				<section class="block">
					<div class="block-head"><span class="block-title">Signing in as</span></div>
					<dl class="identity">
						{#each identity as row (row.label)}
							<div class="id-row">
								<dt>{row.label}</dt>
								<dd>{row.value}</dd>
							</div>
						{/each}
					</dl>
				</section>
			{/if}

			<footer class="actions">
				<button class="btn btn-primary" onclick={authService.goOnDuty}>
					<span class="material-icons btn-icon">login</span>
					Go on duty
				</button>
				<button class="btn" onclick={authService.closeUI}>Close terminal</button>
			</footer>
		{:else}
			<div class="status">
				<span class="material-icons status-icon">error_outline</span>
				<div class="status-text">
					<span class="eyebrow">Terminal fault</span>
					<h2 class="title">Sign-in failed</h2>
				</div>
			</div>
			<p class="lede">{authService.authError || "The terminal could not verify your credentials."}</p>
			<footer class="actions">
				<button class="btn" onclick={authService.closeUI}>Close terminal</button>
			</footer>
		{/if}

		<div class="foot">
			<span class="foot-version">{info.version}</span>
			<span class="foot-notice">{info.footerSubtext}</span>
		</div>
	</div>
</div>

<style>
	/* Solid, never backdrop-filter: CEF paints the blur as a black block.
	   The faint plan grid matches the restricted-section panel. */
	.overlay {
		position: absolute;
		inset: 0;
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 40px 24px;
		background-color: rgb(8, 8, 9);
		background-image:
			radial-gradient(ellipse at 50% 40%, rgba(255, 255, 255, 0.03), transparent 62%),
			repeating-linear-gradient(
				0deg,
				rgba(255, 255, 255, 0.016) 0px,
				rgba(255, 255, 255, 0.016) 1px,
				transparent 1px,
				transparent 34px
			),
			repeating-linear-gradient(
				90deg,
				rgba(255, 255, 255, 0.016) 0px,
				rgba(255, 255, 255, 0.016) 1px,
				transparent 1px,
				transparent 34px
			);
	}

	.panel {
		position: relative;
		width: 100%;
		max-width: 440px;
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 14px;
		padding: 26px 30px 22px;
		overflow: hidden;
		animation: rise 0.24s ease-out;
	}

	:global([data-job-type="ems"]) .panel {
		background: rgb(16, 12, 12);
		border-color: rgba(220, 50, 50, 0.12);
	}

	/* The band carries the state: hatched while access is withheld, flat while
	   the terminal is merely waiting on the officer or the server. */
	.band {
		position: absolute;
		inset: 0 0 auto 0;
		height: 4px;
		background: var(--accent-35);
	}

	.state-offduty .band {
		background: repeating-linear-gradient(
			-45deg,
			rgba(245, 158, 11, 0.85) 0px,
			rgba(245, 158, 11, 0.85) 7px,
			rgba(245, 158, 11, 0.12) 7px,
			rgba(245, 158, 11, 0.12) 14px
		);
	}

	.state-denied .band,
	.state-error .band {
		background: repeating-linear-gradient(
			-45deg,
			rgba(239, 68, 68, 0.8) 0px,
			rgba(239, 68, 68, 0.8) 7px,
			rgba(239, 68, 68, 0.12) 7px,
			rgba(239, 68, 68, 0.12) 14px
		);
	}

	/* Department masthead */
	.dept {
		display: flex;
		align-items: center;
		gap: 12px;
		padding-bottom: 18px;
		margin-bottom: 18px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
	}

	.dept-icon {
		flex: none;
		font-size: 26px;
		color: var(--accent-60);
	}

	.dept-text {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
	}

	.dept-name {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
	}

	.dept-sub {
		font-size: 11px;
		letter-spacing: 0.02em;
		color: rgba(255, 255, 255, 0.35);
	}

	/* State header */
	.status {
		display: flex;
		align-items: center;
		gap: 14px;
		margin-bottom: 14px;
	}

	.status-icon,
	.spinner {
		flex: none;
		width: 44px;
		height: 44px;
		border-radius: 10px;
	}

	.status-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 20px;
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.state-offduty .status-icon {
		color: rgba(245, 158, 11, 0.8);
		background: rgba(245, 158, 11, 0.08);
		border-color: rgba(245, 158, 11, 0.18);
	}

	.state-denied .status-icon,
	.state-error .status-icon {
		color: rgba(239, 68, 68, 0.75);
		background: rgba(239, 68, 68, 0.07);
		border-color: rgba(239, 68, 68, 0.16);
	}

	.spinner {
		border: 3px solid rgba(255, 255, 255, 0.06);
		border-left-color: var(--accent-60);
		border-radius: 50%;
		width: 26px;
		height: 26px;
		margin: 9px;
		animation: spin 1s linear infinite;
	}

	.status-text {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 0;
	}

	.eyebrow {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.14em;
		text-transform: uppercase;
		color: rgba(255, 255, 255, 0.3);
	}

	.state-offduty .eyebrow {
		color: rgba(245, 158, 11, 0.7);
	}

	.state-denied .eyebrow,
	.state-error .eyebrow {
		color: rgba(239, 68, 68, 0.65);
	}

	.title {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
		line-height: 1.2;
		color: rgba(255, 255, 255, 0.92);
	}

	.lede {
		margin: 0;
		font-size: 13px;
		line-height: 1.6;
		color: rgba(255, 255, 255, 0.5);
	}

	.lede strong {
		font-weight: 500;
		color: rgba(255, 255, 255, 0.75);
	}

	.block {
		margin-top: 20px;
	}

	.block-head {
		padding-bottom: 8px;
		margin-bottom: 6px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.block-title {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: rgba(255, 255, 255, 0.35);
	}

	.identity {
		margin: 0;
		display: flex;
		flex-direction: column;
	}

	.id-row {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: 16px;
		padding: 7px 2px;
	}

	.id-row + .id-row {
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}

	.id-row dt {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.38);
	}

	.id-row dd {
		margin: 0;
		font-size: 13px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.8);
	}

	.actions {
		display: flex;
		gap: 8px;
		margin-top: 22px;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 9px 16px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
		font-family: inherit;
		cursor: pointer;
		transition:
			background 0.15s ease,
			color 0.15s ease,
			border-color 0.15s ease;
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.55);
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.btn:hover {
		background: rgba(255, 255, 255, 0.07);
		color: rgba(255, 255, 255, 0.9);
		border-color: rgba(255, 255, 255, 0.15);
	}

	.btn-primary {
		background: var(--accent-10);
		color: var(--accent-text);
		border-color: var(--accent-25);
	}

	.btn-primary:hover {
		background: var(--accent-20);
		color: var(--accent-text);
		border-color: var(--accent-35);
	}

	.btn-icon {
		font-size: 16px;
	}

	.foot {
		display: flex;
		flex-direction: column;
		gap: 3px;
		margin-top: 22px;
		padding-top: 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.05);
	}

	.foot-version {
		font-size: 11px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.32);
	}

	.foot-notice {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: rgba(255, 255, 255, 0.18);
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@keyframes rise {
		0% { opacity: 0; transform: translateY(10px); }
		100% { opacity: 1; transform: translateY(0); }
	}

	@media (prefers-reduced-motion: reduce) {
		.panel { animation: none; }
	}
</style>