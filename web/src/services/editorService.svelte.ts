import { Editor } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import TextAlign from "@tiptap/extension-text-align";
import Highlight from "@tiptap/extension-highlight";
import TextStyle from "@tiptap/extension-text-style";
import Color from "@tiptap/extension-color";

export interface EditorServiceState {
	editor: Editor | null;
	isInitialized: boolean;
	content: string;
}

export function createEditorService() {
	let state = $state<EditorServiceState>({
		editor: null,
		isInitialized: false,
		content: "",
	});

	/**
	 * Initialize the TipTap editor with the given element and content
	 */
	function initializeEditor(
		element: HTMLElement,
		initialContent: string = "",
		onUpdate?: (content: string) => void,
	): Editor | null {
		if (!element) {
			console.warn("Editor element not available yet");
			return null;
		}

		if (state.editor) {
			state.editor.destroy();
		}

		const editor = new Editor({
			element,
			extensions: [
				StarterKit,
				Underline,
				TextAlign.configure({
					types: ["heading", "paragraph"],
				}),
				Highlight.configure({
					multicolor: true,
				}),
				TextStyle,
				Color,
			],
			content: initialContent,
			onUpdate: ({ editor }) => {
				const content = editor.getHTML();
				state.content = content;
				if (onUpdate) {
					onUpdate(content);
				}
			},
			editorProps: {
				attributes: {
					class: "prose prose-invert max-w-none focus:outline-none min-h-[400px] p-4",
				},
			},
		});

		state.editor = editor;
		state.isInitialized = true;
		state.content = initialContent;

		return editor;
	}

	/**
	 * Destroy the editor instance
	 */
	function destroyEditor(): void {
		if (state.editor) {
			state.editor.destroy();
			state.editor = null;
			state.isInitialized = false;
		}
	}

	/**
	 * Update editor content programmatically
	 */
	function updateContent(content: string): void {
		if (state.editor) {
			state.editor.commands.setContent(content);
			state.content = content;
		}
	}

	/**
	 * Get current editor content
	 */
	function getContent(): string {
		return state.editor?.getHTML() || state.content;
	}

	/**
	 * Check if editor is active for a specific mark/node
	 */
	function isActive(name: string, attributes?: Record<string, any>): boolean {
		return state.editor?.isActive(name, attributes) ?? false;
	}

	/**
	 * Execute editor commands
	 */
	function executeCommand(command: (editor: Editor) => void): void {
		if (state.editor) {
			command(state.editor);
		}
	}

	return {
		get state() {
			return state;
		},
		initializeEditor,
		destroyEditor,
		updateContent,
		getContent,
		isActive,
		executeCommand,
	};
}

export type EditorService = ReturnType<typeof createEditorService>;
