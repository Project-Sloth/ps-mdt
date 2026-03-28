<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { isEnvBrowser } from "../utils/misc";
	import { GetParentResourceName } from "../utils/fivem";

	let visible = $state(false);
	let zoomLevel = $state(1.0);
	let citizenName = $state("");
	let flashActive = $state(false);

	/** Direct NUI post - bypasses fetchNui whitelist since this is a camera-only callback */
	function postCameraAction(payload: Record<string, any>) {
		if (isEnvBrowser()) return;
		const resourceName = GetParentResourceName();
		fetch(`https://${resourceName}/mugshotCameraAction`, {
			method: "POST",
			headers: { "Content-Type": "application/json; charset=UTF-8" },
			body: JSON.stringify(payload),
		}).catch(() => {});
	}

	function handleMessage(event: MessageEvent) {
		const { action, data } = event.data || {};
		if (action === "showMugshotCamera") {
			visible = true;
			zoomLevel = 1.0;
			citizenName = data?.name || "SUBJECT";
			flashActive = false;
		} else if (action === "hideMugshotCamera") {
			visible = false;
		} else if (action === "mugshotFlash") {
			flashActive = true;
			setTimeout(() => { flashActive = false; }, 150);
		} else if (action === "updateMugshotZoom") {
			if (data?.level !== undefined) {
				zoomLevel = Math.round(data.level * 10) / 10;
			}
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (!visible) return;
		if (e.code === "Escape") {
			e.preventDefault();
			e.stopPropagation();
			postCameraAction({ action: "cancel" });
		}
	}

	function capture() {
		postCameraAction({ action: "capture" });
	}

	function cancel() {
		postCameraAction({ action: "cancel" });
	}

	function zoomIn() {
		zoomLevel = Math.min(zoomLevel + 0.5, 5.0);
		postCameraAction({ action: "zoom", level: zoomLevel });
	}

	function zoomOut() {
		zoomLevel = Math.max(zoomLevel - 0.5, 1.0);
		postCameraAction({ action: "zoom", level: zoomLevel });
	}

	let zoomDisplay = $derived(`${zoomLevel.toFixed(1)}x`);
	let timestamp = $state("00:00:00");
	let timestampInterval: ReturnType<typeof setInterval> | null = null;
	let startTime = 0;

	function updateTimestamp() {
		const elapsed = Math.floor((Date.now() - startTime) / 1000);
		const h = String(Math.floor(elapsed / 3600)).padStart(2, "0");
		const m = String(Math.floor((elapsed % 3600) / 60)).padStart(2, "0");
		const s = String(elapsed % 60).padStart(2, "0");
		timestamp = `${h}:${m}:${s}`;
	}

	$effect(() => {
		if (visible) {
			startTime = Date.now();
			timestampInterval = setInterval(updateTimestamp, 1000);
		} else {
			if (timestampInterval) {
				clearInterval(timestampInterval);
				timestampInterval = null;
			}
			timestamp = "00:00:00";
		}
	});

	onMount(() => {
		window.addEventListener("message", handleMessage);
		window.addEventListener("keydown", handleKeydown);
	});

	onDestroy(() => {
		window.removeEventListener("message", handleMessage);
		window.removeEventListener("keydown", handleKeydown);
		if (timestampInterval) clearInterval(timestampInterval);
	});
</script>

{#if visible}
	<div class="camera-overlay" class:flash={flashActive}>
		<!-- Viewfinder corners -->
		<div class="corner top-left"></div>
		<div class="corner top-right"></div>
		<div class="corner bottom-left"></div>
		<div class="corner bottom-right"></div>

		<!-- Crosshair center -->
		<div class="crosshair">
			<div class="cross-h"></div>
			<div class="cross-v"></div>
		</div>

		<!-- Top status bar -->
		<div class="status-bar top">
			<div class="status-left">
				<span class="rec-indicator">
					<span class="rec-dot"></span>
					REC
				</span>
				<span class="timestamp">{timestamp}</span>
			</div>
			<div class="status-center">
				<span class="subject-label">MUGSHOT - {citizenName}</span>
			</div>
			<div class="status-right">
				<span class="dept-label">LSPD</span>
			</div>
		</div>

		<!-- Bottom info bar -->
		<div class="status-bar bottom">
			<div class="status-left">
				<span class="cam-spec">FULL HD</span>
				<span class="cam-spec">PNG</span>
				<span class="cam-spec">ISO 200</span>
			</div>
			<div class="status-center">
				<div class="zoom-controls">
					<button class="zoom-btn" onclick={zoomOut} disabled={zoomLevel <= 1.0}>
						<span class="material-icons">remove</span>
					</button>
					<span class="zoom-display">
						<span class="material-icons zoom-icon">search</span>
						{zoomDisplay} ZOOM
					</span>
					<button class="zoom-btn" onclick={zoomIn} disabled={zoomLevel >= 5.0}>
						<span class="material-icons">add</span>
					</button>
				</div>
			</div>
			<div class="status-right">
				<span class="hint">SCROLL to zoom</span>
			</div>
		</div>

		<!-- Action buttons -->
		<div class="action-bar">
			<button class="action-btn capture-btn" onclick={capture}>
				<span class="shutter-ring">
					<span class="shutter-inner"></span>
				</span>
			</button>
			<button class="action-btn cancel-btn" onclick={cancel}>
				<span class="material-icons">close</span>
				<span>ESC</span>
			</button>
		</div>

		<!-- Vignette overlay -->
		<div class="vignette"></div>

		<!-- Flash effect -->
		{#if flashActive}
			<div class="flash-overlay"></div>
		{/if}
	</div>
{/if}

<style>
	.camera-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		z-index: 9999;
		pointer-events: auto;
		user-select: none;
	}

	/* Viewfinder corners */
	.corner {
		position: absolute;
		width: 80px;
		height: 80px;
		z-index: 2;
	}

	.corner::before,
	.corner::after {
		content: "";
		position: absolute;
		background: rgba(255, 255, 255, 0.7);
	}

	.top-left { top: 12%; left: 15%; }
	.top-left::before { top: 0; left: 0; width: 80px; height: 3px; }
	.top-left::after { top: 0; left: 0; width: 3px; height: 80px; }

	.top-right { top: 12%; right: 15%; }
	.top-right::before { top: 0; right: 0; width: 80px; height: 3px; }
	.top-right::after { top: 0; right: 0; width: 3px; height: 80px; }

	.bottom-left { bottom: 12%; left: 15%; }
	.bottom-left::before { bottom: 0; left: 0; width: 80px; height: 3px; }
	.bottom-left::after { bottom: 0; left: 0; width: 3px; height: 80px; }

	.bottom-right { bottom: 12%; right: 15%; }
	.bottom-right::before { bottom: 0; right: 0; width: 80px; height: 3px; }
	.bottom-right::after { bottom: 0; right: 0; width: 3px; height: 80px; }

	/* Crosshair */
	.crosshair {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		z-index: 2;
	}

	.cross-h, .cross-v {
		position: absolute;
		background: rgba(255, 255, 255, 0.3);
	}

	.cross-h {
		width: 20px;
		height: 1px;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
	}

	.cross-v {
		width: 1px;
		height: 20px;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
	}

	/* Status bars */
	.status-bar {
		position: absolute;
		left: 0;
		right: 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 30px;
		z-index: 3;
	}

	.status-bar.top {
		top: 0;
		background: linear-gradient(to bottom, rgba(0, 0, 0, 0.5) 0%, transparent 100%);
		padding-top: 16px;
		padding-bottom: 30px;
	}

	.status-bar.bottom {
		bottom: 0;
		background: linear-gradient(to top, rgba(0, 0, 0, 0.5) 0%, transparent 100%);
		padding-bottom: 16px;
		padding-top: 30px;
	}

	.status-left, .status-right, .status-center {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.status-center {
		flex: 1;
		justify-content: center;
	}

	.rec-indicator {
		display: flex;
		align-items: center;
		gap: 6px;
		color: #ef4444;
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 1px;
		font-family: "Courier New", monospace;
	}

	.rec-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: #ef4444;
		animation: pulse-rec 1s ease-in-out infinite;
	}

	@keyframes pulse-rec {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.2; }
	}

	.timestamp {
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		font-family: "Courier New", monospace;
		letter-spacing: 1px;
	}

	.subject-label {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 2px;
		text-transform: uppercase;
	}

	.dept-label {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 2px;
	}

	.cam-spec {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-family: "Courier New", monospace;
		letter-spacing: 0.5px;
	}

	.hint {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-style: italic;
	}

	/* Zoom controls */
	.zoom-controls {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.zoom-btn {
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 50%;
		width: 28px;
		height: 28px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: rgba(255, 255, 255, 0.8);
		cursor: pointer;
		transition: all 0.15s ease;
		padding: 0;
	}

	.zoom-btn .material-icons {
		font-size: 16px;
	}

	.zoom-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.2);
		color: white;
	}

	.zoom-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.zoom-display {
		display: flex;
		align-items: center;
		gap: 4px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 1px;
		min-width: 90px;
		justify-content: center;
	}

	.zoom-icon {
		font-size: 14px;
		opacity: 0.6;
	}

	/* Action bar */
	.action-bar {
		position: absolute;
		right: 30px;
		top: 50%;
		transform: translateY(-50%);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
		z-index: 3;
	}

	.action-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.15s ease;
		border: none;
		background: none;
		padding: 0;
	}

	/* Shutter button */
	.capture-btn {
		width: 60px;
		height: 60px;
	}

	.shutter-ring {
		width: 56px;
		height: 56px;
		border-radius: 50%;
		border: 3px solid rgba(255, 255, 255, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.15s ease;
	}

	.shutter-inner {
		width: 44px;
		height: 44px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.85);
		transition: all 0.15s ease;
	}

	.capture-btn:hover .shutter-ring {
		border-color: white;
		transform: scale(1.05);
	}

	.capture-btn:hover .shutter-inner {
		background: white;
	}

	.capture-btn:active .shutter-inner {
		background: rgba(255, 255, 255, 0.6);
		transform: scale(0.9);
	}

	/* Cancel button */
	.cancel-btn {
		flex-direction: column;
		gap: 2px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 9px;
		letter-spacing: 0.5px;
	}

	.cancel-btn .material-icons {
		font-size: 20px;
	}

	.cancel-btn:hover {
		color: rgba(255, 255, 255, 0.7);
	}

	/* Vignette */
	.vignette {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: radial-gradient(
			ellipse at center,
			transparent 50%,
			rgba(0, 0, 0, 0.4) 100%
		);
		pointer-events: none;
		z-index: 1;
	}

	/* Flash */
	.flash-overlay {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: white;
		z-index: 10;
		animation: flash-fade 0.15s ease-out forwards;
		pointer-events: none;
	}

	@keyframes flash-fade {
		0% { opacity: 0.9; }
		100% { opacity: 0; }
	}
</style>
