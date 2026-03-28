export function defaultAwarenessStateFilter(currentClientId: number, userClientId: number, _user: any): boolean;
export function defaultCursorBuilder(user: any): HTMLElement;
export function defaultSelectionBuilder(user: any): import('prosemirror-view').DecorationAttrs;
export function createDecorations(state: any, awareness: Awareness, awarenessFilter: (arg0: number, arg1: number, arg2: any) => boolean, createCursor: (user: {
    name: string;
    color: string;
}, clientId: number) => Element, createSelection: (user: {
    name: string;
    color: string;
}, clientId: number) => import('prosemirror-view').DecorationAttrs): any;
export function yCursorPlugin(awareness: Awareness, { awarenessStateFilter, cursorBuilder, selectionBuilder, getSelection }?: {
    awarenessStateFilter?: (arg0: any, arg1: any, arg2: any) => boolean;
    cursorBuilder?: (user: any, clientId: number) => HTMLElement;
    selectionBuilder?: (user: any, clientId: number) => import('prosemirror-view').DecorationAttrs;
    getSelection?: (arg0: any) => any;
}, cursorStateField?: string): any;
import { Awareness } from "y-protocols/awareness";
