'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');

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
//# sourceMappingURL=index.cjs.map
