(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-paragraph"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * This extension allows you to create paragraphs.
   * @see https://www.tiptap.dev/api/nodes/paragraph
   */
  const Paragraph = core.Node.create({
      name: 'paragraph',
      priority: 1000,
      addOptions() {
          return {
              HTMLAttributes: {},
          };
      },
      group: 'block',
      content: 'inline*',
      parseHTML() {
          return [
              { tag: 'p' },
          ];
      },
      renderHTML({ HTMLAttributes }) {
          return ['p', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addCommands() {
          return {
              setParagraph: () => ({ commands }) => {
                  return commands.setNode(this.name);
              },
          };
      },
      addKeyboardShortcuts() {
          return {
              'Mod-Alt-0': () => this.editor.commands.setParagraph(),
          };
      },
  });

  exports.Paragraph = Paragraph;
  exports.default = Paragraph;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
