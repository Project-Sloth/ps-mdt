import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        deleteCurrentNode: {
            /**
             * Delete the node that currently has the selection anchor.
             * @example editor.commands.deleteCurrentNode()
             */
            deleteCurrentNode: () => ReturnType;
        };
    }
}
export declare const deleteCurrentNode: RawCommands['deleteCurrentNode'];
//# sourceMappingURL=deleteCurrentNode.d.ts.map