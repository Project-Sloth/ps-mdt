import { Selection } from '@tiptap/pm/state';
import { Predicate } from '../types.js';
/**
 * Finds the closest parent node to the current selection that matches a predicate.
 * @param predicate The predicate to match
 * @returns A command that finds the closest parent node to the current selection that matches the predicate
 * @example ```js
 * findParentNode(node => node.type.name === 'paragraph')
 * ```
 */
export declare function findParentNode(predicate: Predicate): (selection: Selection) => {
    pos: number;
    start: number;
    depth: number;
    node: import("prosemirror-model").Node;
} | undefined;
//# sourceMappingURL=findParentNode.d.ts.map