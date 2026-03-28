// src/core-constants.ts
var SELECTED_NODE_CLASS_NAME = "ProseMirror-selectednode";
var SELECTED_NODE_CLASS_SELECTOR = ".".concat(SELECTED_NODE_CLASS_NAME);
var LEAF_NODE_REPLACING_CHARACTER = "\uFFFC";
var NULL_CHARACTER = "\0";
var STATE_OVERRIDE = "__state_override__";
var REMIRROR_WEBVIEW_NAME = "$$__REMIRROR_WEBVIEW_BUNDLE__$$";
var ZERO_WIDTH_SPACE_CHAR = "\u200B";
var NON_BREAKING_SPACE_CHAR = "\xA0";
var EMPTY_PARAGRAPH_NODE = {
  type: "doc",
  content: [
    {
      type: "paragraph"
    }
  ]
};
var EMPTY_NODE = {
  type: "doc",
  content: []
};
function mutateTag(mutator) {
  mutator(BaseExtensionTag);
}
var BaseExtensionTag = {
  /**
   * Describes a node that can be used as the last node of a document and
   * doesn't need to have anything else rendered after itself.
   *
   * @remarks
   *
   * e.g. `paragraph`
   */
  LastNodeCompatible: "lastNodeCompatible",
  /**
   * A mark that is used to change the formatting of the node it wraps.
   *
   * @remarks
   *
   * e.g. `bold`, `italic`
   */
  FormattingMark: "formattingMark",
  /**
   * A node that formats text in a non-standard way.
   *
   * @remarks
   *
   * e.g. `codeBlock`, `heading`, `blockquote`
   */
  FormattingNode: "formattingNode",
  /**
   * Identifies a node which has problems with cursor navigation.
   *
   * @remarks
   *
   * When this tag is added to an extension this will be picked up by
   * behavioural extensions such as the NodeCursorExtension which makes hard to
   * reach nodes reachable using keyboard arrows.
   */
  NodeCursor: "nodeCursor",
  /**
   * Mark group for font styling (e.g. bold, italic, underline, superscript).
   */
  FontStyle: "fontStyle",
  /**
   * Mark groups for links.
   */
  Link: "link",
  /**
   * Mark groups for colors (text-color, background-color, etc).
   */
  Color: "color",
  /**
   * Mark group for alignment.
   */
  Alignment: "alignment",
  /**
   * Mark group for indentation.
   */
  Indentation: "indentation",
  /**
   * Extension which affect the behaviour of the content. Can be nodes marks or
   * plain.
   */
  Behavior: "behavior",
  /**
   * Marks and nodes which contain code.
   */
  Code: "code",
  /**
   * Whether this node is an inline node.
   *
   * - `text` is an inline node, but `paragraph` is a block node.
   */
  InlineNode: "inline",
  /**
   * This is a node that can contain list items.
   */
  ListContainerNode: "listContainer",
  /**
   * Tags the extension as a list item node which can be contained by
   * [[`ExtensionTag.ListNode`]].
   */
  ListItemNode: "listItemNode",
  /**
   * Sets this as a block level node.
   */
  Block: "block",
  /**
   * @deprecate use `ExtensionTags.Block` instead.
   */
  BlockNode: "block",
  /**
   * Set this as a text block
   */
  TextBlock: "textBlock",
  /**
   * A tag that excludes this from input rules.
   */
  ExcludeInputRules: "excludeFromInputRules",
  /**
   * A mark or node that can't  be exited when at the end and beginning of the
   * document with an arrow key or backspace key.
   */
  PreventExits: "preventsExits",
  /**
   * Represents a media compatible node.
   */
  Media: "media"
};
var ExtensionTag = BaseExtensionTag;
var __INTERNAL_REMIRROR_IDENTIFIER_KEY__ = Symbol.for("__remirror__");
var RemirrorIdentifier = /* @__PURE__ */ ((RemirrorIdentifier2) => {
  RemirrorIdentifier2["PlainExtension"] = "RemirrorPlainExtension";
  RemirrorIdentifier2["NodeExtension"] = "RemirrorNodeExtension";
  RemirrorIdentifier2["MarkExtension"] = "RemirrorMarkExtension";
  RemirrorIdentifier2["PlainExtensionConstructor"] = "RemirrorPlainExtensionConstructor";
  RemirrorIdentifier2["NodeExtensionConstructor"] = "RemirrorNodeExtensionConstructor";
  RemirrorIdentifier2["MarkExtensionConstructor"] = "RemirrorMarkExtensionConstructor";
  RemirrorIdentifier2["Manager"] = "RemirrorManager";
  RemirrorIdentifier2["Preset"] = "RemirrorPreset";
  RemirrorIdentifier2["PresetConstructor"] = "RemirrorPresetConstructor";
  return RemirrorIdentifier2;
})(RemirrorIdentifier || {});
var ExtensionPriority = /* @__PURE__ */ ((ExtensionPriority2) => {
  ExtensionPriority2[ExtensionPriority2["Critical"] = 1e6] = "Critical";
  ExtensionPriority2[ExtensionPriority2["Highest"] = 1e5] = "Highest";
  ExtensionPriority2[ExtensionPriority2["High"] = 1e4] = "High";
  ExtensionPriority2[ExtensionPriority2["Medium"] = 1e3] = "Medium";
  ExtensionPriority2[ExtensionPriority2["Default"] = 100] = "Default";
  ExtensionPriority2[ExtensionPriority2["Low"] = 10] = "Low";
  ExtensionPriority2[ExtensionPriority2["Lowest"] = 0] = "Lowest";
  return ExtensionPriority2;
})(ExtensionPriority || {});
var ManagerPhase = /* @__PURE__ */ ((ManagerPhase2) => {
  ManagerPhase2[ManagerPhase2["None"] = 0] = "None";
  ManagerPhase2[ManagerPhase2["Create"] = 1] = "Create";
  ManagerPhase2[ManagerPhase2["EditorView"] = 2] = "EditorView";
  ManagerPhase2[ManagerPhase2["Runtime"] = 3] = "Runtime";
  ManagerPhase2[ManagerPhase2["Destroy"] = 4] = "Destroy";
  return ManagerPhase2;
})(ManagerPhase || {});
var NamedShortcut = /* @__PURE__ */ ((NamedShortcut2) => {
  NamedShortcut2["Undo"] = "_|undo|_";
  NamedShortcut2["Redo"] = "_|redo|_";
  NamedShortcut2["Bold"] = "_|bold|_";
  NamedShortcut2["Italic"] = "_|italic|_";
  NamedShortcut2["Underline"] = "_|underline|_";
  NamedShortcut2["Strike"] = "_|strike|_";
  NamedShortcut2["Code"] = "_|code|_";
  NamedShortcut2["Paragraph"] = "_|paragraph|_";
  NamedShortcut2["H1"] = "_|h1|_";
  NamedShortcut2["H2"] = "_|h2|_";
  NamedShortcut2["H3"] = "_|h3|_";
  NamedShortcut2["H4"] = "_|h4|_";
  NamedShortcut2["H5"] = "_|h5|_";
  NamedShortcut2["H6"] = "_|h6|_";
  NamedShortcut2["TaskList"] = "_|task|_";
  NamedShortcut2["BulletList"] = "_|bullet|_";
  NamedShortcut2["OrderedList"] = "_|number|_";
  NamedShortcut2["Quote"] = "_|quote|_";
  NamedShortcut2["Divider"] = "_|divider|_";
  NamedShortcut2["Codeblock"] = "_|codeblock|_";
  NamedShortcut2["ClearFormatting"] = "_|clear|_";
  NamedShortcut2["Superscript"] = "_|sup|_";
  NamedShortcut2["Subscript"] = "_|sub|_";
  NamedShortcut2["LeftAlignment"] = "_|left-align|_";
  NamedShortcut2["CenterAlignment"] = "_|center-align|_";
  NamedShortcut2["RightAlignment"] = "_|right-align|_";
  NamedShortcut2["JustifyAlignment"] = "_|justify-align|_";
  NamedShortcut2["InsertLink"] = "_|link|_";
  NamedShortcut2["Find"] = "_|find|_";
  NamedShortcut2["FindBackwards"] = "_|find-backwards|_";
  NamedShortcut2["FindReplace"] = "_|find-replace|_";
  NamedShortcut2["AddFootnote"] = "_|footnote|_";
  NamedShortcut2["AddComment"] = "_|comment|_";
  NamedShortcut2["ContextMenu"] = "_|context-menu|_";
  NamedShortcut2["IncreaseFontSize"] = "_|inc-font-size|_";
  NamedShortcut2["DecreaseFontSize"] = "_|dec-font-size|_";
  NamedShortcut2["IncreaseIndent"] = "_|indent|_";
  NamedShortcut2["DecreaseIndent"] = "_|dedent|_";
  NamedShortcut2["Shortcuts"] = "_|shortcuts|_";
  NamedShortcut2["Copy"] = "_|copy|_";
  NamedShortcut2["Cut"] = "_|cut|_";
  NamedShortcut2["Paste"] = "_|paste|_";
  NamedShortcut2["PastePlain"] = "_|paste-plain|_";
  NamedShortcut2["SelectAll"] = "_|select-all|_";
  NamedShortcut2["Format"] = "_|format|_";
  return NamedShortcut2;
})(NamedShortcut || {});
var EMPTY_ARRAY = [];

// src/error-constants.ts
var ErrorConstant = /* @__PURE__ */ ((ErrorConstant2) => {
  ErrorConstant2["UNKNOWN"] = "RMR0001";
  ErrorConstant2["INVALID_COMMAND_ARGUMENTS"] = "RMR0002";
  ErrorConstant2["CUSTOM"] = "RMR0003";
  ErrorConstant2["CORE_HELPERS"] = "RMR0004";
  ErrorConstant2["MUTATION"] = "RMR0005";
  ErrorConstant2["INTERNAL"] = "RMR0006";
  ErrorConstant2["MISSING_REQUIRED_EXTENSION"] = "RMR0007";
  ErrorConstant2["MANAGER_PHASE_ERROR"] = "RMR0008";
  ErrorConstant2["INVALID_GET_EXTENSION"] = "RMR0010";
  ErrorConstant2["INVALID_MANAGER_ARGUMENTS"] = "RMR0011";
  ErrorConstant2["SCHEMA"] = "RMR0012";
  ErrorConstant2["HELPERS_CALLED_IN_OUTER_SCOPE"] = "RMR0013";
  ErrorConstant2["INVALID_MANAGER_EXTENSION"] = "RMR0014";
  ErrorConstant2["DUPLICATE_COMMAND_NAMES"] = "RMR0016";
  ErrorConstant2["DUPLICATE_HELPER_NAMES"] = "RMR0017";
  ErrorConstant2["NON_CHAINABLE_COMMAND"] = "RMR0018";
  ErrorConstant2["INVALID_EXTENSION"] = "RMR0019";
  ErrorConstant2["INVALID_CONTENT"] = "RMR0021";
  ErrorConstant2["INVALID_NAME"] = "RMR0050";
  ErrorConstant2["EXTENSION"] = "RMR0100";
  ErrorConstant2["EXTENSION_SPEC"] = "RMR0101";
  ErrorConstant2["EXTENSION_EXTRA_ATTRIBUTES"] = "RMR0102";
  ErrorConstant2["INVALID_SET_EXTENSION_OPTIONS"] = "RMR0103";
  ErrorConstant2["REACT_PROVIDER_CONTEXT"] = "RMR0200";
  ErrorConstant2["REACT_GET_ROOT_PROPS"] = "RMR0201";
  ErrorConstant2["REACT_EDITOR_VIEW"] = "RMR0202";
  ErrorConstant2["REACT_CONTROLLED"] = "RMR0203";
  ErrorConstant2["REACT_NODE_VIEW"] = "RMR0204";
  ErrorConstant2["REACT_GET_CONTEXT"] = "RMR0205";
  ErrorConstant2["REACT_COMPONENTS"] = "RMR0206";
  ErrorConstant2["REACT_HOOKS"] = "RMR0207";
  ErrorConstant2["I18N_CONTEXT"] = "RMR0300";
  return ErrorConstant2;
})(ErrorConstant || {});
export {
  EMPTY_ARRAY,
  EMPTY_NODE,
  EMPTY_PARAGRAPH_NODE,
  ErrorConstant,
  ExtensionPriority,
  ExtensionTag,
  LEAF_NODE_REPLACING_CHARACTER,
  ManagerPhase,
  NON_BREAKING_SPACE_CHAR,
  NULL_CHARACTER,
  NamedShortcut,
  REMIRROR_WEBVIEW_NAME,
  RemirrorIdentifier,
  SELECTED_NODE_CLASS_NAME,
  SELECTED_NODE_CLASS_SELECTOR,
  STATE_OVERRIDE,
  ZERO_WIDTH_SPACE_CHAR,
  __INTERNAL_REMIRROR_IDENTIFIER_KEY__,
  mutateTag
};
