import { Node } from '@tiptap/core';
export interface HardBreakOptions {
    /**
     * Controls if marks should be kept after being split by a hard break.
     * @default true
     * @example false
     */
    keepMarks: boolean;
    /**
     * HTML attributes to add to the hard break element.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        hardBreak: {
            /**
             * Add a hard break
             * @example editor.commands.setHardBreak()
             */
            setHardBreak: () => ReturnType;
        };
    }
}
/**
 * This extension allows you to insert hard breaks.
 * @see https://www.tiptap.dev/api/nodes/hard-break
 */
export declare const HardBreak: Node<HardBreakOptions, any>;
//# sourceMappingURL=hard-break.d.ts.map