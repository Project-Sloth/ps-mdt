import { Schema } from '@tiptap/pm/model';
import { Plugin } from '@tiptap/pm/state';
import { NodeViewConstructor } from '@tiptap/pm/view';
import type { Editor } from './Editor.js';
import { Extensions, RawCommands } from './types.js';
export declare class ExtensionManager {
    editor: Editor;
    schema: Schema;
    extensions: Extensions;
    splittableMarks: string[];
    constructor(extensions: Extensions, editor: Editor);
    /**
     * Returns a flattened and sorted extension list while
     * also checking for duplicated extensions and warns the user.
     * @param extensions An array of Tiptap extensions
     * @returns An flattened and sorted array of Tiptap extensions
     */
    static resolve(extensions: Extensions): Extensions;
    /**
     * Create a flattened array of extensions by traversing the `addExtensions` field.
     * @param extensions An array of Tiptap extensions
     * @returns A flattened array of Tiptap extensions
     */
    static flatten(extensions: Extensions): Extensions;
    /**
     * Sort extensions by priority.
     * @param extensions An array of Tiptap extensions
     * @returns A sorted array of Tiptap extensions by priority
     */
    static sort(extensions: Extensions): Extensions;
    /**
     * Get all commands from the extensions.
     * @returns An object with all commands where the key is the command name and the value is the command function
     */
    get commands(): RawCommands;
    /**
     * Get all registered Prosemirror plugins from the extensions.
     * @returns An array of Prosemirror plugins
     */
    get plugins(): Plugin[];
    /**
     * Get all attributes from the extensions.
     * @returns An array of attributes
     */
    get attributes(): import("@tiptap/core").ExtensionAttribute[];
    /**
     * Get all node views from the extensions.
     * @returns An object with all node views where the key is the node name and the value is the node view function
     */
    get nodeViews(): Record<string, NodeViewConstructor>;
    /**
     * Go through all extensions, create extension storages & setup marks
     * & bind editor event listener.
     */
    private setupExtensions;
}
//# sourceMappingURL=ExtensionManager.d.ts.map