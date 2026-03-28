import { NodeView as ProseMirrorNodeView, ViewMutationRecord } from '@tiptap/pm/view';
import { Editor as CoreEditor } from './Editor.js';
import { NodeViewRendererOptions, NodeViewRendererProps } from './types.js';
/**
 * Node views are used to customize the rendered DOM structure of a node.
 * @see https://tiptap.dev/guide/node-views
 */
export declare class NodeView<Component, NodeEditor extends CoreEditor = CoreEditor, Options extends NodeViewRendererOptions = NodeViewRendererOptions> implements ProseMirrorNodeView {
    component: Component;
    editor: NodeEditor;
    options: Options;
    extension: NodeViewRendererProps['extension'];
    node: NodeViewRendererProps['node'];
    decorations: NodeViewRendererProps['decorations'];
    innerDecorations: NodeViewRendererProps['innerDecorations'];
    view: NodeViewRendererProps['view'];
    getPos: NodeViewRendererProps['getPos'];
    HTMLAttributes: NodeViewRendererProps['HTMLAttributes'];
    isDragging: boolean;
    constructor(component: Component, props: NodeViewRendererProps, options?: Partial<Options>);
    mount(): void;
    get dom(): HTMLElement;
    get contentDOM(): HTMLElement | null;
    onDragStart(event: DragEvent): void;
    stopEvent(event: Event): boolean;
    /**
     * Called when a DOM [mutation](https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver) or a selection change happens within the view.
     * @return `false` if the editor should re-read the selection or re-parse the range around the mutation
     * @return `true` if it can safely be ignored.
     */
    ignoreMutation(mutation: ViewMutationRecord): boolean;
    /**
     * Update the attributes of the prosemirror node.
     */
    updateAttributes(attributes: Record<string, any>): void;
    /**
     * Delete the node.
     */
    deleteNode(): void;
}
//# sourceMappingURL=NodeView.d.ts.map