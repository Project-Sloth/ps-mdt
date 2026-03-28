import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        keyboardShortcut: {
            /**
             * Trigger a keyboard shortcut.
             * @param name The name of the keyboard shortcut.
             * @example editor.commands.keyboardShortcut('Mod-b')
             */
            keyboardShortcut: (name: string) => ReturnType;
        };
    }
}
export declare const keyboardShortcut: RawCommands['keyboardShortcut'];
//# sourceMappingURL=keyboardShortcut.d.ts.map