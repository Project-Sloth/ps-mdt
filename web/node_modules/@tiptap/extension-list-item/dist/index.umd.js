(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-list-item"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * This extension allows you to create list items.
   * @see https://www.tiptap.dev/api/nodes/list-item
   */
  const ListItem = core.Node.create({
      name: 'listItem',
      addOptions() {
          return {
              HTMLAttributes: {},
              bulletListTypeName: 'bulletList',
              orderedListTypeName: 'orderedList',
          };
      },
      content: 'paragraph block*',
      defining: true,
      parseHTML() {
          return [
              {
                  tag: 'li',
              },
          ];
      },
      renderHTML({ HTMLAttributes }) {
          return ['li', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addKeyboardShortcuts() {
          return {
              Enter: () => this.editor.commands.splitListItem(this.name),
              Tab: () => this.editor.commands.sinkListItem(this.name),
              'Shift-Tab': () => this.editor.commands.liftListItem(this.name),
          };
      },
  });

  exports.ListItem = ListItem;
  exports.default = ListItem;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
