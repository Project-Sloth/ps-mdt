import { Extension } from '@tiptap/core';
import { DecorationAttrs } from '@tiptap/pm/view';
type CollaborationCursorStorage = {
    users: {
        clientId: number;
        [key: string]: any;
    }[];
};
export interface CollaborationCursorOptions {
    /**
     * The Hocuspocus provider instance. This can also be a TiptapCloudProvider instance.
     * @type {HocuspocusProvider | TiptapCloudProvider}
     * @example new HocuspocusProvider()
     */
    provider: any;
    /**
     * The user details object – feel free to add properties to this object as needed
     * @example { name: 'John Doe', color: '#305500' }
     */
    user: Record<string, any>;
    /**
     * A function that returns a DOM element for the cursor.
     * @param user The user details object
     * @example
     * render: user => {
     *  const cursor = document.createElement('span')
     *  cursor.classList.add('collaboration-cursor__caret')
     *  cursor.setAttribute('style', `border-color: ${user.color}`)
     *
     *  const label = document.createElement('div')
     *  label.classList.add('collaboration-cursor__label')
     *  label.setAttribute('style', `background-color: ${user.color}`)
     *  label.insertBefore(document.createTextNode(user.name), null)
     *
     *  cursor.insertBefore(label, null)
     *  return cursor
     * }
     */
    render(user: Record<string, any>): HTMLElement;
    /**
     * A function that returns a ProseMirror DecorationAttrs object for the selection.
     * @param user The user details object
     * @example
     * selectionRender: user => {
     * return {
     *  nodeName: 'span',
     *  class: 'collaboration-cursor__selection',
     *  style: `background-color: ${user.color}`,
     *  'data-user': user.name,
     * }
     */
    selectionRender(user: Record<string, any>): DecorationAttrs;
    /**
     * @deprecated The "onUpdate" option is deprecated. Please use `editor.storage.collaborationCursor.users` instead. Read more: https://tiptap.dev/api/extensions/collaboration-cursor
     */
    onUpdate: (users: {
        clientId: number;
        [key: string]: any;
    }[]) => null;
}
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        collaborationCursor: {
            /**
             * Update details of the current user
             * @example editor.commands.updateUser({ name: 'John Doe', color: '#305500' })
             */
            updateUser: (attributes: Record<string, any>) => ReturnType;
            /**
             * Update details of the current user
             *
             * @deprecated The "user" command is deprecated. Please use "updateUser" instead. Read more: https://tiptap.dev/api/extensions/collaboration-cursor
             */
            user: (attributes: Record<string, any>) => ReturnType;
        };
    }
}
/**
 * This extension allows you to add collaboration cursors to your editor.
 * @see https://tiptap.dev/api/extensions/collaboration-cursor
 */
export declare const CollaborationCursor: Extension<CollaborationCursorOptions, CollaborationCursorStorage>;
export {};
//# sourceMappingURL=collaboration-cursor.d.ts.map