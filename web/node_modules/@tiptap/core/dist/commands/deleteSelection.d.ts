import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        deleteSelection: {
            /**
             * Delete the selection, if there is one.
             * @example editor.commands.deleteSelection()
             */
            deleteSelection: () => ReturnType;
        };
    }
}
export declare const deleteSelection: RawCommands['deleteSelection'];
//# sourceMappingURL=deleteSelection.d.ts.map