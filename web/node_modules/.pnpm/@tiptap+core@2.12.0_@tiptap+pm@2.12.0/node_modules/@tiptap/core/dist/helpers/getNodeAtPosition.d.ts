import { Node, NodeType } from '@tiptap/pm/model';
import { EditorState } from '@tiptap/pm/state';
/**
 * Finds the first node of a given type or name in the current selection.
 * @param state The editor state.
 * @param typeOrName The node type or name.
 * @param pos The position to start searching from.
 * @param maxDepth The maximum depth to search.
 * @returns The node and the depth as an array.
 */
export declare const getNodeAtPosition: (state: EditorState, typeOrName: string | NodeType, pos: number, maxDepth?: number) => [Node | null, number];
//# sourceMappingURL=getNodeAtPosition.d.ts.map