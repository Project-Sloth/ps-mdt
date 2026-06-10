<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { Editor } from "@tiptap/core";
	import StarterKit from "@tiptap/starter-kit";
	import Underline from "@tiptap/extension-underline";
	import TextAlign from "@tiptap/extension-text-align";
	import Highlight from "@tiptap/extension-highlight";
	import TextStyle from "@tiptap/extension-text-style";
	import Color from "@tiptap/extension-color";
	import Collaboration from "@tiptap/extension-collaboration";
	// TipTap v2. On v3 use: import CollaborationCaret from "@tiptap/extension-collaboration-caret";
	import CollaborationCursor from "@tiptap/extension-collaboration-cursor";
	import * as Y from "yjs";
	import type { Awareness } from "y-protocols/awareness";
	import ReportEditorToolbar from "./ReportEditorToolbar.svelte";

	interface Props {
		content: string;
		onUpdate: (content: string) => void;
		ydoc?: Y.Doc | null;
		collabActive?: boolean;
		awareness?: Awareness | null;
		userName?: string;
		userColor?: string;
	}

	let {
		content,
		onUpdate,
		ydoc = null,
		collabActive = false,
		awareness = null,
		userName = "",
		userColor = "#3B82F6",
	}: Props = $props();

	let editor = $state<Editor | null>(null);
	let editorElement = $state<HTMLElement>();

	onDestroy(() => {
		if (editor) {
			editor.destroy();
		}
	});

	// Initialize editor when editorElement becomes available
	$effect(() => {
		if (editorElement && !editor) {
			editor = initializeEditor();
		}
	});

	function initializeEditor(): Editor | null {
		if (!editorElement) return null;

		const extensions: any[] = [
			Underline,
			TextAlign.configure({
				types: ["heading", "paragraph"],
			}),
			Highlight.configure({
				multicolor: true,
			}),
			TextStyle,
			Color,
		];

		if (collabActive && ydoc) {
			extensions.unshift(
				StarterKit.configure({
					history: false,
				}),
			);
			extensions.push(
				Collaboration.configure({
					document: ydoc,
				}),
			);
			// Live cursors + name labels for other editors
			if (awareness) {
				extensions.push(
					CollaborationCursor.configure({
						// minimal provider: the extension only reads .awareness
						provider: { awareness },
						user: {
							name: userName || "Editor",
							color: userColor || "#3B82F6",
						},
					}),
				);
			}
		} else {
			extensions.unshift(StarterKit);
		}

		const editorInstance = new Editor({
			element: editorElement,
			extensions,
			content: collabActive && ydoc ? undefined : content,
			onUpdate: ({ editor }) => {
				onUpdate(editor.getHTML());
			},
			editorProps: {
				attributes: {
					class: "prose prose-invert max-w-none focus:outline-none min-h-[400px] p-4",
				},
			},
		});

		// In collab mode, if Y.js doc is empty and we have initial content, set it
		if (collabActive && ydoc && content) {
			const fragment = ydoc.getXmlFragment("default");
			if (fragment.length === 0) {
				// Y.js doc is empty, initialize from HTML content
				editorInstance.commands.setContent(content);
			}
		}

		return editorInstance;
	}

	// In solo mode (no collab), update content when prop changes
	$effect(() => {
		if (editor && !collabActive && content !== editor.getHTML()) {
			const { from, to } = editor.state.selection;
			editor.commands.setContent(content);
			try {
				const maxPos = editor.state.doc.content.size;
				editor.commands.setTextSelection({
					from: Math.min(from, maxPos),
					to: Math.min(to, maxPos),
				});
			} catch {}
		}
	});
</script>

<div class="editor-wrapper">
	{#if editor}
		<ReportEditorToolbar {editor} />
	{/if}

	<div class="editor-container">
		<div bind:this={editorElement} class="editor"></div>
	</div>
</div>

<style>
	.editor-wrapper {
		display: grid;
		grid-template-rows: auto 1fr;
		gap: 0;
		min-height: 0;
	}

	.editor-container {
		background: transparent;
		border: none;
		border-radius: 0;
		overflow: hidden;
		min-height: 0;
		display: flex;
		flex-direction: column;
	}

	.editor-container:focus-within {
		border-color: transparent;
	}

	:global(.editor) {
		flex: 1;
		color: rgba(255, 255, 255, 0.9);
		padding: 12px;
		overflow-y: auto;
		min-height: 400px;
		cursor: text;
		background: transparent;
		width: 100%;
		height: 100%;
	}

	:global(.editor .ProseMirror) {
		min-height: 400px;
		outline: none;
		padding: 0;
		width: 100%;
		height: 100%;
	}

	:global(.editor p) {
		margin: 0 0 1em 0;
	}

	:global(.editor ul, .editor ol) {
		padding-left: 1.5em;
		margin: 0 0 1em 0;
	}

	:global(.editor strong) {
		font-weight: 600;
	}

	:global(.editor em) {
		font-style: italic;
	}

	:global(.editor u) {
		text-decoration: underline;
	}

	:global(.editor h1) {
		font-size: 2em;
		font-weight: 700;
		margin: 0.5em 0;
		color: rgba(255, 255, 255, 0.9);
	}

	:global(.editor h2) {
		font-size: 1.5em;
		font-weight: 600;
		margin: 0.75em 0 0.5em 0;
		color: rgba(255, 255, 255, 0.9);
	}

	:global(.editor h3) {
		font-size: 1.25em;
		font-weight: 600;
		margin: 0.75em 0 0.5em 0;
		color: rgba(255, 255, 255, 0.9);
	}

	:global(.editor blockquote) {
		border-left: 3px solid rgba(255, 255, 255, 0.1);
		margin: 1em 0;
		padding-left: 1em;
		color: rgba(255, 255, 255, 0.35);
		font-style: italic;
		background: rgba(255, 255, 255, 0.02);
		border-radius: 0 6px 6px 0;
		padding: 0.8em;
	}

	:global(.editor mark) {
		background: rgba(255, 255, 0, 0.3);
		padding: 2px 4px;
		border-radius: 3px;
	}

	:global(.editor:focus) {
		outline: none;
	}

	:global(.editor::-webkit-scrollbar) {
		width: 4px;
	}

	:global(.editor::-webkit-scrollbar-track) {
		background: transparent;
	}

	:global(.editor::-webkit-scrollbar-thumb) {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	:global(.editor::-webkit-scrollbar-thumb:hover) {
		background: rgba(255, 255, 255, 0.1);
	}

	/* ---- Collaboration cursors (live carets + name labels) ---- */
	/* Covers both v2 (.collaboration-cursor__*) and v3 (.collaboration-caret__*) */

	/* Single clean caret line in the user's color.
	   The user color comes from the inline `border-color` the extension sets,
	   so we only touch width/style here and explicitly kill the right border. */
	:global(.collaboration-cursor__caret),
	:global(.collaboration-caret__caret) {
		position: relative;
		margin-left: -1px;
		margin-right: -1px;
		border: none;
		border-left-width: 2px;
		border-left-style: solid;
		border-radius: 2px;
		box-sizing: border-box;
		pointer-events: none;
		word-break: normal;
	}

	/* Name pill above the caret. background-color is set inline by the extension. */
	:global(.collaboration-cursor__label),
	:global(.collaboration-caret__label) {
		position: absolute;
		top: -1.55em;
		left: -2px;
		white-space: nowrap;
		color: #fff;
		font-size: 10px;
		font-weight: 600;
		line-height: 1;
		letter-spacing: 0.2px;
		padding: 3px 6px;
		border-radius: 5px 5px 5px 1px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.35);
		user-select: none;
		pointer-events: none;
		opacity: 0;
		animation: cursorLabelFade 2.6s ease forwards;
	}

	@keyframes cursorLabelFade {
		0% { opacity: 0; transform: translateY(3px); }
		12% { opacity: 1; transform: translateY(0); }
		65% { opacity: 1; transform: translateY(0); }
		100% { opacity: 0; transform: translateY(-2px); }
	}
</style>