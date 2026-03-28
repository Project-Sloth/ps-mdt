import { Mark } from '@tiptap/core';
export interface UnderlineOptions {
    /**
     * HTML attributes to add to the underline element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        underline: {
            /**
             * Set an underline mark
             * @example editor.commands.setUnderline()
             */
            setUnderline: () => ReturnType;
            /**
             * Toggle an underline mark
             * @example editor.commands.toggleUnderline()
             */
            toggleUnderline: () => ReturnType;
            /**
             * Unset an underline mark
             * @example editor.commands.unsetUnderline()
             */
            unsetUnderline: () => ReturnType;
        };
    }
}
/**
 * This extension allows you to create underline text.
 * @see https://www.tiptap.dev/api/marks/underline
 */
export declare const Underline: Mark<UnderlineOptions, any>;
//# sourceMappingURL=underline.d.ts.map