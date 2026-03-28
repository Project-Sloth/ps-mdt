'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');

/**
 * Matches an italic to a *italic* on input.
 */
const starInputRegex = /(?:^|\s)(\*(?!\s+\*)((?:[^*]+))\*(?!\s+\*))$/;
/**
 * Matches an italic to a *italic* on paste.
 */
const starPasteRegex = /(?:^|\s)(\*(?!\s+\*)((?:[^*]+))\*(?!\s+\*))/g;
/**
 * Matches an italic to a _italic_ on input.
 */
const underscoreInputRegex = /(?:^|\s)(_(?!\s+_)((?:[^_]+))_(?!\s+_))$/;
/**
 * Matches an italic to a _italic_ on paste.
 */
const underscorePasteRegex = /(?:^|\s)(_(?!\s+_)((?:[^_]+))_(?!\s+_))/g;
/**
 * This extension allows you to create italic text.
 * @see https://www.tiptap.dev/api/marks/italic
 */
const Italic = core.Mark.create({
    name: 'italic',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    parseHTML() {
        return [
            {
                tag: 'em',
            },
            {
                tag: 'i',
                getAttrs: node => node.style.fontStyle !== 'normal' && null,
            },
            {
                style: 'font-style=normal',
                clearMark: mark => mark.type.name === this.name,
            },
            {
                style: 'font-style=italic',
            },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['em', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setItalic: () => ({ commands }) => {
                return commands.setMark(this.name);
            },
            toggleItalic: () => ({ commands }) => {
                return commands.toggleMark(this.name);
            },
            unsetItalic: () => ({ commands }) => {
                return commands.unsetMark(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-i': () => this.editor.commands.toggleItalic(),
            'Mod-I': () => this.editor.commands.toggleItalic(),
        };
    },
    addInputRules() {
        return [
            core.markInputRule({
                find: starInputRegex,
                type: this.type,
            }),
            core.markInputRule({
                find: underscoreInputRegex,
                type: this.type,
            }),
        ];
    },
    addPasteRules() {
        return [
            core.markPasteRule({
                find: starPasteRegex,
                type: this.type,
            }),
            core.markPasteRule({
                find: underscorePasteRegex,
                type: this.type,
            }),
        ];
    },
});

exports.Italic = Italic;
exports.default = Italic;
exports.starInputRegex = starInputRegex;
exports.starPasteRegex = starPasteRegex;
exports.underscoreInputRegex = underscoreInputRegex;
exports.underscorePasteRegex = underscorePasteRegex;
//# sourceMappingURL=index.cjs.map
