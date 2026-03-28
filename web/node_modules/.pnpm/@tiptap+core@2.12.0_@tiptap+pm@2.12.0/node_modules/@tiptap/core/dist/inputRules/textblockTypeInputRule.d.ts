import { NodeType } from '@tiptap/pm/model';
import { InputRule, InputRuleFinder } from '../InputRule.js';
import { ExtendedRegExpMatchArray } from '../types.js';
/**
 * Build an input rule that changes the type of a textblock when the
 * matched text is typed into it. When using a regular expresion you’ll
 * probably want the regexp to start with `^`, so that the pattern can
 * only occur at the start of a textblock.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#input-rules
 */
export declare function textblockTypeInputRule(config: {
    find: InputRuleFinder;
    type: NodeType;
    getAttributes?: Record<string, any> | ((match: ExtendedRegExpMatchArray) => Record<string, any>) | false | null;
}): InputRule;
//# sourceMappingURL=textblockTypeInputRule.d.ts.map