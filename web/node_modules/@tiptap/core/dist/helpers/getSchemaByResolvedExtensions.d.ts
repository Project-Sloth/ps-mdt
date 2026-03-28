import { Schema } from '@tiptap/pm/model';
import { Editor } from '../index.js';
import { Extensions } from '../types.js';
/**
 * Creates a new Prosemirror schema based on the given extensions.
 * @param extensions An array of Tiptap extensions
 * @param editor The editor instance
 * @returns A Prosemirror schema
 */
export declare function getSchemaByResolvedExtensions(extensions: Extensions, editor?: Editor): Schema;
//# sourceMappingURL=getSchemaByResolvedExtensions.d.ts.map