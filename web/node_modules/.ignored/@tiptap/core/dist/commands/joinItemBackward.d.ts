import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        joinItemBackward: {
            /**
             * Join two items backward.
             * @example editor.commands.joinItemBackward()
             */
            joinItemBackward: () => ReturnType;
        };
    }
}
export declare const joinItemBackward: RawCommands['joinItemBackward'];
//# sourceMappingURL=joinItemBackward.d.ts.map