import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        wrapInList: {
            /**
             * Wrap a node in a list.
             * @param typeOrName The type or name of the node.
             * @param attributes The attributes of the node.
             * @example editor.commands.wrapInList('bulletList')
             */
            wrapInList: (typeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const wrapInList: RawCommands['wrapInList'];
//# sourceMappingURL=wrapInList.d.ts.map