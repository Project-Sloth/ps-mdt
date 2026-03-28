import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        deleteNode: {
            /**
             * Delete a node with a given type or name.
             * @param typeOrName The type or name of the node.
             * @example editor.commands.deleteNode('paragraph')
             */
            deleteNode: (typeOrName: string | NodeType) => ReturnType;
        };
    }
}
export declare const deleteNode: RawCommands['deleteNode'];
//# sourceMappingURL=deleteNode.d.ts.map