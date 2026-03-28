import { Node as ProseMirrorNode } from '@tiptap/pm/model';
import { Range, TextSerializer } from '../types.js';
/**
 * Gets the text between two positions in a Prosemirror node
 * and serializes it using the given text serializers and block separator (see getText)
 * @param startNode The Prosemirror node to start from
 * @param range The range of the text to get
 * @param options Options for the text serializer & block separator
 * @returns The text between the two positions
 */
export declare function getTextBetween(startNode: ProseMirrorNode, range: Range, options?: {
    blockSeparator?: string;
    textSerializers?: Record<string, TextSerializer>;
}): string;
//# sourceMappingURL=getTextBetween.d.ts.map