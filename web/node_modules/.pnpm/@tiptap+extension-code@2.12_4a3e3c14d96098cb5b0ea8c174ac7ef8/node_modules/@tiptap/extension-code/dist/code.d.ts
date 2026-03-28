import { Mark } from '@tiptap/core';
export interface CodeOptions {
    /**
     * The HTML attributes applied to the code element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        code: {
            /**
             * Set a code mark
             */
            setCode: () => ReturnType;
            /**
             * Toggle inline code
             */
            toggleCode: () => ReturnType;
            /**
             * Unset a code mark
             */
            unsetCode: () => ReturnType;
        };
    }
}
/**
 * Regular expressions to match inline code blocks enclosed in backticks.
 *  It matches:
 *     - An opening backtick, followed by
 *     - Any text that doesn't include a backtick (captured for marking), followed by
 *     - A closing backtick.
 *  This ensures that any text between backticks is formatted as code,
 *  regardless of the surrounding characters (exception being another backtick).
 */
export declare const inputRegex: RegExp;
/**
 * Matches inline code while pasting.
 */
export declare const pasteRegex: RegExp;
/**
 * This extension allows you to mark text as inline code.
 * @see https://tiptap.dev/api/marks/code
 */
export declare const Code: Mark<CodeOptions, any>;
//# sourceMappingURL=code.d.ts.map