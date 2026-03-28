import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        clearNodes: {
            /**
             * Normalize nodes to a simple paragraph.
             * @example editor.commands.clearNodes()
             */
            clearNodes: () => ReturnType;
        };
    }
}
export declare const clearNodes: RawCommands['clearNodes'];
//# sourceMappingURL=clearNodes.d.ts.map