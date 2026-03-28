import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        unsetAllMarks: {
            /**
             * Remove all marks in the current selection.
             * @example editor.commands.unsetAllMarks()
             */
            unsetAllMarks: () => ReturnType;
        };
    }
}
export declare const unsetAllMarks: RawCommands['unsetAllMarks'];
//# sourceMappingURL=unsetAllMarks.d.ts.map