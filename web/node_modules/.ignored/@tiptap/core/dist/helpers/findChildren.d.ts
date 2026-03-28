import { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { NodeWithPos, Predicate } from '../types.js';
/**
 * Find children inside a Prosemirror node that match a predicate.
 * @param node The Prosemirror node to search in
 * @param predicate The predicate to match
 * @returns An array of nodes with their positions
 */
export declare function findChildren(node: ProseMirrorNode, predicate: Predicate): NodeWithPos[];
//# sourceMappingURL=findChildren.d.ts.map