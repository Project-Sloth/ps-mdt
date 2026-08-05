<script lang="ts">
	import { getPermissionMeta } from "../constants/management";

	interface Props {
		/** Human readable name of the section that was blocked */
		pageLabel: string;
		/** Permission keys that would grant access (any one is enough) */
		requiredPermissions?: string[];
		/** Rank / grade name of the signed in officer */
		rank?: string;
		/** Callsign of the signed in officer */
		callsign?: string;
		/** Department label */
		department?: string;
		/** Sections the officer can open instead, in sidebar order */
		suggestions?: { tab: string; label: string; icon: string }[];
		/** Called when the officer chooses to leave the section */
		onBack: () => void;
		/** Called with a tab name when a suggested section is chosen */
		onOpen?: (tab: string) => void;
	}

	let {
		pageLabel,
		requiredPermissions = [],
		rank = "",
		callsign = "",
		department = "",
		suggestions = [],
		onBack,
		onOpen,
	}: Props = $props();

	let copied = $state(false);
	let copyTimer: ReturnType<typeof setTimeout> | undefined;

	const grants = $derived(
		requiredPermissions
			.map((key) => ({ key, meta: getPermissionMeta(key) }))
			.filter((entry) => entry.meta !== undefined),
	);

	const identity = $derived(
		[
			{ label: "Rank", value: rank },
			{ label: "Callsign", value: callsign },
			{ label: "Department", value: department },
		].filter((row) => row.value),
	);

	function buildRequestText(): string {
		const lines = [
			`MDT access request — ${pageLabel}`,
			rank || callsign ? `Officer: ${[rank, callsign].filter(Boolean).join(" · ")}` : "",
			"",
			"Grants access (any one of):",
			...grants.map((g) => `  ${g.key} — ${g.meta?.label}`),
		];
		return lines.filter((line) => line !== undefined).join("\n");
	}

	/** CEF has no navigator.clipboard, so fall back to a hidden textarea */
	function copyRequest() {
		try {
			const textarea = document.createElement("textarea");
			textarea.value = buildRequestText();
			textarea.style.position = "fixed";
			textarea.style.opacity = "0";
			document.body.appendChild(textarea);
			textarea.select();
			document.execCommand("copy");
			document.body.removeChild(textarea);

			copied = true;
			if (copyTimer !== undefined) clearTimeout(copyTimer);
			copyTimer = setTimeout(() => (copied = false), 2000);
		} catch {
			// silent — copying is a convenience, not a requirement
		}
	}
</script>

<div class="restricted">
	<div class="column">
	<div class="panel">
		<div class="hatch" aria-hidden="true"></div>

		<header class="head">
			<span class="material-icons head-icon">lock</span>
			<div class="head-text">
				<span class="eyebrow">Restricted section</span>
				<h2 class="title">{pageLabel}</h2>
			</div>
		</header>

		<p class="lede">
			Your rank doesn't carry the clearance this section needs. Nothing is missing from your
			account — it simply hasn't been granted yet.
		</p>

		{#if grants.length > 0}
			<section class="block">
				<div class="block-head">
					<span class="block-title">Access requires any one of</span>
					<span class="block-count">{grants.length}</span>
				</div>

				<ul class="grants">
					{#each grants as grant (grant.key)}
						<li class="grant">
							<span class="marker" aria-hidden="true"></span>
							<div class="grant-body">
								<span class="grant-label">{grant.meta?.label}</span>
								<span class="grant-desc">{grant.meta?.description}</span>
							</div>
							<span class="grant-cat">{grant.meta?.category}</span>
						</li>
					{/each}
				</ul>
			</section>
		{/if}

		{#if identity.length > 0}
			<section class="block">
				<div class="block-head">
					<span class="block-title">Signed in as</span>
				</div>
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
			<button class="btn btn-primary" onclick={onBack}>
				<span class="material-icons btn-icon">arrow_back</span>
				Back to Dashboard
			</button>
			{#if grants.length > 0}
				<button class="btn" onclick={copyRequest}>
					<span class="material-icons btn-icon">{copied ? "check" : "content_copy"}</span>
					{copied ? "Copied" : "Copy request details"}
				</button>
			{/if}
		</footer>
	</div>

	{#if suggestions.length > 0}
		<nav class="elsewhere">
			<span class="elsewhere-title">Open instead</span>
			<div class="chips">
				{#each suggestions as item (item.tab)}
					<button class="chip" onclick={() => onOpen?.(item.tab)}>
						<span class="material-icons chip-icon">{item.icon}</span>
						{item.label}
					</button>
				{/each}
			</div>
		</nav>
	{/if}
	</div>
</div>

<style>
	/* A faint plan-room grid keeps the space around the panel from reading as a
	   blank page, without competing with it for attention. */
	.restricted {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 100%;
		padding: 40px 24px;
		background-color: var(--card-dark-bg);
		background-image:
			radial-gradient(ellipse at 50% 38%, rgba(245, 158, 11, 0.045), transparent 62%),
			repeating-linear-gradient(
				0deg,
				rgba(255, 255, 255, 0.018) 0px,
				rgba(255, 255, 255, 0.018) 1px,
				transparent 1px,
				transparent 34px
			),
			repeating-linear-gradient(
				90deg,
				rgba(255, 255, 255, 0.018) 0px,
				rgba(255, 255, 255, 0.018) 1px,
				transparent 1px,
				transparent 34px
			);
	}

	.column {
		width: 100%;
		max-width: 520px;
	}

	.panel {
		position: relative;
		width: 100%;
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 14px;
		padding: 30px 30px 26px;
		overflow: hidden;
		animation: rise 0.22s ease-out;
	}

	/* Signature: a restricted-document hazard band across the top edge */
	.hatch {
		position: absolute;
		inset: 0 0 auto 0;
		height: 4px;
		background: repeating-linear-gradient(
			-45deg,
			rgba(245, 158, 11, 0.85) 0px,
			rgba(245, 158, 11, 0.85) 7px,
			rgba(245, 158, 11, 0.12) 7px,
			rgba(245, 158, 11, 0.12) 14px
		);
	}

	.head {
		display: flex;
		align-items: center;
		gap: 14px;
		margin-bottom: 16px;
	}

	.head-icon {
		flex: none;
		width: 44px;
		height: 44px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 20px;
		color: rgba(245, 158, 11, 0.8);
		background: rgba(245, 158, 11, 0.08);
		border: 1px solid rgba(245, 158, 11, 0.18);
		border-radius: 10px;
	}

	.head-text {
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
		color: rgba(245, 158, 11, 0.7);
	}

	.title {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
		line-height: 1.2;
		color: rgba(255, 255, 255, 0.92);
	}

	.lede {
		margin: 0 0 22px;
		font-size: 13px;
		line-height: 1.6;
		color: rgba(255, 255, 255, 0.5);
	}

	.block + .block {
		margin-top: 20px;
	}

	.block-head {
		display: flex;
		align-items: center;
		gap: 10px;
		padding-bottom: 8px;
		margin-bottom: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.block-title {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: rgba(255, 255, 255, 0.35);
	}

	.block-count {
		font-size: 10px;
		font-weight: 600;
		line-height: 1;
		padding: 3px 6px;
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.45);
		background: rgba(255, 255, 255, 0.05);
	}

	.grants {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.grant {
		display: flex;
		align-items: flex-start;
		gap: 11px;
		padding: 9px 10px;
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.02);
	}

	.marker {
		flex: none;
		width: 9px;
		height: 9px;
		margin-top: 4px;
		border: 1.5px solid rgba(245, 158, 11, 0.45);
		border-radius: 2px;
	}

	.grant-body {
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 0;
		flex: 1;
	}

	.grant-label {
		font-size: 13px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.85);
	}

	.grant-desc {
		font-size: 12px;
		line-height: 1.5;
		color: rgba(255, 255, 255, 0.42);
	}

	.grant-cat {
		flex: none;
		font-size: 10px;
		letter-spacing: 0.04em;
		color: rgba(255, 255, 255, 0.28);
		padding-top: 2px;
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
		padding: 7px 10px;
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
		margin-top: 24px;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 9px 16px;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
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

	@keyframes rise {
		0% {
			opacity: 0;
			transform: translateY(8px);
		}
		100% {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.elsewhere {
		display: flex;
		flex-direction: column;
		gap: 10px;
		margin-top: 20px;
		padding: 0 4px;
		animation: rise 0.22s ease-out 0.06s backwards;
	}

	.elsewhere-title {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.12em;
		text-transform: uppercase;
		color: rgba(255, 255, 255, 0.28);
	}

	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
	}

	.chip {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 7px 12px 7px 10px;
		border-radius: 999px;
		font-size: 12px;
		font-weight: 500;
		font-family: inherit;
		cursor: pointer;
		color: rgba(255, 255, 255, 0.55);
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.07);
		transition:
			background 0.15s ease,
			color 0.15s ease,
			border-color 0.15s ease;
	}

	.chip:hover {
		background: var(--accent-10);
		color: var(--accent-text);
		border-color: var(--accent-25);
	}

	.chip-icon {
		font-size: 15px;
		opacity: 0.75;
	}

	@media (prefers-reduced-motion: reduce) {
		.panel,
		.elsewhere {
			animation: none;
		}
	}
</style>