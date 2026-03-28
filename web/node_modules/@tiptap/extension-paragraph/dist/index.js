import { Node, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create paragraphs.
 * @see https://www.tiptap.dev/api/nodes/paragraph
 */
const Paragraph = Node.create({
    name: 'paragraph',
    priority: 1000,
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    group: 'block',
    content: 'inline*',
    parseHTML() {
        return [
            { tag: 'p' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['p', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setParagraph: () => ({ commands }) => {
                return commands.setNode(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-Alt-0': () => this.editor.commands.setParagraph(),
        };
    },
});

export { Paragraph, Paragraph as default };
//# sourceMappingURL=index.js.map
