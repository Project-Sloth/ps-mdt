import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        toggleList: {
            /**
             * Toggle between different list types.
             * @param listTypeOrName The type or name of the list.
             * @param itemTypeOrName The type or name of the list item.
             * @param keepMarks Keep marks when toggling.
             * @param attributes Attributes for the new list.
             * @example editor.commands.toggleList('bulletList', 'listItem')
             */
            toggleList: (listTypeOrName: string | NodeType, itemTypeOrName: string | NodeType, keepMarks?: boolean, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const toggleList: RawCommands['toggleList'];
//# sourceMappingURL=toggleList.d.ts.map