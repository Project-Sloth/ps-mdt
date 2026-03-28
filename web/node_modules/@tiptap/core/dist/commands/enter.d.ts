import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        enter: {
            /**
             * Trigger enter.
             * @example editor.commands.enter()
             */
            enter: () => ReturnType;
        };
    }
}
export declare const enter: RawCommands['enter'];
//# sourceMappingURL=enter.d.ts.map