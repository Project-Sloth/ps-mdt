import { Fragment, Node as ProseMirrorNode, ParseOptions, Schema } from '@tiptap/pm/model';
import { Content } from '../types.js';
export type CreateNodeFromContentOptions = {
    slice?: boolean;
    parseOptions?: ParseOptions;
    errorOnInvalidContent?: boolean;
};
/**
 * Takes a JSON or HTML content and creates a Prosemirror node or fragment from it.
 * @param content The JSON or HTML content to create the node from
 * @param schema The Prosemirror schema to use for the node
 * @param options Options for the parser
 * @returns The created Prosemirror node or fragment
 */
export declare function createNodeFromContent(content: Content | ProseMirrorNode | Fragment, schema: Schema, options?: CreateNodeFromContentOptions): ProseMirrorNode | Fragment;
//# sourceMappingURL=createNodeFromContent.d.ts.map