import { MarkType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        extendMarkRange: {
            /**
             * Extends the text selection to the current mark by type or name.
             * @param typeOrName The type or name of the mark.
             * @param attributes The attributes of the mark.
             * @example editor.commands.extendMarkRange('bold')
             * @example editor.commands.extendMarkRange('mention', { userId: "1" })
             */
            extendMarkRange: (
            /**
             * The type or name of the mark.
             */
            typeOrName: string | MarkType, 
            /**
             * The attributes of the mark.
             */
            attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const extendMarkRange: RawCommands['extendMarkRange'];
//# sourceMappingURL=extendMarkRange.d.ts.map