import { Extension } from '@tiptap/core';
import { Blockquote } from '@tiptap/extension-blockquote';
import { Bold } from '@tiptap/extension-bold';
import { BulletList } from '@tiptap/extension-bullet-list';
import { Code } from '@tiptap/extension-code';
import { CodeBlock } from '@tiptap/extension-code-block';
import { Document } from '@tiptap/extension-document';
import { Dropcursor } from '@tiptap/extension-dropcursor';
import { Gapcursor } from '@tiptap/extension-gapcursor';
import { HardBreak } from '@tiptap/extension-hard-break';
import { Heading } from '@tiptap/extension-heading';
import { History } from '@tiptap/extension-history';
import { HorizontalRule } from '@tiptap/extension-horizontal-rule';
import { Italic } from '@tiptap/extension-italic';
import { ListItem } from '@tiptap/extension-list-item';
import { OrderedList } from '@tiptap/extension-ordered-list';
import { Paragraph } from '@tiptap/extension-paragraph';
import { Strike } from '@tiptap/extension-strike';
import { Text } from '@tiptap/extension-text';

/**
 * The starter kit is a collection of essential editor extensions.
 *
 * It’s a good starting point for building your own editor.
 */
const StarterKit = Extension.create({
    name: 'starterKit',
    addExtensions() {
        const extensions = [];
        if (this.options.bold !== false) {
            extensions.push(Bold.configure(this.options.bold));
        }
        if (this.options.blockquote !== false) {
            extensions.push(Blockquote.configure(this.options.blockquote));
        }
        if (this.options.bulletList !== false) {
            extensions.push(BulletList.configure(this.options.bulletList));
        }
        if (this.options.code !== false) {
            extensions.push(Code.configure(this.options.code));
        }
        if (this.options.codeBlock !== false) {
            extensions.push(CodeBlock.configure(this.options.codeBlock));
        }
        if (this.options.document !== false) {
            extensions.push(Document.configure(this.options.document));
        }
        if (this.options.dropcursor !== false) {
            extensions.push(Dropcursor.configure(this.options.dropcursor));
        }
        if (this.options.gapcursor !== false) {
            extensions.push(Gapcursor.configure(this.options.gapcursor));
        }
        if (this.options.hardBreak !== false) {
            extensions.push(HardBreak.configure(this.options.hardBreak));
        }
        if (this.options.heading !== false) {
            extensions.push(Heading.configure(this.options.heading));
        }
        if (this.options.history !== false) {
            extensions.push(History.configure(this.options.history));
        }
        if (this.options.horizontalRule !== false) {
            extensions.push(HorizontalRule.configure(this.options.horizontalRule));
        }
        if (this.options.italic !== false) {
            extensions.push(Italic.configure(this.options.italic));
        }
        if (this.options.listItem !== false) {
            extensions.push(ListItem.configure(this.options.listItem));
        }
        if (this.options.orderedList !== false) {
            extensions.push(OrderedList.configure(this.options.orderedList));
        }
        if (this.options.paragraph !== false) {
            extensions.push(Paragraph.configure(this.options.paragraph));
        }
        if (this.options.strike !== false) {
            extensions.push(Strike.configure(this.options.strike));
        }
        if (this.options.text !== false) {
            extensions.push(Text.configure(this.options.text));
        }
        return extensions;
    },
});

export { StarterKit, StarterKit as default };
//# sourceMappingURL=index.js.map
