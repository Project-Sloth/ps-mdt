'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');
var extensionBlockquote = require('@tiptap/extension-blockquote');
var extensionBold = require('@tiptap/extension-bold');
var extensionBulletList = require('@tiptap/extension-bullet-list');
var extensionCode = require('@tiptap/extension-code');
var extensionCodeBlock = require('@tiptap/extension-code-block');
var extensionDocument = require('@tiptap/extension-document');
var extensionDropcursor = require('@tiptap/extension-dropcursor');
var extensionGapcursor = require('@tiptap/extension-gapcursor');
var extensionHardBreak = require('@tiptap/extension-hard-break');
var extensionHeading = require('@tiptap/extension-heading');
var extensionHistory = require('@tiptap/extension-history');
var extensionHorizontalRule = require('@tiptap/extension-horizontal-rule');
var extensionItalic = require('@tiptap/extension-italic');
var extensionListItem = require('@tiptap/extension-list-item');
var extensionOrderedList = require('@tiptap/extension-ordered-list');
var extensionParagraph = require('@tiptap/extension-paragraph');
var extensionStrike = require('@tiptap/extension-strike');
var extensionText = require('@tiptap/extension-text');

/**
 * The starter kit is a collection of essential editor extensions.
 *
 * It’s a good starting point for building your own editor.
 */
const StarterKit = core.Extension.create({
    name: 'starterKit',
    addExtensions() {
        const extensions = [];
        if (this.options.bold !== false) {
            extensions.push(extensionBold.Bold.configure(this.options.bold));
        }
        if (this.options.blockquote !== false) {
            extensions.push(extensionBlockquote.Blockquote.configure(this.options.blockquote));
        }
        if (this.options.bulletList !== false) {
            extensions.push(extensionBulletList.BulletList.configure(this.options.bulletList));
        }
        if (this.options.code !== false) {
            extensions.push(extensionCode.Code.configure(this.options.code));
        }
        if (this.options.codeBlock !== false) {
            extensions.push(extensionCodeBlock.CodeBlock.configure(this.options.codeBlock));
        }
        if (this.options.document !== false) {
            extensions.push(extensionDocument.Document.configure(this.options.document));
        }
        if (this.options.dropcursor !== false) {
            extensions.push(extensionDropcursor.Dropcursor.configure(this.options.dropcursor));
        }
        if (this.options.gapcursor !== false) {
            extensions.push(extensionGapcursor.Gapcursor.configure(this.options.gapcursor));
        }
        if (this.options.hardBreak !== false) {
            extensions.push(extensionHardBreak.HardBreak.configure(this.options.hardBreak));
        }
        if (this.options.heading !== false) {
            extensions.push(extensionHeading.Heading.configure(this.options.heading));
        }
        if (this.options.history !== false) {
            extensions.push(extensionHistory.History.configure(this.options.history));
        }
        if (this.options.horizontalRule !== false) {
            extensions.push(extensionHorizontalRule.HorizontalRule.configure(this.options.horizontalRule));
        }
        if (this.options.italic !== false) {
            extensions.push(extensionItalic.Italic.configure(this.options.italic));
        }
        if (this.options.listItem !== false) {
            extensions.push(extensionListItem.ListItem.configure(this.options.listItem));
        }
        if (this.options.orderedList !== false) {
            extensions.push(extensionOrderedList.OrderedList.configure(this.options.orderedList));
        }
        if (this.options.paragraph !== false) {
            extensions.push(extensionParagraph.Paragraph.configure(this.options.paragraph));
        }
        if (this.options.strike !== false) {
            extensions.push(extensionStrike.Strike.configure(this.options.strike));
        }
        if (this.options.text !== false) {
            extensions.push(extensionText.Text.configure(this.options.text));
        }
        return extensions;
    },
});

exports.StarterKit = StarterKit;
exports.default = StarterKit;
//# sourceMappingURL=index.cjs.map
