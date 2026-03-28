import { MarkType } from '@tiptap/pm/model';
import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        setMark: {
            /**
             * Add a mark with new attributes.
             * @param typeOrName The mark type or name.
             * @example editor.commands.setMark('bold', { level: 1 })
             */
            setMark: (typeOrName: string | MarkType, attributes?: Record<string, any>) => ReturnType;
        };
    }
}
export declare const setMark: RawCommands['setMark'];
//# sourceMappingURL=setMark.d.ts.map