import { NodeType } from '@tiptap/pm/model';
import { PasteRule, PasteRuleFinder } from '../PasteRule.js';
import { ExtendedRegExpMatchArray, JSONContent } from '../types.js';
/**
 * Build an paste rule that adds a node when the
 * matched text is pasted into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#paste-rules
 */
export declare function nodePasteRule(config: {
    find: PasteRuleFinder;
    type: NodeType;
    getAttributes?: Record<string, any> | ((match: ExtendedRegExpMatchArray, event: ClipboardEvent) => Record<string, any>) | false | null;
    getContent?: JSONContent[] | ((attrs: Record<string, any>) => JSONContent[]) | false | null;
}): PasteRule;
//# sourceMappingURL=nodePasteRule.d.ts.map