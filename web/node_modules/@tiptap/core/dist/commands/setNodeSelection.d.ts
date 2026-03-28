import { RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        setNodeSelection: {
            /**
             * Creates a NodeSelection.
             * @param position - Position of the node.
             * @example editor.commands.setNodeSelection(10)
             */
            setNodeSelection: (position: number) => ReturnType;
        };
    }
}
export declare const setNodeSelection: RawCommands['setNodeSelection'];
//# sourceMappingURL=setNodeSelection.d.ts.map