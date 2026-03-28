import { Node, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create list items.
 * @see https://www.tiptap.dev/api/nodes/list-item
 */
const ListItem = Node.create({
    name: 'listItem',
    addOptions() {
        return {
            HTMLAttributes: {},
            bulletListTypeName: 'bulletList',
            orderedListTypeName: 'orderedList',
        };
    },
    content: 'paragraph block*',
    defining: true,
    parseHTML() {
        return [
            {
                tag: 'li',
            },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['li', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addKeyboardShortcuts() {
        return {
            Enter: () => this.editor.commands.splitListItem(this.name),
            Tab: () => this.editor.commands.sinkListItem(this.name),
            'Shift-Tab': () => this.editor.commands.liftListItem(this.name),
        };
    },
});

export { ListItem, ListItem as default };
//# sourceMappingURL=index.js.map
