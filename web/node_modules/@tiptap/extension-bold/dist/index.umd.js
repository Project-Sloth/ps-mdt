(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-bold"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * Matches bold text via `**` as input.
   */
  const starInputRegex = /(?:^|\s)(\*\*(?!\s+\*\*)((?:[^*]+))\*\*(?!\s+\*\*))$/;
  /**
   * Matches bold text via `**` while pasting.
   */
  const starPasteRegex = /(?:^|\s)(\*\*(?!\s+\*\*)((?:[^*]+))\*\*(?!\s+\*\*))/g;
  /**
   * Matches bold text via `__` as input.
   */
  const underscoreInputRegex = /(?:^|\s)(__(?!\s+__)((?:[^_]+))__(?!\s+__))$/;
  /**
   * Matches bold text via `__` while pasting.
   */
  const underscorePasteRegex = /(?:^|\s)(__(?!\s+__)((?:[^_]+))__(?!\s+__))/g;
  /**
   * This extension allows you to mark text as bold.
   * @see https://tiptap.dev/api/marks/bold
   */
  const Bold = core.Mark.create({
      name: 'bold',
      addOptions() {
          return {
              HTMLAttributes: {},
          };
      },
      parseHTML() {
          return [
              {
                  tag: 'strong',
              },
              {
                  tag: 'b',
                  getAttrs: node => node.style.fontWeight !== 'normal' && null,
              },
              {
                  style: 'font-weight=400',
                  clearMark: mark => mark.type.name === this.name,
              },
              {
                  style: 'font-weight',
                  getAttrs: value => /^(bold(er)?|[5-9]\d{2,})$/.test(value) && null,
              },
          ];
      },
      renderHTML({ HTMLAttributes }) {
          return ['strong', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addCommands() {
          return {
              setBold: () => ({ commands }) => {
                  return commands.setMark(this.name);
              },
              toggleBold: () => ({ commands }) => {
                  return commands.toggleMark(this.name);
              },
              unsetBold: () => ({ commands }) => {
                  return commands.unsetMark(this.name);
              },
          };
      },
      addKeyboardShortcuts() {
          return {
              'Mod-b': () => this.editor.commands.toggleBold(),
              'Mod-B': () => this.editor.commands.toggleBold(),
          };
      },
      addInputRules() {
          return [
              core.markInputRule({
                  find: starInputRegex,
                  type: this.type,
              }),
              core.markInputRule({
                  find: underscoreInputRegex,
                  type: this.type,
              }),
          ];
      },
      addPasteRules() {
          return [
              core.markPasteRule({
                  find: starPasteRegex,
                  type: this.type,
              }),
              core.markPasteRule({
                  find: underscorePasteRegex,
                  type: this.type,
              }),
          ];
      },
  });

  exports.Bold = Bold;
  exports.default = Bold;
  exports.starInputRegex = starInputRegex;
  exports.starPasteRegex = starPasteRegex;
  exports.underscoreInputRegex = underscoreInputRegex;
  exports.underscorePasteRegex = underscorePasteRegex;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
