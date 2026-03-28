<script lang="ts">
	interface Props {
		show: boolean;
		uploading?: boolean;
		onClose: () => void;
		onUpload: (file: File) => void;
	}

	let { show, uploading = false, onClose, onUpload }: Props = $props();

	let selectedFileName: string = $state("");

	function handleImageUpload(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (file) {
			selectedFileName = file.name;
			onUpload(file);
		}
	}

	function handleOverlayClick(event: MouseEvent) {
		if (uploading) return;
		if (event.target === event.currentTarget) {
			onClose();
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (uploading) return;
		if (event.key === "Escape") {
			onClose();
		}
	}
</script>

{#if show}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="popup-overlay"
		onclick={handleOverlayClick}
		onkeydown={handleKeydown}
		role="button"
		tabindex="0"
		aria-label="Close upload dialog"
	>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="popup" role="dialog" aria-modal="true" tabindex="-1">
			<div class="popup-header">
				<span class="popup-title">Upload Evidence Image</span>
				{#if !uploading}
					<button class="popup-close" onclick={onClose}>x</button>
				{/if}
			</div>
			<div class="popup-content">
				{#if uploading}
					<div class="uploading-state">
						<div class="spinner"></div>
						<span class="uploading-text">Uploading{selectedFileName ? ` ${selectedFileName}` : ""}...</span>
						<span class="uploading-hint">Please wait, compressing and uploading image</span>
					</div>
				{:else}
					<div class="upload-area">
						<input
							type="file"
							accept="image/*"
							onchange={handleImageUpload}
							class="file-input"
							id="image-upload"
						/>
						<label for="image-upload" class="upload-label">
							<span class="upload-icon">+</span>
							<span class="upload-text">Click to select image</span>
							<span class="upload-hint">Supports JPG, PNG, GIF (auto-compressed)</span>
						</label>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 2000;
	}

	.popup {
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px;
		width: 90%;
		max-width: 400px;
		max-height: 70vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 10px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.popup-title {
		font-size: 13px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.9);
	}

	.popup-close {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.5);
		font-size: 14px;
		cursor: pointer;
		padding: 0;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.popup-close:hover {
		color: rgba(255, 255, 255, 0.7);
	}

	.popup-content {
		padding: 14px;
	}

	.upload-area {
		border: 1px dashed rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		padding: 24px 14px;
		text-align: center;
	}

	.upload-area:hover {
		border-color: rgba(255, 255, 255, 0.15);
	}

	.file-input {
		display: none;
	}

	.upload-label {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 6px;
		cursor: pointer;
		color: rgba(255, 255, 255, 0.5);
	}

	.upload-icon {
		font-size: 24px;
		color: rgba(255, 255, 255, 0.5);
		font-weight: 300;
	}

	.upload-text {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.5);
	}

	.upload-hint {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.45);
	}

	.uploading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 10px;
		padding: 24px 14px;
		text-align: center;
	}

	.uploading-text {
		font-size: 13px;
		color: #fbbf24;
		font-weight: 500;
	}

	.uploading-hint {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.4);
	}

	.spinner {
		width: 28px;
		height: 28px;
		border: 2px solid rgba(255, 255, 255, 0.1);
		border-top-color: #fbbf24;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
