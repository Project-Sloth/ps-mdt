import { Extension, ParentConfig } from '@tiptap/core';
declare module '@tiptap/core' {
    interface NodeConfig<Options, Storage> {
        /**
         * A function to determine whether the gap cursor is allowed at the current position. Must return `true` or `false`.
         * @default null
         */
        allowGapCursor?: boolean | null | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<NodeConfig<Options>>['allowGapCursor'];
        }) => boolean | null);
    }
}
/**
 * This extension allows you to add a gap cursor to your editor.
 * A gap cursor is a cursor that appears when you click on a place
 * where no content is present, for example inbetween nodes.
 * @see https://tiptap.dev/api/extensions/gapcursor
 */
export declare const Gapcursor: Extension<any, any>;
//# sourceMappingURL=gapcursor.d.ts.map