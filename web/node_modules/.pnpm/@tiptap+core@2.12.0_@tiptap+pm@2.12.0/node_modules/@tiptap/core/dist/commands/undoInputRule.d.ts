import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        undoInputRule: {
            /**
             * Undo an input rule.
             * @example editor.commands.undoInputRule()
             */
            undoInputRule: () => ReturnType;
        };
    }
}
export declare const undoInputRule: RawCommands['undoInputRule'];
//# sourceMappingURL=undoInputRule.d.ts.map