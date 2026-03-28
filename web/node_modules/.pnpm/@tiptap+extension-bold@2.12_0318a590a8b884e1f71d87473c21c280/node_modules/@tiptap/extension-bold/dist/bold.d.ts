import { Mark } from '@tiptap/core';
export interface BoldOptions {
    /**
     * HTML attributes to add to the bold element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        bold: {
            /**
             * Set a bold mark
             */
            setBold: () => ReturnType;
            /**
             * Toggle a bold mark
             */
            toggleBold: () => ReturnType;
            /**
             * Unset a bold mark
             */
            unsetBold: () => ReturnType;
        };
    }
}
/**
 * Matches bold text via `**` as input.
 */
export declare const starInputRegex: RegExp;
/**
 * Matches bold text via `**` while pasting.
 */
export declare const starPasteRegex: RegExp;
/**
 * Matches bold text via `__` as input.
 */
export declare const underscoreInputRegex: RegExp;
/**
 * Matches bold text via `__` while pasting.
 */
export declare const underscorePasteRegex: RegExp;
/**
 * This extension allows you to mark text as bold.
 * @see https://tiptap.dev/api/marks/bold
 */
export declare const Bold: Mark<BoldOptions, any>;
//# sourceMappingURL=bold.d.ts.map