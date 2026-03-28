import { Extensions, JSONContent, TextSerializer } from '../types.js';
/**
 * Generate raw text from a JSONContent
 * @param doc The JSONContent to generate text from
 * @param extensions The extensions to use for the schema
 * @param options Options for the text generation f.e. blockSeparator or textSerializers
 * @returns The generated text
 */
export declare function generateText(doc: JSONContent, extensions: Extensions, options?: {
    blockSeparator?: string;
    textSerializers?: Record<string, TextSerializer>;
}): string;
//# sourceMappingURL=generateText.d.ts.map