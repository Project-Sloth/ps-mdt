import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        liftEmptyBlock: {
            /**
             * If the cursor is in an empty textblock that can be lifted, lift the block.
             * @example editor.commands.liftEmptyBlock()
             */
            liftEmptyBlock: () => ReturnType;
        };
    }
}
export declare const liftEmptyBlock: RawCommands['liftEmptyBlock'];
//# sourceMappingURL=liftEmptyBlock.d.ts.map