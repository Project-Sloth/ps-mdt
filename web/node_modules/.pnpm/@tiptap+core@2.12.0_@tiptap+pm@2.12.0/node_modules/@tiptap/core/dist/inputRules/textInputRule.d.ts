import { InputRule, InputRuleFinder } from '../InputRule.js';
/**
 * Build an input rule that replaces text when the
 * matched text is typed into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#input-rules
 */
export declare function textInputRule(config: {
    find: InputRuleFinder;
    replace: string;
}): InputRule;
//# sourceMappingURL=textInputRule.d.ts.map