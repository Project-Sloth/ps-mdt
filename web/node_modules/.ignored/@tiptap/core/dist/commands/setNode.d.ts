import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        setNode: {
            /**
             * Replace a given range with a node.
             * @param typeOrName The type or name of the node
             * @param attributes The attributes of the node
             * @example editor.commands.setNode('paragraph')
             */
            setNode: (typeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const setNode: RawCommands['setNode'];
//# sourceMappingURL=setNode.d.ts.map