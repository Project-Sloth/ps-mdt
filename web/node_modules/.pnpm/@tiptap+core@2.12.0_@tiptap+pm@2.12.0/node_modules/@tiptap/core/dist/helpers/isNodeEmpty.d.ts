import { Node as ProseMirrorNode } from '@tiptap/pm/model';
/**
 * Returns true if the given prosemirror node is empty.
 */
export declare function isNodeEmpty(node: ProseMirrorNode, { checkChildren, ignoreWhitespace, }?: {
    /**
     * When true (default), it will also check if all children are empty.
     */
    checkChildren?: boolean;
    /**
     * When true, it will ignore whitespace when checking for emptiness.
     */
    ignoreWhitespace?: boolean;
}): boolean;
//# sourceMappingURL=isNodeEmpty.d.ts.map