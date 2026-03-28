import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        liftListItem: {
            /**
             * Create a command to lift the list item around the selection up into a wrapping list.
             * @param typeOrName The type or name of the node.
             * @example editor.commands.liftListItem('listItem')
             */
            liftListItem: (typeOrName: string | NodeType) => ReturnType;
        };
    }
}
export declare const liftListItem: RawCommands['liftListItem'];
//# sourceMappingURL=liftListItem.d.ts.map