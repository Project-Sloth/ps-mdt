(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-heading"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * This extension allows you to create headings.
   * @see https://www.tiptap.dev/api/nodes/heading
   */
  const Heading = core.Node.create({
      name: 'heading',
      addOptions() {
          return {
              levels: [1, 2, 3, 4, 5, 6],
              HTMLAttributes: {},
          };
      },
      content: 'inline*',
      group: 'block',
      defining: true,
      addAttributes() {
          return {
              level: {
                  default: 1,
                  rendered: false,
              },
          };
      },
      parseHTML() {
          return this.options.levels
              .map((level) => ({
              tag: `h${level}`,
              attrs: { level },
          }));
      },
      renderHTML({ node, HTMLAttributes }) {
          const hasLevel = this.options.levels.includes(node.attrs.level);
          const level = hasLevel
              ? node.attrs.level
              : this.options.levels[0];
          return [`h${level}`, core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addCommands() {
          return {
              setHeading: attributes => ({ commands }) => {
                  if (!this.options.levels.includes(attributes.level)) {
                      return false;
                  }
                  return commands.setNode(this.name, attributes);
              },
              toggleHeading: attributes => ({ commands }) => {
                  if (!this.options.levels.includes(attributes.level)) {
                      return false;
                  }
                  return commands.toggleNode(this.name, 'paragraph', attributes);
              },
          };
      },
      addKeyboardShortcuts() {
          return this.options.levels.reduce((items, level) => ({
              ...items,
              ...{
                  [`Mod-Alt-${level}`]: () => this.editor.commands.toggleHeading({ level }),
              },
          }), {});
      },
      addInputRules() {
          return this.options.levels.map(level => {
              return core.textblockTypeInputRule({
                  find: new RegExp(`^(#{${Math.min(...this.options.levels)},${level}})\\s$`),
                  type: this.type,
                  getAttributes: {
                      level,
                  },
              });
          });
      },
  });

  exports.Heading = Heading;
  exports.default = Heading;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
