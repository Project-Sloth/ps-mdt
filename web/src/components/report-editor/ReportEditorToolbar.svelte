<script lang="ts">
	import type { Editor } from "@tiptap/core";

	interface Props {
		editor: Editor;
	}

	let { editor }: Props = $props();
</script>

<div class="editor-toolbar">
	<div class="toolbar-group">
		<button
			aria-label="Bold"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleBold().run()}
			class:active={editor.isActive("bold")}
			title="Bold (Ctrl+B)"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z"
				/>
			</svg>
		</button>

		<button
			aria-label="Italic"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleItalic().run()}
			class:active={editor.isActive("italic")}
			title="Italic (Ctrl+I)"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path d="M10 4v3h2.21l-3.42 8H6v3h8v-3h-2.21l3.42-8H18V4z" />
			</svg>
		</button>

		<button
			aria-label="Underline"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleUnderline().run()}
			class:active={editor.isActive("underline")}
			title="Underline (Ctrl+U)"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M12 17c3.31 0 6-2.69 6-6V3h-2.5v8c0 1.93-1.57 3.5-3.5 3.5S8.5 12.93 8.5 11V3H6v8c0 3.31 2.69 6 6 6zm-7 2v2h14v-2H5z"
				/>
			</svg>
		</button>

		<button
			aria-label="Highlight"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleHighlight().run()}
			class:active={editor.isActive("highlight")}
			title="Highlight"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M6 14l3 3-3 3v2h18v-2l-3-3 3-3V9H6v5zm0-5h18V7l-3-3 3-3V1H6v4l3 3-3 3v2z"
				/>
			</svg>
		</button>
	</div>

	<div class="toolbar-group">
		<button
			aria-label="Align Left"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().setTextAlign("left").run()}
			class:active={editor.isActive({ textAlign: "left" })}
			title="Align Left"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M15 15H3v2h12v-2zm0-8H3v2h12V7zM3 13h18v-2H3v2zm0 8h18v-2H3v2zM3 3v2h18V3H3z"
				/>
			</svg>
		</button>

		<button
			aria-label="Align Center"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().setTextAlign("center").run()}
			class:active={editor.isActive({ textAlign: "center" })}
			title="Align Center"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M7 15v2h10v-2H7zm-4 6h18v-2H3v2zm0-8h18v-2H3v2zm4-6v2h10V7H7zM3 3v2h18V3H3z"
				/>
			</svg>
		</button>

		<button
			aria-label="Align Right"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().setTextAlign("right").run()}
			class:active={editor.isActive({ textAlign: "right" })}
			title="Align Right"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M3 21h18v-2H3v2zm6-4h12v-2H9v2zm-6-4h18v-2H3v2zm6-4h12V7H9v2zM3 3v2h18V3H3z"
				/>
			</svg>
		</button>
	</div>

	<div class="toolbar-group">
		<button
			aria-label="Bullet List"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleBulletList().run()}
			class:active={editor.isActive("bulletList")}
			title="Bullet List"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M4 10.5c-.83 0-1.5.67-1.5 1.5s.67 1.5 1.5 1.5 1.5-.67 1.5-1.5-.67-1.5-1.5-1.5zm0-6c-.83 0-1.5.67-1.5 1.5S3.17 7.5 4 7.5 5.5 6.83 5.5 6 4.83 4.5 4 4.5zm0 12c-.83 0-1.5.67-1.5 1.5s.67 1.5 1.5 1.5 1.5-.67 1.5-1.5-.67-1.5-1.5-1.5zM7 19h14v-2H7v2zm0-6h14v-2H7v2zm0-8v2h14V5H7z"
				/>
			</svg>
		</button>

		<button
			aria-label="Numbered List"
			class="toolbar-btn"
			onclick={() => editor.chain().focus().toggleOrderedList().run()}
			class:active={editor.isActive("orderedList")}
			title="Numbered List"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M2 17h2v.5H3v1h1v.5H2v1h3v-4H2v1zm1-9h1V4H2v1h1v3zm-1 3h1.8L2 13.1v.9h3v-1H3.2L5 10.9V10H2v1zm5-6v2h14V5H7zm0 14h14v-2H7v2zm0-6h14v-2H7v2z"
				/>
			</svg>
		</button>
	</div>

	<div class="toolbar-group">
		<button
			aria-label="Heading 1"
			class="toolbar-btn"
			onclick={() =>
				editor.chain().focus().toggleHeading({ level: 1 }).run()}
			class:active={editor.isActive("heading", { level: 1 })}
			title="Heading 1"
		>
			H1
		</button>

		<button
			aria-label="Heading 2"
			class="toolbar-btn"
			onclick={() =>
				editor.chain().focus().toggleHeading({ level: 2 }).run()}
			class:active={editor.isActive("heading", { level: 2 })}
			title="Heading 2"
		>
			H2
		</button>

		<button
			aria-label="Heading 3"
			class="toolbar-btn"
			onclick={() =>
				editor.chain().focus().toggleHeading({ level: 3 }).run()}
			class:active={editor.isActive("heading", { level: 3 })}
			title="Heading 3"
		>
			H3
		</button>
	</div>
</div>

<style>
	.editor-toolbar {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 5px 16px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		flex-wrap: wrap;
	}

	.toolbar-group {
		display: flex;
		align-items: center;
		gap: 2px;
		padding: 0 6px;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.toolbar-group:last-child {
		border-right: none;
	}

	.toolbar-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 26px;
		height: 26px;
		background: transparent;
		border: 1px solid transparent;
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		font-size: 11px;
		font-weight: 600;
	}

	.toolbar-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.toolbar-btn.active {
		background: rgba(255, 255, 255, 0.1);
		color: rgba(255, 255, 255, 0.9);
	}

	.toolbar-btn svg {
		width: 14px;
		height: 14px;
	}

	@media (max-width: 768px) {
		.editor-toolbar {
			gap: 4px;
			padding: 4px 8px;
		}

		.toolbar-group {
			gap: 1px;
			padding: 0 3px;
		}

		.toolbar-btn {
			width: 24px;
			height: 24px;
		}
	}
</style>
