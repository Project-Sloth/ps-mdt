(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core'), require('@tiptap/pm/gapcursor')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core', '@tiptap/pm/gapcursor'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-gapcursor"] = {}, global.core, global.gapcursor));
})(this, (function (exports, core, gapcursor) { 'use strict';

  /**
   * This extension allows you to add a gap cursor to your editor.
   * A gap cursor is a cursor that appears when you click on a place
   * where no content is present, for example inbetween nodes.
   * @see https://tiptap.dev/api/extensions/gapcursor
   */
  const Gapcursor = core.Extension.create({
      name: 'gapCursor',
      addProseMirrorPlugins() {
          return [
              gapcursor.gapCursor(),
          ];
      },
      extendNodeSchema(extension) {
          var _a;
          const context = {
              name: extension.name,
              options: extension.options,
              storage: extension.storage,
          };
          return {
              allowGapCursor: (_a = core.callOrReturn(core.getExtensionField(extension, 'allowGapCursor', context))) !== null && _a !== void 0 ? _a : null,
          };
      },
  });

  exports.Gapcursor = Gapcursor;
  exports.default = Gapcursor;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
