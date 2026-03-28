import { MarkType, NodeType } from '@tiptap/pm/model';
import { EditorState } from '@tiptap/pm/state';
/**
 * Get node or mark attributes by type or name on the current editor state
 * @param state The current editor state
 * @param typeOrName The node or mark type or name
 * @returns The attributes of the node or mark or an empty object
 */
export declare function getAttributes(state: EditorState, typeOrName: string | NodeType | MarkType): Record<string, any>;
//# sourceMappingURL=getAttributes.d.ts.map