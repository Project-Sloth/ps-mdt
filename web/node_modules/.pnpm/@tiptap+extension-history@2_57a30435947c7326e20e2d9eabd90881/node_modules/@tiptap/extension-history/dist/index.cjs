'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');
var history = require('@tiptap/pm/history');

/**
 * This extension allows you to undo and redo recent changes.
 * @see https://www.tiptap.dev/api/extensions/history
 *
 * **Important**: If the `@tiptap/extension-collaboration` package is used, make sure to remove
 * the `history` extension, as it is not compatible with the `collaboration` extension.
 *
 * `@tiptap/extension-collaboration` uses its own history implementation.
 */
const History = core.Extension.create({
    name: 'history',
    addOptions() {
        return {
            depth: 100,
            newGroupDelay: 500,
        };
    },
    addCommands() {
        return {
            undo: () => ({ state, dispatch }) => {
                return history.undo(state, dispatch);
            },
            redo: () => ({ state, dispatch }) => {
                return history.redo(state, dispatch);
            },
        };
    },
    addProseMirrorPlugins() {
        return [
            history.history(this.options),
        ];
    },
    addKeyboardShortcuts() {
        return {
            'Mod-z': () => this.editor.commands.undo(),
            'Shift-Mod-z': () => this.editor.commands.redo(),
            'Mod-y': () => this.editor.commands.redo(),
            // Russian keyboard layouts
            'Mod-я': () => this.editor.commands.undo(),
            'Shift-Mod-я': () => this.editor.commands.redo(),
        };
    },
});

exports.History = History;
exports.default = History;
//# sourceMappingURL=index.cjs.map
