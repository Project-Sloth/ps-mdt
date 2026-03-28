import '@tiptap/extension-text-style';
import { Extension } from '@tiptap/core';
export type ColorOptions = {
    /**
     * The types where the color can be applied
     * @default ['textStyle']
     * @example ['heading', 'paragraph']
    */
    types: string[];
};
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        color: {
            /**
             * Set the text color
             * @param color The color to set
             * @example editor.commands.setColor('red')
             */
            setColor: (color: string) => ReturnType;
            /**
             * Unset the text color
             * @example editor.commands.unsetColor()
             */
            unsetColor: () => ReturnType;
        };
    }
}
/**
 * This extension allows you to color your text.
 * @see https://tiptap.dev/api/extensions/color
 */
export declare const Color: Extension<ColorOptions, any>;
//# sourceMappingURL=color.d.ts.map