import { Command, CommandProps, RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        first: {
            /**
             * Runs one command after the other and stops at the first which returns true.
             * @param commands The commands to run.
             * @example editor.commands.first([command1, command2])
             */
            first: (commands: Command[] | ((props: CommandProps) => Command[])) => ReturnType;
        };
    }
}
export declare const first: RawCommands['first'];
//# sourceMappingURL=first.d.ts.map