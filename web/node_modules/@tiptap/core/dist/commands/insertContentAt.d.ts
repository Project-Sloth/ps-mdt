import { Fragment, Node as ProseMirrorNode, ParseOptions } from '@tiptap/pm/model';
import { Content, Range, RawCommands } from '../types.js';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        insertContentAt: {
            /**
             * Insert a node or string of HTML at a specific position.
             * @example editor.commands.insertContentAt(0, '<h1>Example</h1>')
             */
            insertContentAt: (
            /**
             * The position to insert the content at.
             */
            position: number | Range, 
            /**
             * The ProseMirror content to insert.
             */
            value: Content | ProseMirrorNode | Fragment, 
            /**
             * Optional options
             */
            options?: {
                /**
                 * Options for parsing the content.
                 */
                parseOptions?: ParseOptions;
                /**
                 * Whether to update the selection after inserting the content.
                 */
                updateSelection?: boolean;
                /**
                 * Whether to apply input rules after inserting the content.
                 */
                applyInputRules?: boolean;
                /**
                 * Whether to apply paste rules after inserting the content.
                 */
                applyPasteRules?: boolean;
                /**
                 * Whether to throw an error if the content is invalid.
                 */
                errorOnInvalidContent?: boolean;
            }) => ReturnType;
        };
    }
}
export declare const insertContentAt: RawCommands['insertContentAt'];
//# sourceMappingURL=insertContentAt.d.ts.map