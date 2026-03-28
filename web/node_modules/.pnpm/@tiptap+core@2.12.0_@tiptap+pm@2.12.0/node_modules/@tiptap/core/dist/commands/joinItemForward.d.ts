import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        joinItemForward: {
            /**
             * Join two items Forwards.
             * @example editor.commands.joinItemForward()
             */
            joinItemForward: () => ReturnType;
        };
    }
}
export declare const joinItemForward: RawCommands['joinItemForward'];
//# sourceMappingURL=joinItemForward.d.ts.map