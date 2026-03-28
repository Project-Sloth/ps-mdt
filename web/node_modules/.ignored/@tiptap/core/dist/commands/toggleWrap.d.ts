import { NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        toggleWrap: {
            /**
             * Wraps nodes in another node, or removes an existing wrap.
             * @param typeOrName The type or name of the node.
             * @param attributes The attributes of the node.
             * @example editor.commands.toggleWrap('blockquote')
             */
            toggleWrap: (typeOrName: string | NodeType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const toggleWrap: RawCommands['toggleWrap'];
//# sourceMappingURL=toggleWrap.d.ts.map