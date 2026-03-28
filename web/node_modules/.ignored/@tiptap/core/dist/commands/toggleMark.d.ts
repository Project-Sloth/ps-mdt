import { MarkType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        toggleMark: {
            /**
             * Toggle a mark on and off.
             * @param typeOrName The mark type or name.
             * @param attributes The attributes of the mark.
             * @param options.extendEmptyMarkRange Removes the mark even across the current selection. Defaults to `false`.
             * @example editor.commands.toggleMark('bold')
             */
            toggleMark: (
            /**
             * The mark type or name.
             */
            typeOrName: string | MarkType, 
            /**
             * The attributes of the mark.
             */
            attributes?: Record<string, any>, options?: {
                /**
                 * Removes the mark even across the current selection. Defaults to `false`.
                 */
                extendEmptyMarkRange?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const toggleMark: RawCommands['toggleMark'];
//# sourceMappingURL=toggleMark.d.ts.map