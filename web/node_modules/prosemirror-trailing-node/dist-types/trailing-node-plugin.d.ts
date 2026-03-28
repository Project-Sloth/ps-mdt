import { Plugin } from 'prosemirror-state';
export interface TrailingNodePluginOptions {
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
export declare function trailingNode(options?: TrailingNodePluginOptions): Plugin<boolean>;
