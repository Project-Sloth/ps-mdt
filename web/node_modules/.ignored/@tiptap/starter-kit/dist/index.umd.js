(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core'), require('@tiptap/extension-blockquote'), require('@tiptap/extension-bold'), require('@tiptap/extension-bullet-list'), require('@tiptap/extension-code'), require('@tiptap/extension-code-block'), require('@tiptap/extension-document'), require('@tiptap/extension-dropcursor'), require('@tiptap/extension-gapcursor'), require('@tiptap/extension-hard-break'), require('@tiptap/extension-heading'), require('@tiptap/extension-history'), require('@tiptap/extension-horizontal-rule'), require('@tiptap/extension-italic'), require('@tiptap/extension-list-item'), require('@tiptap/extension-ordered-list'), require('@tiptap/extension-paragraph'), require('@tiptap/extension-strike'), require('@tiptap/extension-text')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core', '@tiptap/extension-blockquote', '@tiptap/extension-bold', '@tiptap/extension-bullet-list', '@tiptap/extension-code', '@tiptap/extension-code-block', '@tiptap/extension-document', '@tiptap/extension-dropcursor', '@tiptap/extension-gapcursor', '@tiptap/extension-hard-break', '@tiptap/extension-heading', '@tiptap/extension-history', '@tiptap/extension-horizontal-rule', '@tiptap/extension-italic', '@tiptap/extension-list-item', '@tiptap/extension-ordered-list', '@tiptap/extension-paragraph', '@tiptap/extension-strike', '@tiptap/extension-text'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/starter-kit"] = {}, global.core, global.extensionBlockquote, global.extensionBold, global.extensionBulletList, global.extensionCode, global.extensionCodeBlock, global.extensionDocument, global.extensionDropcursor, global.extensionGapcursor, global.extensionHardBreak, global.extensionHeading, global.extensionHistory, global.extensionHorizontalRule, global.extensionItalic, global.extensionListItem, global.extensionOrderedList, global.extensionParagraph, global.extensionStrike, global.extensionText));
})(this, (function (exports, core, extensionBlockquote, extensionBold, extensionBulletList, extensionCode, extensionCodeBlock, extensionDocument, extensionDropcursor, extensionGapcursor, extensionHardBreak, extensionHeading, extensionHistory, extensionHorizontalRule, extensionItalic, extensionListItem, extensionOrderedList, extensionParagraph, extensionStrike, extensionText) { 'use strict';

  /**
   * The starter kit is a collection of essential editor extensions.
   *
   * It’s a good starting point for building your own editor.
   */
  const StarterKit = core.Extension.create({
      name: 'starterKit',
      addExtensions() {
          const extensions = [];
          if (this.options.bold !== false) {
              extensions.push(extensionBold.Bold.configure(this.options.bold));
          }
          if (this.options.blockquote !== false) {
              extensions.push(extensionBlockquote.Blockquote.configure(this.options.blockquote));
          }
          if (this.options.bulletList !== false) {
              extensions.push(extensionBulletList.BulletList.configure(this.options.bulletList));
          }
          if (this.options.code !== false) {
              extensions.push(extensionCode.Code.configure(this.options.code));
          }
          if (this.options.codeBlock !== false) {
              extensions.push(extensionCodeBlock.CodeBlock.configure(this.options.codeBlock));
          }
          if (this.options.document !== false) {
              extensions.push(extensionDocument.Document.configure(this.options.document));
          }
          if (this.options.dropcursor !== false) {
              extensions.push(extensionDropcursor.Dropcursor.configure(this.options.dropcursor));
          }
          if (this.options.gapcursor !== false) {
              extensions.push(extensionGapcursor.Gapcursor.configure(this.options.gapcursor));
          }
          if (this.options.hardBreak !== false) {
              extensions.push(extensionHardBreak.HardBreak.configure(this.options.hardBreak));
          }
          if (this.options.heading !== false) {
              extensions.push(extensionHeading.Heading.configure(this.options.heading));
          }
          if (this.options.history !== false) {
              extensions.push(extensionHistory.History.configure(this.options.history));
          }
          if (this.options.horizontalRule !== false) {
              extensions.push(extensionHorizontalRule.HorizontalRule.configure(this.options.horizontalRule));
          }
          if (this.options.italic !== false) {
              extensions.push(extensionItalic.Italic.configure(this.options.italic));
          }
          if (this.options.listItem !== false) {
              extensions.push(extensionListItem.ListItem.configure(this.options.listItem));
          }
          if (this.options.orderedList !== false) {
              extensions.push(extensionOrderedList.OrderedList.configure(this.options.orderedList));
          }
          if (this.options.paragraph !== false) {
              extensions.push(extensionParagraph.Paragraph.configure(this.options.paragraph));
          }
          if (this.options.strike !== false) {
              extensions.push(extensionStrike.Strike.configure(this.options.strike));
          }
          if (this.options.text !== false) {
              extensions.push(extensionText.Text.configure(this.options.text));
          }
          return extensions;
      },
  });

  exports.StarterKit = StarterKit;
  exports.default = StarterKit;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
