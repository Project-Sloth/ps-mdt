import { MarkType, NodeType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        resetAttributes: {
            /**
             * Resets some node attributes to the default value.
             * @param typeOrName The type or name of the node.
             * @param attributes The attributes of the node to reset.
             * @example editor.commands.resetAttributes('heading', 'level')
             */
            resetAttributes: (typeOrName: string | NodeType | MarkType, attributes: string | string[]) => ReturnType;
        };
    }
}
export declare const resetAttributes: RawCommands['resetAttributes'];
//# sourceMappingURL=resetAttributes.d.ts.map