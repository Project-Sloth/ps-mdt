<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface Bulletin {
		id?: number;
		content: string;
	}

	let bulletins: Bulletin[] = $state([]);
	let newTitle: string = $state("");
	let newContent: string = $state("");
	let isLoading = $state(false);
	let isSubmitting = $state(false);
	let statusMessage: { text: string; type: "success" | "error" } | null = $state(null);

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	async function loadBulletins() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<Bulletin[]>(
				NUI_EVENTS.DASHBOARD.GET_BULLETINS,
				{},
				[],
			);
			bulletins = Array.isArray(response) ? response : [];
		} catch (error) {
			console.error("Failed to load bulletins:", error);
			bulletins = [];
		} finally {
			isLoading = false;
		}
	}

	function buildContent(): string {
		const title = newTitle.trim().toUpperCase();
		const body = newContent.trim();
		if (title && body) return `${title}: ${body}`;
		if (title) return title;
		return body;
	}

	function parseBulletin(content: string): { title: string; body: string } {
		const colonIdx = content.indexOf(":");
		if (colonIdx > 0 && colonIdx < 40) {
			return {
				title: content.slice(0, colonIdx).trim(),
				body: content.slice(colonIdx + 1).trim(),
			};
		}
		return { title: "", body: content };
	}

	async function handleSubmit() {
		if (!newContent.trim() && !newTitle.trim()) return;
		const fullContent = buildContent();
		if (!fullContent) return;
		if (isEnvBrowser()) {
			bulletins = [{ id: Date.now(), content: fullContent }, ...bulletins];
			newTitle = "";
			newContent = "";
			return;
		}
		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string; id?: number }>(
				NUI_EVENTS.DASHBOARD.CREATE_BULLETIN,
				{ content: fullContent },
				{ success: false },
			);
			if (result && result.success) {
				showStatus("Bulletin posted");
				newTitle = "";
				newContent = "";
				await loadBulletins();
			} else {
				showStatus(result?.message || "Failed to post bulletin", "error");
			}
		} catch (error) {
			console.error("Failed to create bulletin:", error);
			showStatus("Failed to post bulletin", "error");
		} finally {
			isSubmitting = false;
		}
	}

	async function deleteBulletin(id: number | undefined) {
		if (!id) return;
		if (isEnvBrowser()) {
			bulletins = bulletins.filter((b) => b.id !== id);
			return;
		}
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.DASHBOARD.DELETE_BULLETIN,
				{ id },
				{ success: false },
			);
			if (result && result.success) {
				showStatus("Bulletin deleted");
				await loadBulletins();
			} else {
				showStatus(result?.message || "Failed to delete bulletin", "error");
			}
		} catch (error) {
			console.error("Failed to delete bulletin:", error);
			showStatus("Failed to delete bulletin", "error");
		}
	}

	onMount(() => {
		if (isEnvBrowser()) {
			bulletins = [
				{ id: 1, content: "TRAINING: FTO certification renewal is due by end of month. Contact Lt. Park to schedule your assessment." },
				{ id: 2, content: "BOLO REMINDER: Black Kuruma from the Pacific Standard robbery is still outstanding. If spotted, do NOT engage alone." },
				{ id: 3, content: "Radio channel 3 is now reserved for tactical operations. Please update your radios before next shift." },
			];
			return;
		}
		loadBulletins();
	});
</script>

<div class="bulletins-panel">
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">
			{statusMessage.text}
		</div>
	{/if}

	<div class="new-bulletin">
		<div class="bulletin-fields">
			<input
				class="bulletin-title-input"
				type="text"
				placeholder="Title (e.g. TRAINING, BOLO REMINDER)"
				bind:value={newTitle}
			/>
			<textarea
				class="bulletin-input"
				placeholder="Write a bulletin..."
				rows="2"
				bind:value={newContent}
			></textarea>
		</div>
		<button
			class="btn-post"
			onclick={handleSubmit}
			disabled={(!newContent.trim() && !newTitle.trim()) || isSubmitting}
		>
			{isSubmitting ? "Posting..." : "Post"}
		</button>
	</div>

	{#if isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading bulletins...</p>
		</div>
	{:else}
		<div class="bulletins-list">
			{#each bulletins as bulletin (bulletin.id || bulletin.content)}
				{@const parsed = parseBulletin(bulletin.content)}
				<div class="bulletin-row">
					<div class="bulletin-body">
						{#if parsed.title && parsed.body}
							<span class="bulletin-title">{parsed.title}</span>
							<p class="bulletin-text">{parsed.body}</p>
						{:else}
							<p class="bulletin-text">{bulletin.content}</p>
						{/if}
					</div>
					{#if bulletin.id}
						<button
							class="delete-btn"
							onclick={() => deleteBulletin(bulletin.id)}
							aria-label="Delete bulletin"
						>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					{/if}
				</div>
			{:else}
				<div class="empty-state">No bulletins posted.</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.bulletins-panel {
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

	.new-bulletin {
		display: flex;
		gap: 10px;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
		align-items: flex-end;
	}

	.bulletin-fields {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.bulletin-title-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.bulletin-title-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.12);
	}

	.bulletin-title-input::placeholder {
		color: rgba(255, 255, 255, 0.35);
		font-weight: 400;
		text-transform: none;
		letter-spacing: 0;
	}

	.bulletin-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 6px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		resize: vertical;
		min-height: 32px;
	}

	.bulletin-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.12);
	}

	.bulletin-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.btn-post {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 12px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
	}

	.btn-post:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-post:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.bulletins-list {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.bulletins-list::-webkit-scrollbar {
		width: 4px;
	}

	.bulletins-list::-webkit-scrollbar-track {
		background: transparent;
	}

	.bulletins-list::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.bulletin-row {
		display: flex;
		align-items: flex-start;
		gap: 10px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}

	.bulletin-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.bulletin-row:last-child {
		border-bottom: none;
	}

	.bulletin-body {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 0;
	}

	.bulletin-title {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.35);
	}

	.bulletin-text {
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		line-height: 1.5;
		margin: 0;
	}

	.delete-btn {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 3px;
		border-radius: 3px;
		display: flex;
		align-items: center;
		flex-shrink: 0;
		transition: all 0.1s;
		opacity: 0;
	}

	.bulletin-row:hover .delete-btn {
		opacity: 1;
	}

	.delete-btn:hover {
		color: rgba(252, 165, 165, 0.8);
		background: rgba(239, 68, 68, 0.08);
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
