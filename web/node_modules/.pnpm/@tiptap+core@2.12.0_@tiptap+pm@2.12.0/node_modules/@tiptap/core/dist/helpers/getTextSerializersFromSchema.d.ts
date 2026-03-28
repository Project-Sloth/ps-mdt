import { Schema } from '@tiptap/pm/model';
import { TextSerializer } from '../types.js';
/**
 * Find text serializers `toText` in a Prosemirror schema
 * @param schema The Prosemirror schema to search in
 * @returns A record of text serializers by node name
 */
export declare function getTextSerializersFromSchema(schema: Schema): Record<string, TextSerializer>;
//# sourceMappingURL=getTextSerializersFromSchema.d.ts.map