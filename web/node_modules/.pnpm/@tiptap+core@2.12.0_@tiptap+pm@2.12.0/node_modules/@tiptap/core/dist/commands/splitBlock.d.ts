import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        splitBlock: {
            /**
             * Forks a new node from an existing node.
             * @param options.keepMarks Keep marks from the previous node.
             * @example editor.commands.splitBlock()
             * @example editor.commands.splitBlock({ keepMarks: true })
             */
            splitBlock: (options?: {
                keepMarks?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const splitBlock: RawCommands['splitBlock'];
//# sourceMappingURL=splitBlock.d.ts.map