import { Node } from '@tiptap/core';
/**
 * The heading level options.
 */
export type Level = 1 | 2 | 3 | 4 | 5 | 6;
export interface HeadingOptions {
    /**
     * The available heading levels.
     * @default [1, 2, 3, 4, 5, 6]
     * @example [1, 2, 3]
     */
    levels: Level[];
    /**
     * The HTML attributes for a heading node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        heading: {
            /**
             * Set a heading node
             * @param attributes The heading attributes
             * @example editor.commands.setHeading({ level: 1 })
             */
            setHeading: (attributes: {
                level: Level;
            }) => ReturnType;
            /**
             * Toggle a heading node
             * @param attributes The heading attributes
             * @example editor.commands.toggleHeading({ level: 1 })
             */
            toggleHeading: (attributes: {
                level: Level;
            }) => ReturnType;
        };
    }
}
/**
 * This extension allows you to create headings.
 * @see https://www.tiptap.dev/api/nodes/heading
 */
export declare const Heading: Node<HeadingOptions, any>;
//# sourceMappingURL=heading.d.ts.map