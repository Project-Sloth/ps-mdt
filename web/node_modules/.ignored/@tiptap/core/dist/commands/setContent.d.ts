import { Fragment, Node as ProseMirrorNode, ParseOptions } from '@tiptap/pm/model';
import { Content, RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        setContent: {
            /**
             * Replace the whole document with new content.
             * @param content The new content.
             * @param emitUpdate Whether to emit an update event.
             * @param parseOptions Options for parsing the content.
             * @example editor.commands.setContent('<p>Example text</p>')
             */
            setContent: (
            /**
             * The new content.
             */
            content: Content | Fragment | ProseMirrorNode, 
            /**
             * Whether to emit an update event.
             * @default false
             */
            emitUpdate?: boolean, 
            /**
             * Options for parsing the content.
             * @default {}
             */
            parseOptions?: ParseOptions, 
            /**
             * Options for `setContent`.
             */
            options?: {
                /**
                 * Whether to throw an error if the content is invalid.
                 */
                errorOnInvalidContent?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const setContent: RawCommands['setContent'];
//# sourceMappingURL=setContent.d.ts.map