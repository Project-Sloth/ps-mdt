import { MarkType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        unsetMark: {
            /**
             * Remove all marks in the current selection.
             * @param typeOrName The mark type or name.
             * @param options.extendEmptyMarkRange Removes the mark even across the current selection. Defaults to `false`.
             * @example editor.commands.unsetMark('bold')
             */
            unsetMark: (
            /**
             * The mark type or name.
             */
            typeOrName: string | MarkType, options?: {
                /**
                 * Removes the mark even across the current selection. Defaults to `false`.
                 */
                extendEmptyMarkRange?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const unsetMark: RawCommands['unsetMark'];
//# sourceMappingURL=unsetMark.d.ts.map