import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        exitCode: {
            /**
             * Exit from a code block.
             * @example editor.commands.exitCode()
             */
            exitCode: () => ReturnType;
        };
    }
}
export declare const exitCode: RawCommands['exitCode'];
//# sourceMappingURL=exitCode.d.ts.map