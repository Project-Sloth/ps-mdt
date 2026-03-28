import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        splitListItem: {
            /**
             * Splits one list item into two list items.
             * @param typeOrName The type or name of the node.
             * @param overrideAttrs The attributes to ensure on the new node.
             * @example editor.commands.splitListItem('listItem')
             */
            splitListItem: (typeOrName: string | NodeType, overrideAttrs?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const splitListItem: RawCommands['splitListItem'];
//# sourceMappingURL=splitListItem.d.ts.map