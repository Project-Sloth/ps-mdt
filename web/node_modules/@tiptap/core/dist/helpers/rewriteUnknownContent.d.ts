import type { Schema } from '@tiptap/pm/model';
import type { JSONContent } from '../types.js';
type RewriteUnknownContentOptions = {
    /**
     * If true, unknown nodes will be treated as paragraphs
     * @default true
     */
    fallbackToParagraph?: boolean;
};
/**
 * Rewrite unknown nodes and marks within JSON content
 * Allowing for user within the editor
 */
export declare function rewriteUnknownContent(
/**
 * The JSON content to clean of unknown nodes and marks
 */
json: JSONContent, 
/**
 * The schema to use for validation
 */
schema: Schema, 
/**
 * Options for the cleaning process
 */
options?: RewriteUnknownContentOptions): {
    /**
     * The cleaned JSON content
     */
    json: JSONContent | null;
    /**
     * The array of nodes and marks that were rewritten
     */
    rewrittenContent: {
        /**
         * The original JSON content that was rewritten
         */
        original: JSONContent;
        /**
         * The name of the node or mark that was unsupported
         */
        unsupported: string;
    }[];
};
export {};
//# sourceMappingURL=rewriteUnknownContent.d.ts.map