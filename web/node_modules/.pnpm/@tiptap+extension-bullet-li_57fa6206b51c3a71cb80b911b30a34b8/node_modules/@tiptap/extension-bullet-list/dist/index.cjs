'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');

const ListItemName = 'listItem';
const TextStyleName = 'textStyle';
/**
 * Matches a bullet list to a dash or asterisk.
 */
const inputRegex = /^\s*([-+*])\s$/;
/**
 * This extension allows you to create bullet lists.
 * This requires the ListItem extension
 * @see https://tiptap.dev/api/nodes/bullet-list
 * @see https://tiptap.dev/api/nodes/list-item.
 */
const BulletList = core.Node.create({
    name: 'bulletList',
    addOptions() {
        return {
            itemTypeName: 'listItem',
            HTMLAttributes: {},
            keepMarks: false,
            keepAttributes: false,
        };
    },
    group: 'block list',
    content() {
        return `${this.options.itemTypeName}+`;
    },
    parseHTML() {
        return [
            { tag: 'ul' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['ul', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            toggleBulletList: () => ({ commands, chain }) => {
                if (this.options.keepAttributes) {
                    return chain().toggleList(this.name, this.options.itemTypeName, this.options.keepMarks).updateAttributes(ListItemName, this.editor.getAttributes(TextStyleName)).run();
                }
                return commands.toggleList(this.name, this.options.itemTypeName, this.options.keepMarks);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-Shift-8': () => this.editor.commands.toggleBulletList(),
        };
    },
    addInputRules() {
        let inputRule = core.wrappingInputRule({
            find: inputRegex,
            type: this.type,
        });
        if (this.options.keepMarks || this.options.keepAttributes) {
            inputRule = core.wrappingInputRule({
                find: inputRegex,
                type: this.type,
                keepMarks: this.options.keepMarks,
                keepAttributes: this.options.keepAttributes,
                getAttributes: () => { return this.editor.getAttributes(TextStyleName); },
                editor: this.editor,
            });
        }
        return [
            inputRule,
        ];
    },
});

exports.BulletList = BulletList;
exports.default = BulletList;
exports.inputRegex = inputRegex;
//# sourceMappingURL=index.cjs.map
