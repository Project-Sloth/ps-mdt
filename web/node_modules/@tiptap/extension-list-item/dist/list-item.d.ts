import { Node } from '@tiptap/core';
export interface ListItemOptions {
    /**
     * The HTML attributes for a list item node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
    /**
     * The node type for bulletList nodes
     * @default 'bulletList'
     * @example 'myCustomBulletList'
     */
    bulletListTypeName: string;
    /**
     * The node type for orderedList nodes
     * @default 'orderedList'
     * @example 'myCustomOrderedList'
     */
    orderedListTypeName: string;
}
/**
 * This extension allows you to create list items.
 * @see https://www.tiptap.dev/api/nodes/list-item
 */
export declare const ListItem: Node<ListItemOptions, any>;
//# sourceMappingURL=list-item.d.ts.map