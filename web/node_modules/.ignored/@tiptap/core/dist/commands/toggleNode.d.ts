import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        toggleNode: {
            /**
             * Toggle a node with another node.
             * @param typeOrName The type or name of the node.
             * @param toggleTypeOrName The type or name of the node to toggle.
             * @param attributes The attributes of the node.
             * @example editor.commands.toggleNode('heading', 'paragraph')
             */
            toggleNode: (typeOrName: string | NodeType, toggleTypeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const toggleNode: RawCommands['toggleNode'];
//# sourceMappingURL=toggleNode.d.ts.map