import { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { NodeWithPos, Predicate, Range } from '../types.js';
/**
 * Same as `findChildren` but searches only within a `range`.
 * @param node The Prosemirror node to search in
 * @param range The range to search in
 * @param predicate The predicate to match
 * @returns An array of nodes with their positions
 */
export declare function findChildrenInRange(node: ProseMirrorNode, range: Range, predicate: Predicate): NodeWithPos[];
//# sourceMappingURL=findChildrenInRange.d.ts.map