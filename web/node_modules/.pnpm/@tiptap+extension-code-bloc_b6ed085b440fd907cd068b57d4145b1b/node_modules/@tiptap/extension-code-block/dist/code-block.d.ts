import { Node } from '@tiptap/core';
export interface CodeBlockOptions {
    /**
     * Adds a prefix to language classes that are applied to code tags.
     * @default 'language-'
     */
    languageClassPrefix: string;
    /**
     * Define whether the node should be exited on triple enter.
     * @default true
     */
    exitOnTripleEnter: boolean;
    /**
     * Define whether the node should be exited on arrow down if there is no node after it.
     * @default true
     */
    exitOnArrowDown: boolean;
    /**
     * The default language.
     * @default null
     * @example 'js'
     */
    defaultLanguage: string | null | undefined;
    /**
     * Custom HTML attributes that should be added to the rendered HTML tag.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        codeBlock: {
            /**
             * Set a code block
             * @param attributes Code block attributes
             * @example editor.commands.setCodeBlock({ language: 'javascript' })
             */
            setCodeBlock: (attributes?: {
                language: string;
            }) => ReturnType;
            /**
             * Toggle a code block
             * @param attributes Code block attributes
             * @example editor.commands.toggleCodeBlock({ language: 'javascript' })
             */
            toggleCodeBlock: (attributes?: {
                language: string;
            }) => ReturnType;
        };
    }
}
/**
 * Matches a code block with backticks.
 */
export declare const backtickInputRegex: RegExp;
/**
 * Matches a code block with tildes.
 */
export declare const tildeInputRegex: RegExp;
/**
 * This extension allows you to create code blocks.
 * @see https://tiptap.dev/api/nodes/code-block
 */
export declare const CodeBlock: Node<CodeBlockOptions, any>;
//# sourceMappingURL=code-block.d.ts.map