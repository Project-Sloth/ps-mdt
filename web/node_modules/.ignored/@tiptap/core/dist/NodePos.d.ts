import { Fragment, Node, ResolvedPos } from '@tiptap/pm/model';
import { Editor } from './Editor.js';
import { Content, Range } from './types.js';
export declare class NodePos {
    private resolvedPos;
    private isBlock;
    private editor;
    private get name();
    constructor(pos: ResolvedPos, editor: Editor, isBlock?: boolean, node?: Node | null);
    private currentNode;
    get node(): Node;
    get element(): HTMLElement;
    actualDepth: number | null;
    get depth(): number;
    get pos(): number;
    get content(): Fragment;
    set content(content: Content);
    get attributes(): {
        [key: string]: any;
    };
    get textContent(): string;
    get size(): number;
    get from(): number;
    get range(): Range;
    get to(): number;
    get parent(): NodePos | null;
    get before(): NodePos | null;
    get after(): NodePos | null;
    get children(): NodePos[];
    get firstChild(): NodePos | null;
    get lastChild(): NodePos | null;
    closest(selector: string, attributes?: {
        [key: string]: any;
    }): NodePos | null;
    querySelector(selector: string, attributes?: {
        [key: string]: any;
    }): NodePos | null;
    querySelectorAll(selector: string, attributes?: {
        [key: string]: any;
    }, firstItemOnly?: boolean): NodePos[];
    setAttribute(attributes: {
        [key: string]: any;
    }): void;
}
//# sourceMappingURL=NodePos.d.ts.map