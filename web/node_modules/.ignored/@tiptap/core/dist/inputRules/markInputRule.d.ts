import { MarkType } from '@tiptap/pm/model';
import { InputRule, InputRuleFinder } from '../InputRule.js';
import { ExtendedRegExpMatchArray } from '../types.js';
/**
 * Build an input rule that adds a mark when the
 * matched text is typed into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#input-rules
 */
export declare function markInputRule(config: {
    find: InputRuleFinder;
    type: MarkType;
    getAttributes?: Record<string, any> | ((match: ExtendedRegExpMatchArray) => Record<string, any>) | false | null;
}): InputRule;
//# sourceMappingURL=markInputRule.d.ts.map