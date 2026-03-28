// src/trailing-node-plugin.ts
import { Plugin, PluginKey } from "prosemirror-state";
var trailingNodePluginKey = new PluginKey("trailingNode");
function trailingNode(options) {
  const { ignoredNodes = [], nodeName = "paragraph" } = options != null ? options : {};
  const ignoredNodeNames = /* @__PURE__ */ new Set([...ignoredNodes, nodeName]);
  let type;
  let types;
  return new Plugin({
    key: trailingNodePluginKey,
    appendTransaction(_, __, state) {
      const { doc, tr } = state;
      const shouldInsertNodeAtEnd = trailingNodePluginKey.getState(state);
      const endPosition = doc.content.size;
      if (!shouldInsertNodeAtEnd) {
        return;
      }
      return tr.insert(endPosition, type.create());
    },
    state: {
      init: (_, { doc, schema }) => {
        var _a;
        const nodeType = schema.nodes[nodeName];
        if (!nodeType) {
          throw new Error("Invalid node being used for trailing node extension: '".concat(nodeName, "'"));
        }
        type = nodeType;
        types = Object.values(schema.nodes).map((node) => node).filter((node) => !ignoredNodeNames.has(node.name));
        return types.includes((_a = doc.lastChild) == null ? void 0 : _a.type);
      },
      apply: (tr, value) => {
        var _a;
        if (!tr.docChanged) {
          return value;
        }
        return types.includes((_a = tr.doc.lastChild) == null ? void 0 : _a.type);
      }
    }
  });
}
export {
  trailingNode
};
