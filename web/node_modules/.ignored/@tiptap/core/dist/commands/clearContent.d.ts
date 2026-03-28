import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        clearContent: {
            /**
             * Clear the whole document.
             * @param emitUpdate Whether to emit an update event.
             * @example editor.commands.clearContent()
             */
            clearContent: (emitUpdate?: boolean) => ReturnType;
        };
    }
}
export declare const clearContent: RawCommands['clearContent'];
//# sourceMappingURL=clearContent.d.ts.map