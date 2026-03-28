(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-text"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * This extension allows you to create text nodes.
   * @see https://www.tiptap.dev/api/nodes/text
   */
  const Text = core.Node.create({
      name: 'text',
      group: 'inline',
  });

  exports.Text = Text;
  exports.default = Text;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
