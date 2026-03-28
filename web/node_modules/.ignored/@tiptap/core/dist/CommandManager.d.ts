import { EditorState, Transaction } from '@tiptap/pm/state';
import { Editor } from './Editor.js';
import { AnyCommands, CanCommands, ChainedCommands, CommandProps, SingleCommands } from './types.js';
export declare class CommandManager {
    editor: Editor;
    rawCommands: AnyCommands;
    customState?: EditorState;
    constructor(props: {
        editor: Editor;
        state?: EditorState;
    });
    get hasCustomState(): boolean;
    get state(): EditorState;
    get commands(): SingleCommands;
    get chain(): () => ChainedCommands;
    get can(): () => CanCommands;
    createChain(startTr?: Transaction, shouldDispatch?: boolean): ChainedCommands;
    createCan(startTr?: Transaction): CanCommands;
    buildProps(tr: Transaction, shouldDispatch?: boolean): CommandProps;
}
//# sourceMappingURL=CommandManager.d.ts.map