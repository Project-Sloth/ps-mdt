import { Extension } from '@tiptap/core';
import { ySyncPlugin, yUndoPlugin } from 'y-prosemirror';
import { Doc, XmlFragment } from 'yjs';
type YSyncOpts = Parameters<typeof ySyncPlugin>[1];
type YUndoOpts = Parameters<typeof yUndoPlugin>[0];
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        collaboration: {
            /**
             * Undo recent changes
             * @example editor.commands.undo()
             */
            undo: () => ReturnType;
            /**
             * Reapply reverted changes
             * @example editor.commands.redo()
             */
            redo: () => ReturnType;
        };
    }
}
export interface CollaborationStorage {
    /**
     * Whether collaboration is currently disabled.
     * Disabling collaboration will prevent any changes from being synced with other users.
     */
    isDisabled: boolean;
}
export interface CollaborationOptions {
    /**
     * An initialized Y.js document.
     * @example new Y.Doc()
     */
    document?: Doc | null;
    /**
     * Name of a Y.js fragment, can be changed to sync multiple fields with one Y.js document.
     * @default 'default'
     * @example 'my-custom-field'
     */
    field?: string;
    /**
     * A raw Y.js fragment, can be used instead of `document` and `field`.
     * @example new Y.Doc().getXmlFragment('body')
     */
    fragment?: XmlFragment | null;
    /**
     * Fired when the content from Yjs is initially rendered to Tiptap.
     */
    onFirstRender?: () => void;
    /**
     * Options for the Yjs sync plugin.
     */
    ySyncOptions?: YSyncOpts;
    /**
     * Options for the Yjs undo plugin.
     */
    yUndoOptions?: YUndoOpts;
}
/**
 * This extension allows you to collaborate with others in real-time.
 * @see https://tiptap.dev/api/extensions/collaboration
 */
export declare const Collaboration: Extension<CollaborationOptions, CollaborationStorage>;
export {};
//# sourceMappingURL=collaboration.d.ts.map