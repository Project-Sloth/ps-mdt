import { PasteRule, PasteRuleFinder } from '../PasteRule.js';
/**
 * Build an paste rule that replaces text when the
 * matched text is pasted into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#paste-rules
 */
export declare function textPasteRule(config: {
    find: PasteRuleFinder;
    replace: string;
}): PasteRule;
//# sourceMappingURL=textPasteRule.d.ts.map