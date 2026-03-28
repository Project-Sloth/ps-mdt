import { Extension } from '@tiptap/core';
import { BlockquoteOptions } from '@tiptap/extension-blockquote';
import { BoldOptions } from '@tiptap/extension-bold';
import { BulletListOptions } from '@tiptap/extension-bullet-list';
import { CodeOptions } from '@tiptap/extension-code';
import { CodeBlockOptions } from '@tiptap/extension-code-block';
import { DropcursorOptions } from '@tiptap/extension-dropcursor';
import { HardBreakOptions } from '@tiptap/extension-hard-break';
import { HeadingOptions } from '@tiptap/extension-heading';
import { HistoryOptions } from '@tiptap/extension-history';
import { HorizontalRuleOptions } from '@tiptap/extension-horizontal-rule';
import { ItalicOptions } from '@tiptap/extension-italic';
import { ListItemOptions } from '@tiptap/extension-list-item';
import { OrderedListOptions } from '@tiptap/extension-ordered-list';
import { ParagraphOptions } from '@tiptap/extension-paragraph';
import { StrikeOptions } from '@tiptap/extension-strike';
export interface StarterKitOptions {
    /**
     * If set to false, the blockquote extension will not be registered
     * @example blockquote: false
     */
    blockquote: Partial<BlockquoteOptions> | false;
    /**
     * If set to false, the bold extension will not be registered
     * @example bold: false
     */
    bold: Partial<BoldOptions> | false;
    /**
     * If set to false, the bulletList extension will not be registered
     * @example bulletList: false
     */
    bulletList: Partial<BulletListOptions> | false;
    /**
     * If set to false, the code extension will not be registered
     * @example code: false
     */
    code: Partial<CodeOptions> | false;
    /**
     * If set to false, the codeBlock extension will not be registered
     * @example codeBlock: false
     */
    codeBlock: Partial<CodeBlockOptions> | false;
    /**
     * If set to false, the document extension will not be registered
     * @example document: false
     */
    document: false;
    /**
     * If set to false, the dropcursor extension will not be registered
     * @example dropcursor: false
     */
    dropcursor: Partial<DropcursorOptions> | false;
    /**
     * If set to false, the gapcursor extension will not be registered
     * @example gapcursor: false
     */
    gapcursor: false;
    /**
     * If set to false, the hardBreak extension will not be registered
     * @example hardBreak: false
     */
    hardBreak: Partial<HardBreakOptions> | false;
    /**
     * If set to false, the heading extension will not be registered
     * @example heading: false
     */
    heading: Partial<HeadingOptions> | false;
    /**
     * If set to false, the history extension will not be registered
     * @example history: false
     */
    history: Partial<HistoryOptions> | false;
    /**
     * If set to false, the horizontalRule extension will not be registered
     * @example horizontalRule: false
     */
    horizontalRule: Partial<HorizontalRuleOptions> | false;
    /**
     * If set to false, the italic extension will not be registered
     * @example italic: false
     */
    italic: Partial<ItalicOptions> | false;
    /**
     * If set to false, the listItem extension will not be registered
     * @example listItem: false
     */
    listItem: Partial<ListItemOptions> | false;
    /**
     * If set to false, the orderedList extension will not be registered
     * @example orderedList: false
     */
    orderedList: Partial<OrderedListOptions> | false;
    /**
     * If set to false, the paragraph extension will not be registered
     * @example paragraph: false
     */
    paragraph: Partial<ParagraphOptions> | false;
    /**
     * If set to false, the strike extension will not be registered
     * @example strike: false
     */
    strike: Partial<StrikeOptions> | false;
    /**
     * If set to false, the text extension will not be registered
     * @example text: false
     */
    text: false;
}
/**
 * The starter kit is a collection of essential editor extensions.
 *
 * It’s a good starting point for building your own editor.
 */
export declare const StarterKit: Extension<StarterKitOptions, any>;
//# sourceMappingURL=starter-kit.d.ts.map