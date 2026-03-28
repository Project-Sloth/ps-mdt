import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        sinkListItem: {
            /**
             * Sink the list item down into an inner list.
             * @param typeOrName The type or name of the node.
             * @example editor.commands.sinkListItem('listItem')
             */
            sinkListItem: (typeOrName: string | NodeType) => ReturnType;
        };
    }
}
export declare const sinkListItem: RawCommands['sinkListItem'];
//# sourceMappingURL=sinkListItem.d.ts.map