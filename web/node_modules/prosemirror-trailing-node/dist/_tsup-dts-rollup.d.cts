import { Plugin as Plugin_2 } from 'prosemirror-state';

/**
 * This creates the plugin for trailing node.
 *
 * ```ts
 * import { schema } from 'prosemirror-schema-basic';
 * import { trailingNode } from 'prosemirror-trailing-node';
 *
 * // Include the plugin in the created editor state.
 * const state = EditorState.create({
 *   schema,
 *   plugins: [trailingNode({ ignoredNodes: [], nodeName: 'paragraph' })],
 * });
 * ```
 *
 * @param options - the options that can be provided to this plugin.
 */
declare function trailingNode(options?: TrailingNodePluginOptions): Plugin_2<boolean>;
export { trailingNode }
export { trailingNode as trailingNode_alias_1 }

declare interface TrailingNodePluginOptions {
    /**
     * The node to create at the end of the document.
     *
     * **Note**: the nodeName will always be added to the `ignoredNodes` lists to
     * prevent an infinite loop.
     *
     * @defaultValue 'paragraph'
     */
    nodeName?: string;
    /**
     * The nodes for which this rule should not apply.
     */
    ignoredNodes?: string[];
}
export { TrailingNodePluginOptions }
export { TrailingNodePluginOptions as TrailingNodePluginOptions_alias_1 }

export { }
