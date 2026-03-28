import { Mark } from '@tiptap/core';
export interface HighlightOptions {
    /**
     * Allow multiple highlight colors
     * @default false
     * @example true
     */
    multicolor: boolean;
    /**
     * HTML attributes to add to the highlight element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        highlight: {
            /**
             * Set a highlight mark
             * @param attributes The highlight attributes
             * @example editor.commands.setHighlight({ color: 'red' })
             */
            setHighlight: (attributes?: {
                color: string;
            }) => ReturnType;
            /**
             * Toggle a highlight mark
             * @param attributes The highlight attributes
             * @example editor.commands.toggleHighlight({ color: 'red' })
             */
            toggleHighlight: (attributes?: {
                color: string;
            }) => ReturnType;
            /**
             * Unset a highlight mark
             * @example editor.commands.unsetHighlight()
             */
            unsetHighlight: () => ReturnType;
        };
    }
}
/**
 * Matches a highlight to a ==highlight== on input.
 */
export declare const inputRegex: RegExp;
/**
 * Matches a highlight to a ==highlight== on paste.
 */
export declare const pasteRegex: RegExp;
/**
 * This extension allows you to highlight text.
 * @see https://www.tiptap.dev/api/marks/highlight
 */
export declare const Highlight: Mark<HighlightOptions, any>;
//# sourceMappingURL=highlight.d.ts.map