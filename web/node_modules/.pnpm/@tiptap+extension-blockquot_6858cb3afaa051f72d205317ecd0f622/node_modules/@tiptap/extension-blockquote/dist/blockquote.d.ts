import { Node } from '@tiptap/core';
export interface BlockquoteOptions {
    /**
     * HTML attributes to add to the blockquote element
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        blockQuote: {
            /**
             * Set a blockquote node
             */
            setBlockquote: () => ReturnType;
            /**
             * Toggle a blockquote node
             */
            toggleBlockquote: () => ReturnType;
            /**
             * Unset a blockquote node
             */
            unsetBlockquote: () => ReturnType;
        };
    }
}
/**
 * Matches a blockquote to a `>` as input.
 */
export declare const inputRegex: RegExp;
/**
 * This extension allows you to create blockquotes.
 * @see https://tiptap.dev/api/nodes/blockquote
 */
export declare const Blockquote: Node<BlockquoteOptions, any>;
//# sourceMappingURL=blockquote.d.ts.map