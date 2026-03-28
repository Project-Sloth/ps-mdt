'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');
var state = require('@tiptap/pm/state');

/**
 * Matches a code block with backticks.
 */
const backtickInputRegex = /^```([a-z]+)?[\s\n]$/;
/**
 * Matches a code block with tildes.
 */
const tildeInputRegex = /^~~~([a-z]+)?[\s\n]$/;
/**
 * This extension allows you to create code blocks.
 * @see https://tiptap.dev/api/nodes/code-block
 */
const CodeBlock = core.Node.create({
    name: 'codeBlock',
    addOptions() {
        return {
            languageClassPrefix: 'language-',
            exitOnTripleEnter: true,
            exitOnArrowDown: true,
            defaultLanguage: null,
            HTMLAttributes: {},
        };
    },
    content: 'text*',
    marks: '',
    group: 'block',
    code: true,
    defining: true,
    addAttributes() {
        return {
            language: {
                default: this.options.defaultLanguage,
                parseHTML: element => {
                    var _a;
                    const { languageClassPrefix } = this.options;
                    const classNames = [...(((_a = element.firstElementChild) === null || _a === void 0 ? void 0 : _a.classList) || [])];
                    const languages = classNames
                        .filter(className => className.startsWith(languageClassPrefix))
                        .map(className => className.replace(languageClassPrefix, ''));
                    const language = languages[0];
                    if (!language) {
                        return null;
                    }
                    return language;
                },
                rendered: false,
            },
        };
    },
    parseHTML() {
        return [
            {
                tag: 'pre',
                preserveWhitespace: 'full',
            },
        ];
    },
    renderHTML({ node, HTMLAttributes }) {
        return [
            'pre',
            core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes),
            [
                'code',
                {
                    class: node.attrs.language
                        ? this.options.languageClassPrefix + node.attrs.language
                        : null,
                },
                0,
            ],
        ];
    },
    addCommands() {
        return {
            setCodeBlock: attributes => ({ commands }) => {
                return commands.setNode(this.name, attributes);
            },
            toggleCodeBlock: attributes => ({ commands }) => {
                return commands.toggleNode(this.name, 'paragraph', attributes);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-Alt-c': () => this.editor.commands.toggleCodeBlock(),
            // remove code block when at start of document or code block is empty
            Backspace: () => {
                const { empty, $anchor } = this.editor.state.selection;
                const isAtStart = $anchor.pos === 1;
                if (!empty || $anchor.parent.type.name !== this.name) {
                    return false;
                }
                if (isAtStart || !$anchor.parent.textContent.length) {
                    return this.editor.commands.clearNodes();
                }
                return false;
            },
            // exit node on triple enter
            Enter: ({ editor }) => {
                if (!this.options.exitOnTripleEnter) {
                    return false;
                }
                const { state } = editor;
                const { selection } = state;
                const { $from, empty } = selection;
                if (!empty || $from.parent.type !== this.type) {
                    return false;
                }
                const isAtEnd = $from.parentOffset === $from.parent.nodeSize - 2;
                const endsWithDoubleNewline = $from.parent.textContent.endsWith('\n\n');
                if (!isAtEnd || !endsWithDoubleNewline) {
                    return false;
                }
                return editor
                    .chain()
                    .command(({ tr }) => {
                    tr.delete($from.pos - 2, $from.pos);
                    return true;
                })
                    .exitCode()
                    .run();
            },
            // exit node on arrow down
            ArrowDown: ({ editor }) => {
                if (!this.options.exitOnArrowDown) {
                    return false;
                }
                const { state: state$1 } = editor;
                const { selection, doc } = state$1;
                const { $from, empty } = selection;
                if (!empty || $from.parent.type !== this.type) {
                    return false;
                }
                const isAtEnd = $from.parentOffset === $from.parent.nodeSize - 2;
                if (!isAtEnd) {
                    return false;
                }
                const after = $from.after();
                if (after === undefined) {
                    return false;
                }
                const nodeAfter = doc.nodeAt(after);
                if (nodeAfter) {
                    return editor.commands.command(({ tr }) => {
                        tr.setSelection(state.Selection.near(doc.resolve(after)));
                        return true;
                    });
                }
                return editor.commands.exitCode();
            },
        };
    },
    addInputRules() {
        return [
            core.textblockTypeInputRule({
                find: backtickInputRegex,
                type: this.type,
                getAttributes: match => ({
                    language: match[1],
                }),
            }),
            core.textblockTypeInputRule({
                find: tildeInputRegex,
                type: this.type,
                getAttributes: match => ({
                    language: match[1],
                }),
            }),
        ];
    },
    addProseMirrorPlugins() {
        return [
            // this plugin creates a code block for pasted content from VS Code
            // we can also detect the copied code language
            new state.Plugin({
                key: new state.PluginKey('codeBlockVSCodeHandler'),
                props: {
                    handlePaste: (view, event) => {
                        if (!event.clipboardData) {
                            return false;
                        }
                        // don’t create a new code block within code blocks
                        if (this.editor.isActive(this.type.name)) {
                            return false;
                        }
                        const text = event.clipboardData.getData('text/plain');
                        const vscode = event.clipboardData.getData('vscode-editor-data');
                        const vscodeData = vscode ? JSON.parse(vscode) : undefined;
                        const language = vscodeData === null || vscodeData === void 0 ? void 0 : vscodeData.mode;
                        if (!text || !language) {
                            return false;
                        }
                        const { tr, schema } = view.state;
                        // prepare a text node
                        // strip carriage return chars from text pasted as code
                        // see: https://github.com/ProseMirror/prosemirror-view/commit/a50a6bcceb4ce52ac8fcc6162488d8875613aacd
                        const textNode = schema.text(text.replace(/\r\n?/g, '\n'));
                        // create a code block with the text node
                        // replace selection with the code block
                        tr.replaceSelectionWith(this.type.create({ language }, textNode));
                        if (tr.selection.$from.parent.type !== this.type) {
                            // put cursor inside the newly created code block
                            tr.setSelection(state.TextSelection.near(tr.doc.resolve(Math.max(0, tr.selection.from - 2))));
                        }
                        // store meta information
                        // this is useful for other plugins that depends on the paste event
                        // like the paste rule plugin
                        tr.setMeta('paste', true);
                        view.dispatch(tr);
                        return true;
                    },
                },
            }),
        ];
    },
});

exports.CodeBlock = CodeBlock;
exports.backtickInputRegex = backtickInputRegex;
exports.default = CodeBlock;
exports.tildeInputRegex = tildeInputRegex;
//# sourceMappingURL=index.cjs.map
