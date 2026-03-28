import { Mark } from '@tiptap/core';
export interface StrikeOptions {
    /**
     * HTML attributes to add to the strike element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        strike: {
            /**
             * Set a strike mark
             * @example editor.commands.setStrike()
             */
            setStrike: () => ReturnType;
            /**
             * Toggle a strike mark
             * @example editor.commands.toggleStrike()
             */
            toggleStrike: () => ReturnType;
            /**
             * Unset a strike mark
             * @example editor.commands.unsetStrike()
             */
            unsetStrike: () => ReturnType;
        };
    }
}
/**
 * Matches a strike to a ~~strike~~ on input.
 */
export declare const inputRegex: RegExp;
/**
 * Matches a strike to a ~~strike~~ on paste.
 */
export declare const pasteRegex: RegExp;
/**
 * This extension allows you to create strike text.
 * @see https://www.tiptap.dev/api/marks/strike
 */
export declare const Strike: Mark<StrikeOptions, any>;
//# sourceMappingURL=strike.d.ts.map