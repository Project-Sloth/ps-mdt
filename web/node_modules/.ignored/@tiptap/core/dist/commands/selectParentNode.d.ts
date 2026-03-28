import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        selectParentNode: {
            /**
             * Select the parent node.
             * @example editor.commands.selectParentNode()
             */
            selectParentNode: () => ReturnType;
        };
    }
}
export declare const selectParentNode: RawCommands['selectParentNode'];
//# sourceMappingURL=selectParentNode.d.ts.map