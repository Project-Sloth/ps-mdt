import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        lift: {
            /**
             * Removes an existing wrap if possible lifting the node out of it
             * @param typeOrName The type or name of the node.
             * @param attributes The attributes of the node.
             * @example editor.commands.lift('paragraph')
             * @example editor.commands.lift('heading', { level: 1 })
             */
            lift: (typeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const lift: RawCommands['lift'];
//# sourceMappingURL=lift.d.ts.map