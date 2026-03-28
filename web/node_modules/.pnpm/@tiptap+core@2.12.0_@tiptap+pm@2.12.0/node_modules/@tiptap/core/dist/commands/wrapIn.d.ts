import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        wrapIn: {
            /**
             * Wraps nodes in another node.
             * @param typeOrName The type or name of the node.
             * @param attributes The attributes of the node.
             * @example editor.commands.wrapIn('blockquote')
             */
            wrapIn: (typeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const wrapIn: RawCommands['wrapIn'];
//# sourceMappingURL=wrapIn.d.ts.map