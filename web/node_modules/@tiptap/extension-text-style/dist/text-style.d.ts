import { Mark } from '@tiptap/core';
export interface TextStyleOptions {
    /**
     * HTML attributes to add to the span element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
    /**
     * When enabled, merges the styles of nested spans into the child span during HTML parsing.
     * This prioritizes the style of the child span.
     * Used when parsing content created in other editors.
     * (Fix for ProseMirror's default behavior.)
     * @default false
     */
    mergeNestedSpanStyles: boolean;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        textStyle: {
            /**
             * Remove spans without inline style attributes.
             * @example editor.commands.removeEmptyTextStyle()
             */
            removeEmptyTextStyle: () => ReturnType;
        };
    }
}
/**
 * This extension allows you to create text styles. It is required by default
 * for the `textColor` and `backgroundColor` extensions.
 * @see https://www.tiptap.dev/api/marks/text-style
 */
export declare const TextStyle: Mark<TextStyleOptions, any>;
//# sourceMappingURL=text-style.d.ts.map