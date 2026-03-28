(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-document"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * The default document node which represents the top level node of the editor.
   * @see https://tiptap.dev/api/nodes/document
   */
  const Document = core.Node.create({
      name: 'doc',
      topNode: true,
      content: 'block+',
  });

  exports.Document = Document;
  exports.default = Document;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
