import { Node, mergeAttributes, wrappingInputRule } from '@tiptap/core';

/**
 * Matches a blockquote to a `>` as input.
 */
const inputRegex = /^\s*>\s$/;
/**
 * This extension allows you to create blockquotes.
 * @see https://tiptap.dev/api/nodes/blockquote
 */
const Blockquote = Node.create({
    name: 'blockquote',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    content: 'block+',
    group: 'block',
    defining: true,
    parseHTML() {
        return [
            { tag: 'blockquote' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['blockquote', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setBlockquote: () => ({ commands }) => {
                return commands.wrapIn(this.name);
            },
            toggleBlockquote: () => ({ commands }) => {
                return commands.toggleWrap(this.name);
            },
            unsetBlockquote: () => ({ commands }) => {
                return commands.lift(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-Shift-b': () => this.editor.commands.toggleBlockquote(),
        };
    },
    addInputRules() {
        return [
            wrappingInputRule({
                find: inputRegex,
                type: this.type,
            }),
        ];
    },
});

export { Blockquote, Blockquote as default, inputRegex };
//# sourceMappingURL=index.js.map
