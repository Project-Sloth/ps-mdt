import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        createParagraphNear: {
            /**
             * Create a paragraph nearby.
             * @example editor.commands.createParagraphNear()
             */
            createParagraphNear: () => ReturnType;
        };
    }
}
export declare const createParagraphNear: RawCommands['createParagraphNear'];
//# sourceMappingURL=createParagraphNear.d.ts.map