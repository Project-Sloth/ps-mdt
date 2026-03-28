(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-strike"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * Matches a strike to a ~~strike~~ on input.
   */
  const inputRegex = /(?:^|\s)(~~(?!\s+~~)((?:[^~]+))~~(?!\s+~~))$/;
  /**
   * Matches a strike to a ~~strike~~ on paste.
   */
  const pasteRegex = /(?:^|\s)(~~(?!\s+~~)((?:[^~]+))~~(?!\s+~~))/g;
  /**
   * This extension allows you to create strike text.
   * @see https://www.tiptap.dev/api/marks/strike
   */
  const Strike = core.Mark.create({
      name: 'strike',
      addOptions() {
          return {
              HTMLAttributes: {},
          };
      },
      parseHTML() {
          return [
              {
                  tag: 's',
              },
              {
                  tag: 'del',
              },
              {
                  tag: 'strike',
              },
              {
                  style: 'text-decoration',
                  consuming: false,
                  getAttrs: style => (style.includes('line-through') ? {} : false),
              },
          ];
      },
      renderHTML({ HTMLAttributes }) {
          return ['s', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addCommands() {
          return {
              setStrike: () => ({ commands }) => {
                  return commands.setMark(this.name);
              },
              toggleStrike: () => ({ commands }) => {
                  return commands.toggleMark(this.name);
              },
              unsetStrike: () => ({ commands }) => {
                  return commands.unsetMark(this.name);
              },
          };
      },
      addKeyboardShortcuts() {
          return {
              'Mod-Shift-s': () => this.editor.commands.toggleStrike(),
          };
      },
      addInputRules() {
          return [
              core.markInputRule({
                  find: inputRegex,
                  type: this.type,
              }),
          ];
      },
      addPasteRules() {
          return [
              core.markPasteRule({
                  find: pasteRegex,
                  type: this.type,
              }),
          ];
      },
  });

  exports.Strike = Strike;
  exports.default = Strike;
  exports.inputRegex = inputRegex;
  exports.pasteRegex = pasteRegex;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
