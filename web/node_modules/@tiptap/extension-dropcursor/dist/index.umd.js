(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core'), require('@tiptap/pm/dropcursor')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core', '@tiptap/pm/dropcursor'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-dropcursor"] = {}, global.core, global.dropcursor));
})(this, (function (exports, core, dropcursor) { 'use strict';

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

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
