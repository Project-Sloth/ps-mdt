import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        selectAll: {
            /**
             * Select the whole document.
             * @example editor.commands.selectAll()
             */
            selectAll: () => ReturnType;
        };
    }
}
export declare const selectAll: RawCommands['selectAll'];
//# sourceMappingURL=selectAll.d.ts.map