import { Extension } from '@tiptap/core';
import { dropCursor } from '@tiptap/pm/dropcursor';

/**
 * This extension allows you to add a drop cursor to your editor.
 * A drop cursor is a line that appears when you drag and drop content
 * inbetween nodes.
 * @see https://tiptap.dev/api/extensions/dropcursor
 */
const Dropcursor = Extension.create({
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
            dropCursor(this.options),
        ];
    },
});

export { Dropcursor, Dropcursor as default };
//# sourceMappingURL=index.js.map
