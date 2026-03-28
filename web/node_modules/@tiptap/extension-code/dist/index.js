import { Mark, mergeAttributes, markInputRule, markPasteRule } from '@tiptap/core';

/**
 * Regular expressions to match inline code blocks enclosed in backticks.
 *  It matches:
 *     - An opening backtick, followed by
 *     - Any text that doesn't include a backtick (captured for marking), followed by
 *     - A closing backtick.
 *  This ensures that any text between backticks is formatted as code,
 *  regardless of the surrounding characters (exception being another backtick).
 */
const inputRegex = /(^|[^`])`([^`]+)`(?!`)/;
/**
 * Matches inline code while pasting.
 */
const pasteRegex = /(^|[^`])`([^`]+)`(?!`)/g;
/**
 * This extension allows you to mark text as inline code.
 * @see https://tiptap.dev/api/marks/code
 */
const Code = Mark.create({
    name: 'code',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    excludes: '_',
    code: true,
    exitable: true,
    parseHTML() {
        return [
            { tag: 'code' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['code', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setCode: () => ({ commands }) => {
                return commands.setMark(this.name);
            },
            toggleCode: () => ({ commands }) => {
                return commands.toggleMark(this.name);
            },
            unsetCode: () => ({ commands }) => {
                return commands.unsetMark(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-e': () => this.editor.commands.toggleCode(),
        };
    },
    addInputRules() {
        return [
            markInputRule({
                find: inputRegex,
                type: this.type,
            }),
        ];
    },
    addPasteRules() {
        return [
            markPasteRule({
                find: pasteRegex,
                type: this.type,
            }),
        ];
    },
});

export { Code, Code as default, inputRegex, pasteRegex };
//# sourceMappingURL=index.js.map
