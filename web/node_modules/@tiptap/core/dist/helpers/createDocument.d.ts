import { Fragment, Node as ProseMirrorNode, ParseOptions, Schema } from '@tiptap/pm/model';
import { Content } from '../types.js';
/**
 * Create a new Prosemirror document node from content.
 * @param content The JSON or HTML content to create the document from
 * @param schema The Prosemirror schema to use for the document
 * @param parseOptions Options for the parser
 * @returns The created Prosemirror document node
 */
export declare function createDocument(content: Content | ProseMirrorNode | Fragment, schema: Schema, parseOptions?: ParseOptions, options?: {
    errorOnInvalidContent?: boolean;
}): ProseMirrorNode;
//# sourceMappingURL=createDocument.d.ts.map