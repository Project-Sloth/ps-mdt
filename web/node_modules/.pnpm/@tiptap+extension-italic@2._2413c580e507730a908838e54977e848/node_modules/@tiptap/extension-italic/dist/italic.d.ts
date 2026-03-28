import { Mark } from '@tiptap/core';
export interface ItalicOptions {
    /**
     * HTML attributes to add to the italic element.
     * @default {}
     * @example { class: 'foo' }
    */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        italic: {
            /**
             * Set an italic mark
             * @example editor.commands.setItalic()
             */
            setItalic: () => ReturnType;
            /**
             * Toggle an italic mark
             * @example editor.commands.toggleItalic()
             */
            toggleItalic: () => ReturnType;
            /**
             * Unset an italic mark
             * @example editor.commands.unsetItalic()
             */
            unsetItalic: () => ReturnType;
        };
    }
}
/**
 * Matches an italic to a *italic* on input.
 */
export declare const starInputRegex: RegExp;
/**
 * Matches an italic to a *italic* on paste.
 */
export declare const starPasteRegex: RegExp;
/**
 * Matches an italic to a _italic_ on input.
 */
export declare const underscoreInputRegex: RegExp;
/**
 * Matches an italic to a _italic_ on paste.
 */
export declare const underscorePasteRegex: RegExp;
/**
 * This extension allows you to create italic text.
 * @see https://www.tiptap.dev/api/marks/italic
 */
export declare const Italic: Mark<ItalicOptions, any>;
//# sourceMappingURL=italic.d.ts.map