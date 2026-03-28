import { FocusPosition, RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        focus: {
            /**
             * Focus the editor at the given position.
             * @param position The position to focus at.
             * @param options.scrollIntoView Scroll the focused position into view after focusing
             * @example editor.commands.focus()
             * @example editor.commands.focus(32, { scrollIntoView: false })
             */
            focus: (
            /**
             * The position to focus at.
             */
            position?: FocusPosition, 
            /**
             * Optional options
             * @default { scrollIntoView: true }
             */
            options?: {
                scrollIntoView?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const focus: RawCommands['focus'];
//# sourceMappingURL=focus.d.ts.map