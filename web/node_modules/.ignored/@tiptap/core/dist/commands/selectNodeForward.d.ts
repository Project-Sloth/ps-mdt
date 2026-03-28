import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        selectNodeForward: {
            /**
             * Select a node forward.
             * @example editor.commands.selectNodeForward()
             */
            selectNodeForward: () => ReturnType;
        };
    }
}
export declare const selectNodeForward: RawCommands['selectNodeForward'];
//# sourceMappingURL=selectNodeForward.d.ts.map