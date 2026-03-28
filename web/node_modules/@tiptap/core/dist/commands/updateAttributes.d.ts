import { MarkType, NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        updateAttributes: {
            /**
             * Update attributes of a node or mark.
             * @param typeOrName The type or name of the node or mark.
             * @param attributes The attributes of the node or mark.
             * @example editor.commands.updateAttributes('mention', { userId: "2" })
             */
            updateAttributes: (
            /**
             * The type or name of the node or mark.
             */
            typeOrName: string | NodeType | MarkType, 
            /**
             * The attributes of the node or mark.
             */
            attributes: Record<string, any>) => ReturnType;
        };
    }
}
export declare const updateAttributes: RawCommands['updateAttributes'];
//# sourceMappingURL=updateAttributes.d.ts.map