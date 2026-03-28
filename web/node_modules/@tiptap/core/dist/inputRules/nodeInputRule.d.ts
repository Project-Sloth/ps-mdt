import { NodeType } from '@tiptap/pm/model';
import { InputRule, InputRuleFinder } from '../InputRule.js';
import { ExtendedRegExpMatchArray } from '../types.js';
/**
 * Build an input rule that adds a node when the
 * matched text is typed into it.
 * @see https://tiptap.dev/docs/editor/extensions/custom-extensions/extend-existing#input-rules
 */
export declare function nodeInputRule(config: {
    /**
     * The regex to match.
     */
    find: InputRuleFinder;
    /**
     * The node type to add.
     */
    type: NodeType;
    /**
     * A function that returns the attributes for the node
     * can also be an object of attributes
     */
    getAttributes?: Record<string, any> | ((match: ExtendedRegExpMatchArray) => Record<string, any>) | false | null;
}): InputRule;
//# sourceMappingURL=nodeInputRule.d.ts.map