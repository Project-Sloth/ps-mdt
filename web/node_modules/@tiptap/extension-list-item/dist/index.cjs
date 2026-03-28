'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');

/**
 * This extension allows you to create list items.
 * @see https://www.tiptap.dev/api/nodes/list-item
 */
const ListItem = core.Node.create({
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
        return ['li', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addKeyboardShortcuts() {
        return {
            Enter: () => this.editor.commands.splitListItem(this.name),
            Tab: () => this.editor.commands.sinkListItem(this.name),
            'Shift-Tab': () => this.editor.commands.liftListItem(this.name),
        };
    },
});

exports.ListItem = ListItem;
exports.default = ListItem;
//# sourceMappingURL=index.cjs.map
