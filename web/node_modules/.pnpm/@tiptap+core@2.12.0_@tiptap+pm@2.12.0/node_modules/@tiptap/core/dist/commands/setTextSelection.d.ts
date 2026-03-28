import { Range, RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        setTextSelection: {
            /**
             * Creates a TextSelection.
             * @param position The position of the selection.
             * @example editor.commands.setTextSelection(10)
             */
            setTextSelection: (position: number | Range) => ReturnType;
        };
    }
}
export declare const setTextSelection: RawCommands['setTextSelection'];
//# sourceMappingURL=setTextSelection.d.ts.map