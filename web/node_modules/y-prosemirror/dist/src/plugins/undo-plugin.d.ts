export function undo(state: import('prosemirror-state').EditorState): boolean;
export function redo(state: import('prosemirror-state').EditorState): boolean;
/**
 * Undo the last user action if there are undo operations available
 * @type {import('prosemirror-state').Command}
 */
export const undoCommand: import('prosemirror-state').Command;
/**
 * Redo the last user action if there are redo operations available
 * @type {import('prosemirror-state').Command}
 */
export const redoCommand: import('prosemirror-state').Command;
export const defaultProtectedNodes: Set<string>;
export function defaultDeleteFilter(item: import('yjs').Item, protectedNodes: Set<string>): boolean;
export function yUndoPlugin({ protectedNodes, trackedOrigins, undoManager }?: {
    protectedNodes?: Set<string>;
    trackedOrigins?: any[];
    undoManager?: import('yjs').UndoManager | null;
}): Plugin<{
    undoManager: UndoManager;
    prevSel: any;
    hasUndoOps: boolean;
    hasRedoOps: boolean;
}>;
export type UndoPluginState = {
    undoManager: import('yjs').UndoManager;
    prevSel: ReturnType<typeof getRelativeSelection> | null;
    hasUndoOps: boolean;
    hasRedoOps: boolean;
};
import { UndoManager } from 'yjs';
import { Plugin } from 'prosemirror-state';
import { getRelativeSelection } from './sync-plugin.js';
