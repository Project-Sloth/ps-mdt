import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        scrollIntoView: {
            /**
             * Scroll the selection into view.
             * @example editor.commands.scrollIntoView()
             */
            scrollIntoView: () => ReturnType;
        };
    }
}
export declare const scrollIntoView: RawCommands['scrollIntoView'];
//# sourceMappingURL=scrollIntoView.d.ts.map