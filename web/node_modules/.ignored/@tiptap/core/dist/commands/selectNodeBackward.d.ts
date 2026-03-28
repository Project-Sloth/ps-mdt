import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        selectNodeBackward: {
            /**
             * Select a node backward.
             * @example editor.commands.selectNodeBackward()
             */
            selectNodeBackward: () => ReturnType;
        };
    }
}
export declare const selectNodeBackward: RawCommands['selectNodeBackward'];
//# sourceMappingURL=selectNodeBackward.d.ts.map