import { DOMOutputSpec, Mark as ProseMirrorMark, MarkSpec, MarkType } from '@tiptap/pm/model';
import { Plugin, Transaction } from '@tiptap/pm/state';
import { Editor } from './Editor.js';
import { MarkConfig } from './index.js';
import { InputRule } from './InputRule.js';
import { Node } from './Node.js';
import { PasteRule } from './PasteRule.js';
import { Attributes, Extensions, GlobalAttributes, KeyboardShortcutCommand, ParentConfig, RawCommands } from './types.js';
declare module '@tiptap/core' {
    interface MarkConfig<Options = any, Storage = any> {
        [key: string]: any;
        /**
         * The extension name - this must be unique.
         * It will be used to identify the extension.
         *
         * @example 'myExtension'
         */
        name: string;
        /**
         * The priority of your extension. The higher, the earlier it will be called
         * and will take precedence over other extensions with a lower priority.
         * @default 100
         * @example 101
         */
        priority?: number;
        /**
         * The default options for this extension.
         * @example
         * defaultOptions: {
         *   myOption: 'foo',
         *   myOtherOption: 10,
         * }
         */
        defaultOptions?: Options;
        /**
         * This method will add options to this extension
         * @see https://tiptap.dev/guide/custom-extensions#settings
         * @example
         * addOptions() {
         *  return {
         *    myOption: 'foo',
         *    myOtherOption: 10,
         * }
         */
        addOptions?: (this: {
            name: string;
            parent: Exclude<ParentConfig<MarkConfig<Options, Storage>>['addOptions'], undefined>;
        }) => Options;
        /**
         * The default storage this extension can save data to.
         * @see https://tiptap.dev/guide/custom-extensions#storage
         * @example
         * defaultStorage: {
         *   prefetchedUsers: [],
         *   loading: false,
         * }
         */
        addStorage?: (this: {
            name: string;
            options: Options;
            parent: Exclude<ParentConfig<MarkConfig<Options, Storage>>['addStorage'], undefined>;
        }) => Storage;
        /**
         * This function adds globalAttributes to specific nodes.
         * @see https://tiptap.dev/guide/custom-extensions#global-attributes
         * @example
         * addGlobalAttributes() {
         *   return [
         *     {
                 // Extend the following extensions
         *       types: [
         *         'heading',
         *         'paragraph',
         *       ],
         *       // … with those attributes
         *       attributes: {
         *         textAlign: {
         *           default: 'left',
         *           renderHTML: attributes => ({
         *             style: `text-align: ${attributes.textAlign}`,
         *           }),
         *           parseHTML: element => element.style.textAlign || 'left',
         *         },
         *       },
         *     },
         *   ]
         * }
         */
        addGlobalAttributes?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            extensions: (Node | Mark)[];
            parent: ParentConfig<MarkConfig<Options, Storage>>['addGlobalAttributes'];
        }) => GlobalAttributes;
        /**
         * This function adds commands to the editor
         * @see https://tiptap.dev/guide/custom-extensions#keyboard-shortcuts
         * @example
         * addCommands() {
         *   return {
         *     myCommand: () => ({ chain }) => chain().setMark('type', 'foo').run(),
         *   }
         * }
         */
        addCommands?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addCommands'];
        }) => Partial<RawCommands>;
        /**
         * This function registers keyboard shortcuts.
         * @see https://tiptap.dev/guide/custom-extensions#keyboard-shortcuts
         * @example
         * addKeyboardShortcuts() {
         *   return {
         *     'Mod-l': () => this.editor.commands.toggleBulletList(),
         *   }
         * },
         */
        addKeyboardShortcuts?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addKeyboardShortcuts'];
        }) => {
            [key: string]: KeyboardShortcutCommand;
        };
        /**
         * This function adds input rules to the editor.
         * @see https://tiptap.dev/guide/custom-extensions#input-rules
         * @example
         * addInputRules() {
         *   return [
         *     markInputRule({
         *       find: inputRegex,
         *       type: this.type,
         *     }),
         *   ]
         * },
         */
        addInputRules?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addInputRules'];
        }) => InputRule[];
        /**
         * This function adds paste rules to the editor.
         * @see https://tiptap.dev/guide/custom-extensions#paste-rules
         * @example
         * addPasteRules() {
         *   return [
         *     markPasteRule({
         *       find: pasteRegex,
         *       type: this.type,
         *     }),
         *   ]
         * },
         */
        addPasteRules?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addPasteRules'];
        }) => PasteRule[];
        /**
         * This function adds Prosemirror plugins to the editor
         * @see https://tiptap.dev/guide/custom-extensions#prosemirror-plugins
         * @example
         * addProseMirrorPlugins() {
         *   return [
         *     customPlugin(),
         *   ]
         * }
         */
        addProseMirrorPlugins?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addProseMirrorPlugins'];
        }) => Plugin[];
        /**
         * This function adds additional extensions to the editor. This is useful for
         * building extension kits.
         * @example
         * addExtensions() {
         *   return [
         *     BulletList,
         *     OrderedList,
         *     ListItem
         *   ]
         * }
         */
        addExtensions?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addExtensions'];
        }) => Extensions;
        /**
         * This function extends the schema of the node.
         * @example
         * extendNodeSchema() {
         *   return {
         *     group: 'inline',
         *     selectable: false,
         *   }
         * }
         */
        extendNodeSchema?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['extendNodeSchema'];
        }, extension: Node) => Record<string, any>) | null;
        /**
         * This function extends the schema of the mark.
         * @example
         * extendMarkSchema() {
         *   return {
         *     group: 'inline',
         *     selectable: false,
         *   }
         * }
         */
        extendMarkSchema?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['extendMarkSchema'];
        }, extension: Mark) => Record<string, any>) | null;
        /**
         * The editor is not ready yet.
         */
        onBeforeCreate?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onBeforeCreate'];
        }) => void) | null;
        /**
         * The editor is ready.
         */
        onCreate?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onCreate'];
        }) => void) | null;
        /**
         * The content has changed.
         */
        onUpdate?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onUpdate'];
        }) => void) | null;
        /**
         * The selection has changed.
         */
        onSelectionUpdate?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onSelectionUpdate'];
        }) => void) | null;
        /**
         * The editor state has changed.
         */
        onTransaction?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onTransaction'];
        }, props: {
            editor: Editor;
            transaction: Transaction;
        }) => void) | null;
        /**
         * The editor is focused.
         */
        onFocus?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onFocus'];
        }, props: {
            event: FocusEvent;
        }) => void) | null;
        /**
         * The editor isn’t focused anymore.
         */
        onBlur?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onBlur'];
        }, props: {
            event: FocusEvent;
        }) => void) | null;
        /**
         * The editor is destroyed.
         */
        onDestroy?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            editor: Editor;
            type: MarkType;
            parent: ParentConfig<MarkConfig<Options, Storage>>['onDestroy'];
        }) => void) | null;
        /**
         * Keep mark after split node
         */
        keepOnSplit?: boolean | (() => boolean);
        /**
         * Inclusive
         */
        inclusive?: MarkSpec['inclusive'] | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['inclusive'];
            editor?: Editor;
        }) => MarkSpec['inclusive']);
        /**
         * Excludes
         */
        excludes?: MarkSpec['excludes'] | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['excludes'];
            editor?: Editor;
        }) => MarkSpec['excludes']);
        /**
         * Marks this Mark as exitable
         */
        exitable?: boolean | (() => boolean);
        /**
         * Group
         */
        group?: MarkSpec['group'] | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['group'];
            editor?: Editor;
        }) => MarkSpec['group']);
        /**
         * Spanning
         */
        spanning?: MarkSpec['spanning'] | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['spanning'];
            editor?: Editor;
        }) => MarkSpec['spanning']);
        /**
         * Code
         */
        code?: boolean | ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['code'];
            editor?: Editor;
        }) => boolean);
        /**
         * Parse HTML
         */
        parseHTML?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['parseHTML'];
            editor?: Editor;
        }) => MarkSpec['parseDOM'];
        /**
         * Render HTML
         */
        renderHTML?: ((this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['renderHTML'];
            editor?: Editor;
        }, props: {
            mark: ProseMirrorMark;
            HTMLAttributes: Record<string, any>;
        }) => DOMOutputSpec) | null;
        /**
         * Attributes
         */
        addAttributes?: (this: {
            name: string;
            options: Options;
            storage: Storage;
            parent: ParentConfig<MarkConfig<Options, Storage>>['addAttributes'];
            editor?: Editor;
        }) => Attributes | {};
    }
}
/**
 * The Mark class is used to create custom mark extensions.
 * @see https://tiptap.dev/api/extensions#create-a-new-extension
 */
export declare class Mark<Options = any, Storage = any> {
    type: string;
    name: string;
    parent: Mark | null;
    child: Mark | null;
    options: Options;
    storage: Storage;
    config: MarkConfig;
    constructor(config?: Partial<MarkConfig<Options, Storage>>);
    static create<O = any, S = any>(config?: Partial<MarkConfig<O, S>>): Mark<O, S>;
    configure(options?: Partial<Options>): Mark<Options, Storage>;
    extend<ExtendedOptions = Options, ExtendedStorage = Storage>(extendedConfig?: Partial<MarkConfig<ExtendedOptions, ExtendedStorage>>): Mark<ExtendedOptions, ExtendedStorage>;
    static handleExit({ editor, mark }: {
        editor: Editor;
        mark: Mark;
    }): boolean;
}
//# sourceMappingURL=Mark.d.ts.map