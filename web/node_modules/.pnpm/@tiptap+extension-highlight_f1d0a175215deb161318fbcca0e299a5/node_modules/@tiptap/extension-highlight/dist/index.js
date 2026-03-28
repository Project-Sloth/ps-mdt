import { Mark, mergeAttributes, markInputRule, markPasteRule } from '@tiptap/core';

/**
 * Matches a highlight to a ==highlight== on input.
 */
const inputRegex = /(?:^|\s)(==(?!\s+==)((?:[^=]+))==(?!\s+==))$/;
/**
 * Matches a highlight to a ==highlight== on paste.
 */
const pasteRegex = /(?:^|\s)(==(?!\s+==)((?:[^=]+))==(?!\s+==))/g;
/**
 * This extension allows you to highlight text.
 * @see https://www.tiptap.dev/api/marks/highlight
 */
const Highlight = Mark.create({
    name: 'highlight',
    addOptions() {
        return {
            multicolor: false,
            HTMLAttributes: {},
        };
    },
    addAttributes() {
        if (!this.options.multicolor) {
            return {};
        }
        return {
            color: {
                default: null,
                parseHTML: element => element.getAttribute('data-color') || element.style.backgroundColor,
                renderHTML: attributes => {
                    if (!attributes.color) {
                        return {};
                    }
                    return {
                        'data-color': attributes.color,
                        style: `background-color: ${attributes.color}; color: inherit`,
                    };
                },
            },
        };
    },
    parseHTML() {
        return [
            {
                tag: 'mark',
            },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['mark', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setHighlight: attributes => ({ commands }) => {
                return commands.setMark(this.name, attributes);
            },
            toggleHighlight: attributes => ({ commands }) => {
                return commands.toggleMark(this.name, attributes);
            },
            unsetHighlight: () => ({ commands }) => {
                return commands.unsetMark(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-Shift-h': () => this.editor.commands.toggleHighlight(),
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

export { Highlight, Highlight as default, inputRegex, pasteRegex };
//# sourceMappingURL=index.js.map
