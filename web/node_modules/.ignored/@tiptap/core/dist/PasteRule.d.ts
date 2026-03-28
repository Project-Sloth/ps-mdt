import { EditorState, Plugin } from '@tiptap/pm/state';
import { Editor } from './Editor.js';
import { CanCommands, ChainedCommands, ExtendedRegExpMatchArray, Range, SingleCommands } from './types.js';
export type PasteRuleMatch = {
    index: number;
    text: string;
    replaceWith?: string;
    match?: RegExpMatchArray;
    data?: Record<string, any>;
};
export type PasteRuleFinder = RegExp | ((text: string, event?: ClipboardEvent | null) => PasteRuleMatch[] | null | undefined);
/**
 * Paste rules are used to react to pasted content.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#paste-rules
 */
export declare class PasteRule {
    find: PasteRuleFinder;
    handler: (props: {
        state: EditorState;
        range: Range;
        match: ExtendedRegExpMatchArray;
        commands: SingleCommands;
        chain: () => ChainedCommands;
        can: () => CanCommands;
        pasteEvent: ClipboardEvent | null;
        dropEvent: DragEvent | null;
    }) => void | null;
    constructor(config: {
        find: PasteRuleFinder;
        handler: (props: {
            can: () => CanCommands;
            chain: () => ChainedCommands;
            commands: SingleCommands;
            dropEvent: DragEvent | null;
            match: ExtendedRegExpMatchArray;
            pasteEvent: ClipboardEvent | null;
            range: Range;
            state: EditorState;
        }) => void | null;
    });
}
/**
 * Create an paste rules plugin. When enabled, it will cause pasted
 * text that matches any of the given rules to trigger the rule’s
 * action.
 */
export declare function pasteRulesPlugin(props: {
    editor: Editor;
    rules: PasteRule[];
}): Plugin[];
//# sourceMappingURL=PasteRule.d.ts.map