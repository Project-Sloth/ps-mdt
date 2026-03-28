/**
 * The identifier key which is used to check objects for whether they are a
 * certain type.
 *
 * @remarks
 *
 * Just pretend you don't know this exists.
 *
 * @internal
 */
declare const __INTERNAL_REMIRROR_IDENTIFIER_KEY__: unique symbol;
export { __INTERNAL_REMIRROR_IDENTIFIER_KEY__ }
export { __INTERNAL_REMIRROR_IDENTIFIER_KEY__ as __INTERNAL_REMIRROR_IDENTIFIER_KEY___alias_1 }

declare const BaseExtensionTag: {
    /**
     * Describes a node that can be used as the last node of a document and
     * doesn't need to have anything else rendered after itself.
     *
     * @remarks
     *
     * e.g. `paragraph`
     */
    readonly LastNodeCompatible: "lastNodeCompatible";
    /**
     * A mark that is used to change the formatting of the node it wraps.
     *
     * @remarks
     *
     * e.g. `bold`, `italic`
     */
    readonly FormattingMark: "formattingMark";
    /**
     * A node that formats text in a non-standard way.
     *
     * @remarks
     *
     * e.g. `codeBlock`, `heading`, `blockquote`
     */
    readonly FormattingNode: "formattingNode";
    /**
     * Identifies a node which has problems with cursor navigation.
     *
     * @remarks
     *
     * When this tag is added to an extension this will be picked up by
     * behavioural extensions such as the NodeCursorExtension which makes hard to
     * reach nodes reachable using keyboard arrows.
     */
    readonly NodeCursor: "nodeCursor";
    /**
     * Mark group for font styling (e.g. bold, italic, underline, superscript).
     */
    readonly FontStyle: "fontStyle";
    /**
     * Mark groups for links.
     */
    readonly Link: "link";
    /**
     * Mark groups for colors (text-color, background-color, etc).
     */
    readonly Color: "color";
    /**
     * Mark group for alignment.
     */
    readonly Alignment: "alignment";
    /**
     * Mark group for indentation.
     */
    readonly Indentation: "indentation";
    /**
     * Extension which affect the behaviour of the content. Can be nodes marks or
     * plain.
     */
    readonly Behavior: "behavior";
    /**
     * Marks and nodes which contain code.
     */
    readonly Code: "code";
    /**
     * Whether this node is an inline node.
     *
     * - `text` is an inline node, but `paragraph` is a block node.
     */
    readonly InlineNode: "inline";
    /**
     * This is a node that can contain list items.
     */
    readonly ListContainerNode: "listContainer";
    /**
     * Tags the extension as a list item node which can be contained by
     * [[`ExtensionTag.ListNode`]].
     */
    readonly ListItemNode: "listItemNode";
    /**
     * Sets this as a block level node.
     */
    readonly Block: "block";
    /**
     * @deprecate use `ExtensionTags.Block` instead.
     */
    readonly BlockNode: "block";
    /**
     * Set this as a text block
     */
    readonly TextBlock: "textBlock";
    /**
     * A tag that excludes this from input rules.
     */
    readonly ExcludeInputRules: "excludeFromInputRules";
    /**
     * A mark or node that can't  be exited when at the end and beginning of the
     * document with an arrow key or backspace key.
     */
    readonly PreventExits: "preventsExits";
    /**
     * Represents a media compatible node.
     */
    readonly Media: "media";
};

/**
 * Helpful empty array for use when a default array value is needed.
 *
 * DO NOT MUTATE!
 */
declare const EMPTY_ARRAY: never[];
export { EMPTY_ARRAY }
export { EMPTY_ARRAY as EMPTY_ARRAY_alias_1 }

declare const EMPTY_NODE: {
    type: string;
    content: never[];
};
export { EMPTY_NODE }
export { EMPTY_NODE as EMPTY_NODE_alias_1 }

/**
 * A default empty object node. Useful for resetting the content of a
 * prosemirror document.
 */
declare const EMPTY_PARAGRAPH_NODE: {
    type: string;
    content: {
        type: string;
    }[];
};
export { EMPTY_PARAGRAPH_NODE }
export { EMPTY_PARAGRAPH_NODE as EMPTY_PARAGRAPH_NODE_alias_1 }

/**
 * The error codes for errors used throughout the codebase.
 *
 * @remarks
 *
 * They can be removed but should never be changed since they are also used to
 * reference the errors within search engines.
 */
declare enum ErrorConstant {
    /** An error happened but we're not quite sure why. */
    UNKNOWN = "RMR0001",
    /** The arguments passed to the command method were invalid. */
    INVALID_COMMAND_ARGUMENTS = "RMR0002",
    /** This is a custom error possibly thrown by an external library. */
    CUSTOM = "RMR0003",
    /**
     * An error occurred in a function called from the `@remirror/core-helpers`
     * library.
     */
    CORE_HELPERS = "RMR0004",
    /** You have attempted to change a value that shouldn't be changed. */
    MUTATION = "RMR0005",
    /**
     * This is an error which should not occur and is internal to the remirror
     * codebase.
     */
    INTERNAL = "RMR0006",
    /** You're editor is missing a required extension. */
    MISSING_REQUIRED_EXTENSION = "RMR0007",
    /**
     * Called a method event at the wrong time. Please make sure getter functions
     * are only called with within the scope of the returned functions. They
     * should not be called in the outer scope of your method.
     */
    MANAGER_PHASE_ERROR = "RMR0008",
    /**
     * The user requested an invalid extension from the getExtensions method.
     * Please check the `createExtensions` return method is returning an extension
     * with the defined constructor.
     */
    INVALID_GET_EXTENSION = "RMR0010",
    /**
     * Invalid value passed into `Manager constructor`. Only and
     * `Extensions` are supported.
     */
    INVALID_MANAGER_ARGUMENTS = "RMR0011",
    /**
     * There is a problem with the schema or you are trying to access a node /
     * mark that doesn't exists.
     */
    SCHEMA = "RMR0012",
    /**
     * The `helpers` method which is passed into the ``create*` method should only
     * be called within returned method since it relies on an active view (not
     * present in the outer scope).
     */
    HELPERS_CALLED_IN_OUTER_SCOPE = "RMR0013",
    /** The user requested an invalid extension from the manager. */
    INVALID_MANAGER_EXTENSION = "RMR0014",
    /** Command method names must be unique within the editor. */
    DUPLICATE_COMMAND_NAMES = "RMR0016",
    /** Helper method names must be unique within the editor. */
    DUPLICATE_HELPER_NAMES = "RMR0017",
    /** Attempted to chain a non chainable command. */
    NON_CHAINABLE_COMMAND = "RMR0018",
    /** The provided extension is invalid. */
    INVALID_EXTENSION = "RMR0019",
    /** The content provided to the editor is not supported. */
    INVALID_CONTENT = "RMR0021",
    /** An invalid name was used for the extension. */
    INVALID_NAME = "RMR0050",
    /** An error occurred within an extension. */
    EXTENSION = "RMR0100",
    /** The spec was defined without calling the `defaults`, `parse` or `dom` methods. */
    EXTENSION_SPEC = "RMR0101",
    /** Extra attributes must either be a string or an object. */
    EXTENSION_EXTRA_ATTRIBUTES = "RMR0102",
    /** A call to `extension.setOptions` was made with invalid keys. */
    INVALID_SET_EXTENSION_OPTIONS = "RMR0103",
    /**
     * `useRemirror` was called outside of the remirror context. It can only be used
     * within an active remirror context created by the `<Remirror />`.
     */
    REACT_PROVIDER_CONTEXT = "RMR0200",
    /**
     * `getRootProps` has been called MULTIPLE times. It should only be called ONCE during render.
     */
    REACT_GET_ROOT_PROPS = "RMR0201",
    /**
     * A problem occurred adding the editor view to the dom.
     */
    REACT_EDITOR_VIEW = "RMR0202",
    /**
     * There is a problem with your controlled editor setup.
     */
    REACT_CONTROLLED = "RMR0203",
    /**
     * Something went wrong with your custom ReactNodeView Component.
     */
    REACT_NODE_VIEW = "RMR0204",
    /**
     * You attempted to call `getContext` provided by the `useRemirror` prop
     * during the first render of the editor. This is not possible and should only
     * be after the editor first mounts.
     */
    REACT_GET_CONTEXT = "RMR0205",
    /**
     * An error occurred when rendering the react components.
     */
    REACT_COMPONENTS = "RMR0206",
    /**
     * An error occurred within a remirror hook.
     */
    REACT_HOOKS = "RMR0207",
    /**
     * There is something wrong with your i18n setup.
     */
    I18N_CONTEXT = "RMR0300"
}
export { ErrorConstant }
export { ErrorConstant as ErrorConstant_alias_1 }

/**
 * The priority of extension which determines what order it is loaded into the
 * editor.
 *
 * @remarks
 *
 * Higher priority extension (higher numberic value) will ensure the extension
 * has a higher preference in your editor. In the case where you load two
 * identical extensions into your editor (same name, or same constructor), the
 * extension with the  higher priority is the one that will be loaded.
 *
 * The higher the numeric value the higher the priority. The priority can also
 * be passed a number but naming things in this `enum` should help provide some
 * context to the numbers.
 *
 * By default all extensions are created with a `ExtensionPriority.Default`.
 */
declare enum ExtensionPriority {
    /**
     * Use this **never** 😉
     */
    Critical = 1000000,
    /**
     * A, like super duper, high priority.
     */
    Highest = 100000,
    /**
     * The highest priority level that should be used in a publicly shared
     * extension (to allow some wiggle room for downstream users overriding
     * priorities).
     */
    High = 10000,
    /**
     * A medium priority extension. This is typically all you need to take
     * priority over built in extensions.
     */
    Medium = 1000,
    /**
     * This is the **default** priority for most extensions.
     */
    Default = 100,
    /**
     * This is the **default** priority for builtin behavior changing extensions.
     */
    Low = 10,
    /**
     * This is useful for extensions that exist to be overridden.
     */
    Lowest = 0
}
export { ExtensionPriority }
export { ExtensionPriority as ExtensionPriority_alias_1 }

/**
 * The type for the extension tags..
 */
declare type ExtensionTag = Remirror.ExtensionTags & typeof BaseExtensionTag;

/**
 * These are the default supported tag strings which help categorize different
 * behaviors that extensions can exhibit.
 *
 * @remarks
 *
 * Any extension can register itself with multiple such behaviors and these
 * categorizations can be used by other extensions when running commands and
 * updating the document.
 */
declare const ExtensionTag: ExtensionTag;
export { ExtensionTag }
export { ExtensionTag as ExtensionTag_alias_1 }

/**
 * The string values which can be used as extension tags.
 */
declare type ExtensionTagType = ExtensionTag[keyof ExtensionTag];
export { ExtensionTagType }
export { ExtensionTagType as ExtensionTagType_alias_1 }

/**
 * ProseMirror uses the Unicode Character 'OBJECT REPLACEMENT CHARACTER'
 * (U+FFFC) as text representation for leaf nodes, i.e. nodes that don't have
 * any content or text property (e.g. hardBreak, emoji, mention, rule) It was
 * introduced because of https://github.com/ProseMirror/prosemirror/issues/262
 * This can be used in an input rule regex to be able to include or exclude such
 * nodes.
 */
declare const LEAF_NODE_REPLACING_CHARACTER = "\uFFFC";
export { LEAF_NODE_REPLACING_CHARACTER }
export { LEAF_NODE_REPLACING_CHARACTER as LEAF_NODE_REPLACING_CHARACTER_alias_1 }

/**
 * Identifies the stage the extension manager is at.
 */
declare enum ManagerPhase {
    /**
     * The initial value for the manager phase.
     */
    None = 0,
    /**
     * When the extension manager is being created and the onCreate methods are
     * being called.
     *
     * This happens within the RemirrorManager constructor.
     */
    Create = 1,
    /**
     * When the view is being added and all `onView` lifecycle methods are being
     * called. The view is typically added before the dom is ready for it.
     */
    EditorView = 2,
    /**
     * The phases of creating this manager are completed and `onTransaction` is
     * called every time the state updates.
     */
    Runtime = 3,
    /**
     * The manager is being destroyed.
     */
    Destroy = 4
}
export { ManagerPhase }
export { ManagerPhase as ManagerPhase_alias_1 }

/**
 * A method for updating the extension tags.
 *
 * ```tsx
 * import { ExtensionTag, mutateTag } from 'remirror';
 *
 * mutateTag((tag) => {
 *   tag.SuperCustom = 'superCustom';
 * });
 *
 * declare global {
 *   namespace Remirror {
 *     interface ExtensionTag {
 *       SuperCustom: 'superCustom';
 *     }
 *   }
 * }
 *
 *
 * log(ExtensionTag.SuperCustom); // This is fine ✅
 * log(ExtensionTag.NotDefined); // This will throw ❌
 * ```
 */
declare function mutateTag(mutator: (Tag: ExtensionTag) => void): void;
export { mutateTag }
export { mutateTag as mutateTag_alias_1 }

/**
 * The named shortcuts that can be used to update multiple commands.
 */
declare enum NamedShortcut {
    Undo = "_|undo|_",
    Redo = "_|redo|_",
    Bold = "_|bold|_",
    Italic = "_|italic|_",
    Underline = "_|underline|_",
    Strike = "_|strike|_",
    Code = "_|code|_",
    Paragraph = "_|paragraph|_",
    H1 = "_|h1|_",
    H2 = "_|h2|_",
    H3 = "_|h3|_",
    H4 = "_|h4|_",
    H5 = "_|h5|_",
    H6 = "_|h6|_",
    TaskList = "_|task|_",
    BulletList = "_|bullet|_",
    OrderedList = "_|number|_",
    Quote = "_|quote|_",
    Divider = "_|divider|_",
    Codeblock = "_|codeblock|_",
    ClearFormatting = "_|clear|_",
    Superscript = "_|sup|_",
    Subscript = "_|sub|_",
    LeftAlignment = "_|left-align|_",
    CenterAlignment = "_|center-align|_",
    RightAlignment = "_|right-align|_",
    JustifyAlignment = "_|justify-align|_",
    InsertLink = "_|link|_",
    /** @deprecated */
    Find = "_|find|_",
    /** @deprecated */
    FindBackwards = "_|find-backwards|_",
    /** @deprecated */
    FindReplace = "_|find-replace|_",
    AddFootnote = "_|footnote|_",
    AddComment = "_|comment|_",
    ContextMenu = "_|context-menu|_",
    IncreaseFontSize = "_|inc-font-size|_",
    DecreaseFontSize = "_|dec-font-size|_",
    IncreaseIndent = "_|indent|_",
    DecreaseIndent = "_|dedent|_",
    Shortcuts = "_|shortcuts|_",
    Copy = "_|copy|_",
    Cut = "_|cut|_",
    Paste = "_|paste|_",
    PastePlain = "_|paste-plain|_",
    SelectAll = "_|select-all|_",
    /**
     * A keyboard shortcut to trigger formatting the current block.
     *
     * @defaultValue 'Alt-Shift-F' (Mac) | 'Shift-Ctrl-F' (PC)
     */
    Format = "_|format|_"
}
export { NamedShortcut }
export { NamedShortcut as NamedShortcut_alias_1 }

/**
 * The non breaking space character.
 */
declare const NON_BREAKING_SPACE_CHAR = "\u00A0";
export { NON_BREAKING_SPACE_CHAR }
export { NON_BREAKING_SPACE_CHAR as NON_BREAKING_SPACE_CHAR_alias_1 }

/**
 * The null character.
 *
 * See {@link https://stackoverflow.com/a/6380172}
 */
declare const NULL_CHARACTER = "\0";
export { NULL_CHARACTER }
export { NULL_CHARACTER as NULL_CHARACTER_alias_1 }

/**
 * The global name for the module exported by the remirror webview bundle.
 */
declare const REMIRROR_WEBVIEW_NAME = "$$__REMIRROR_WEBVIEW_BUNDLE__$$";
export { REMIRROR_WEBVIEW_NAME }
export { REMIRROR_WEBVIEW_NAME as REMIRROR_WEBVIEW_NAME_alias_1 }

/**
 * These constants are stored on the `REMIRROR_IDENTIFIER_KEY` property of
 * `remirror` related constructors and instances in order to identify them as
 * being internal to Remirror.
 *
 * @remarks
 *
 * This helps to prevent issues around check types via `instanceof` which can
 * lead to false negatives.
 *
 * @internal
 */
declare enum RemirrorIdentifier {
    /**
     * Identifies `PlainExtension`s.
     */
    PlainExtension = "RemirrorPlainExtension",
    /**
     * Identifies `NodeExtension`s.
     */
    NodeExtension = "RemirrorNodeExtension",
    /**
     * Identifies `MarkExtension`s.
     */
    MarkExtension = "RemirrorMarkExtension",
    /**
     * Identifies `PlainExtensionConstructor`s.
     */
    PlainExtensionConstructor = "RemirrorPlainExtensionConstructor",
    /**
     * Identifies `NodeExtensionConstructor`s.
     */
    NodeExtensionConstructor = "RemirrorNodeExtensionConstructor",
    /**
     * Identifies `MarkExtensionConstructor`s.
     */
    MarkExtensionConstructor = "RemirrorMarkExtensionConstructor",
    /**
     * The string used to identify an instance of the `Manager`
     */
    Manager = "RemirrorManager",
    /**
     * The preset type identifier.
     */
    Preset = "RemirrorPreset",
    /**
     * The preset type identifier.
     */
    PresetConstructor = "RemirrorPresetConstructor"
}
export { RemirrorIdentifier }
export { RemirrorIdentifier as RemirrorIdentifier_alias_1 }

/**
 * The css class added to a node that is selected.
 */
declare const SELECTED_NODE_CLASS_NAME = "ProseMirror-selectednode";
export { SELECTED_NODE_CLASS_NAME }
export { SELECTED_NODE_CLASS_NAME as SELECTED_NODE_CLASS_NAME_alias_1 }

/**
 * The css selector for a selected node.
 */
declare const SELECTED_NODE_CLASS_SELECTOR: string;
export { SELECTED_NODE_CLASS_SELECTOR }
export { SELECTED_NODE_CLASS_SELECTOR as SELECTED_NODE_CLASS_SELECTOR_alias_1 }

/**
 * Indicates that a state update was caused by an override and not via
 * transactions or user commands.
 *
 * This is the case when `setContent` is called and for all `controlled` updates
 * within a `react` editor instance.
 */
declare const STATE_OVERRIDE = "__state_override__";
export { STATE_OVERRIDE }
export { STATE_OVERRIDE as STATE_OVERRIDE_alias_1 }

/**
 * A character useful for separating inline nodes.
 *
 * @remarks
 * Typically used in decorations as follows.
 *
 * ```ts
 * document.createTextNode(ZERO_WIDTH_SPACE_CHAR);
 * ```
 *
 * This produces the html entity '8203'
 */
declare const ZERO_WIDTH_SPACE_CHAR = "\u200B";
export { ZERO_WIDTH_SPACE_CHAR }
export { ZERO_WIDTH_SPACE_CHAR as ZERO_WIDTH_SPACE_CHAR_alias_1 }

export { }

declare global {
  namespace Remirror {
    /**
     * This interface is for extending the default `ExtensionTag`'s in your
     * codebase with full type checking support.
     */
    interface ExtensionTags {}
  }
}
