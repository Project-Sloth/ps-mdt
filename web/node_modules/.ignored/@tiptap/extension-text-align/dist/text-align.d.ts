import { Extension } from '@tiptap/core';
export interface TextAlignOptions {
    /**
     * The types where the text align attribute can be applied.
     * @default []
     * @example ['heading', 'paragraph']
     */
    types: string[];
    /**
     * The alignments which are allowed.
     * @default ['left', 'center', 'right', 'justify']
     * @example ['left', 'right']
     */
    alignments: string[];
    /**
     * The default alignment.
     * @default null
     * @example 'center'
     */
    defaultAlignment: string | null;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        textAlign: {
            /**
             * Set the text align attribute
             * @param alignment The alignment
             * @example editor.commands.setTextAlign('left')
             */
            setTextAlign: (alignment: string) => ReturnType;
            /**
             * Unset the text align attribute
             * @example editor.commands.unsetTextAlign()
             */
            unsetTextAlign: () => ReturnType;
            /**
             * Toggle the text align attribute
             * @param alignment The alignment
             * @example editor.commands.toggleTextAlign('right')
             */
            toggleTextAlign: (alignment: string) => ReturnType;
        };
    }
}
/**
 * This extension allows you to align text.
 * @see https://www.tiptap.dev/api/extensions/text-align
 */
export declare const TextAlign: Extension<TextAlignOptions, any>;
//# sourceMappingURL=text-align.d.ts.map