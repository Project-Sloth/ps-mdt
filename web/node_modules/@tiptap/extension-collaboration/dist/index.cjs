'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');
var state = require('@tiptap/pm/state');
var yProsemirror = require('y-prosemirror');

/**
 * This extension allows you to collaborate with others in real-time.
 * @see https://tiptap.dev/api/extensions/collaboration
 */
const Collaboration = core.Extension.create({
    name: 'collaboration',
    priority: 1000,
    addOptions() {
        return {
            document: null,
            field: 'default',
            fragment: null,
        };
    },
    addStorage() {
        return {
            isDisabled: false,
        };
    },
    onCreate() {
        if (this.editor.extensionManager.extensions.find(extension => extension.name === 'history')) {
            console.warn('[tiptap warn]: "@tiptap/extension-collaboration" comes with its own history support and is not compatible with "@tiptap/extension-history".');
        }
    },
    addCommands() {
        return {
            undo: () => ({ tr, state, dispatch }) => {
                tr.setMeta('preventDispatch', true);
                const undoManager = yProsemirror.yUndoPluginKey.getState(state).undoManager;
                if (undoManager.undoStack.length === 0) {
                    return false;
                }
                if (!dispatch) {
                    return true;
                }
                return yProsemirror.undo(state);
            },
            redo: () => ({ tr, state, dispatch }) => {
                tr.setMeta('preventDispatch', true);
                const undoManager = yProsemirror.yUndoPluginKey.getState(state).undoManager;
                if (undoManager.redoStack.length === 0) {
                    return false;
                }
                if (!dispatch) {
                    return true;
                }
                return yProsemirror.redo(state);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-z': () => this.editor.commands.undo(),
            'Mod-y': () => this.editor.commands.redo(),
            'Shift-Mod-z': () => this.editor.commands.redo(),
        };
    },
    addProseMirrorPlugins() {
        var _a;
        const fragment = this.options.fragment
            ? this.options.fragment
            : this.options.document.getXmlFragment(this.options.field);
        // Quick fix until there is an official implementation (thanks to @hamflx).
        // See https://github.com/yjs/y-prosemirror/issues/114 and https://github.com/yjs/y-prosemirror/issues/102
        const yUndoPluginInstance = yProsemirror.yUndoPlugin(this.options.yUndoOptions);
        const originalUndoPluginView = yUndoPluginInstance.spec.view;
        yUndoPluginInstance.spec.view = (view) => {
            const { undoManager } = yProsemirror.yUndoPluginKey.getState(view.state);
            if (undoManager.restore) {
                undoManager.restore();
                undoManager.restore = () => {
                    // noop
                };
            }
            const viewRet = originalUndoPluginView ? originalUndoPluginView(view) : undefined;
            return {
                destroy: () => {
                    const hasUndoManSelf = undoManager.trackedOrigins.has(undoManager);
                    // eslint-disable-next-line no-underscore-dangle
                    const observers = undoManager._observers;
                    undoManager.restore = () => {
                        if (hasUndoManSelf) {
                            undoManager.trackedOrigins.add(undoManager);
                        }
                        undoManager.doc.on('afterTransaction', undoManager.afterTransactionHandler);
                        // eslint-disable-next-line no-underscore-dangle
                        undoManager._observers = observers;
                    };
                    if (viewRet === null || viewRet === void 0 ? void 0 : viewRet.destroy) {
                        viewRet.destroy();
                    }
                },
            };
        };
        const ySyncPluginOptions = {
            ...this.options.ySyncOptions,
            onFirstRender: this.options.onFirstRender,
        };
        const ySyncPluginInstance = yProsemirror.ySyncPlugin(fragment, ySyncPluginOptions);
        if (this.editor.options.enableContentCheck) {
            (_a = fragment.doc) === null || _a === void 0 ? void 0 : _a.on('beforeTransaction', () => {
                try {
                    const jsonContent = (yProsemirror.yXmlFragmentToProsemirrorJSON(fragment));
                    if (jsonContent.content.length === 0) {
                        return;
                    }
                    this.editor.schema.nodeFromJSON(jsonContent).check();
                }
                catch (error) {
                    this.editor.emit('contentError', {
                        error: error,
                        editor: this.editor,
                        disableCollaboration: () => {
                            var _a;
                            (_a = fragment.doc) === null || _a === void 0 ? void 0 : _a.destroy();
                            this.storage.isDisabled = true;
                        },
                    });
                    // If the content is invalid, return false to prevent the transaction from being applied
                    return false;
                }
            });
        }
        return [
            ySyncPluginInstance,
            yUndoPluginInstance,
            // Only add the filterInvalidContent plugin if content checking is enabled
            this.editor.options.enableContentCheck
                && new state.Plugin({
                    key: new state.PluginKey('filterInvalidContent'),
                    filterTransaction: () => {
                        var _a;
                        // When collaboration is disabled, prevent any sync transactions from being applied
                        if (this.storage.isDisabled) {
                            // Destroy the Yjs document to prevent any further sync transactions
                            (_a = fragment.doc) === null || _a === void 0 ? void 0 : _a.destroy();
                            return true;
                        }
                        return true;
                    },
                }),
        ].filter(Boolean);
    },
});

/**
 * Checks if a transaction was originated from a Yjs change.
 * @param {Transaction} transaction - The transaction to check.
 * @returns {boolean} - True if the transaction was originated from a Yjs change, false otherwise.
 * @example
 * const transaction = new Transaction(doc)
 * const isOrigin = isChangeOrigin(transaction) // returns false
 */
function isChangeOrigin(transaction) {
    return !!transaction.getMeta(yProsemirror.ySyncPluginKey);
}

exports.Collaboration = Collaboration;
exports.default = Collaboration;
exports.isChangeOrigin = isChangeOrigin;
//# sourceMappingURL=index.cjs.map
