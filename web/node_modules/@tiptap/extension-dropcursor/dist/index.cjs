'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');
var dropcursor = require('@tiptap/pm/dropcursor');

/**
 * This extension allows you to add a drop cursor to your editor.
 * A drop cursor is a line that appears when you drag and drop content
 * inbetween nodes.
 * @see https://tiptap.dev/api/extensions/dropcursor
 */
const Dropcursor = core.Extension.create({
    name: 'dropCursor',
    addOptions() {
        return {
            color: 'currentColor',
            width: 1,
            class: undefined,
        };
    },
    addProseMirrorPlugins() {
        return [
            dropcursor.dropCursor(this.options),
        ];
    },
});

exports.Dropcursor = Dropcursor;
exports.default = Dropcursor;
//# sourceMappingURL=index.cjs.map
