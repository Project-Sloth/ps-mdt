import { MarkType } from '@tiptap/pm/model';
import { PasteRule, PasteRuleFinder } from '../PasteRule.js';
import { ExtendedRegExpMatchArray } from '../types.js';
/**
 * Build an paste rule that adds a mark when the
 * matched text is pasted into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#paste-rules
 */
export declare function markPasteRule(config: {
    find: PasteRuleFinder;
    type: MarkType;
    getAttributes?: Record<string, any> | ((match: ExtendedRegExpMatchArray, event: ClipboardEvent) => Record<string, any>) | false | null;
}): PasteRule;
//# sourceMappingURL=markPasteRule.d.ts.map