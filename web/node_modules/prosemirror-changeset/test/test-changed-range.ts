import ist from "ist"
import {schema, doc, p} from "prosemirror-test-builder"
import {Transform} from "prosemirror-transform"
import {Node} from "prosemirror-model"

import {ChangeSet} from "prosemirror-changeset"

function mk(doc: Node, change: (tr: Transform) => Transform): {doc0: Node, tr: Transform, data: any[], set0: ChangeSet, set: ChangeSet} {
  let tr = change(new Transform(doc))
  let data = new Array(tr.steps.length).fill("a")
  let set0 = ChangeSet.create(doc)
  return {doc0: doc, tr, data, set0,
          set: set0.addSteps(tr.doc, tr.mapping.maps, data)}
}

function same(a: any, b: any) {
  ist(JSON.stringify(a), JSON.stringify(b))
}

describe("ChangeSet.changedRange", () => {
  it("returns null for identical sets", () => {
    let {set, doc0, tr, data} = mk(doc(p("foo")), tr => tr
                                   .replaceWith(2, 3, schema.text("aaaa"))
                                   .replaceWith(1, 1, schema.text("xx"))
                                   .delete(5, 7))
    ist(set.changedRange(set), null)
    ist(set.changedRange(ChangeSet.create(doc0).addSteps(tr.doc, tr.mapping.maps, data)), null)
  })

  it("returns only the changed range in simple cases", () => {
    let {set0, set, tr} = mk(doc(p("abcd")), tr => tr.replaceWith(2, 4, schema.text("u")))
    same(set0.changedRange(set, tr.mapping.maps), {from: 2, to: 3})
  })

  it("expands to cover updated spans", () => {
    let {doc0, set0, set, tr} = mk(doc(p("abcd")), tr => tr
                                   .replaceWith(2, 2, schema.text("c"))
                                   .delete(3, 5))
    let set1 = ChangeSet.create(doc0).addSteps(tr.docs[1], [tr.mapping.maps[0]], ["a"])
    same(set0.changedRange(set1, [tr.mapping.maps[0]]), {from: 2, to: 3})
    same(set1.changedRange(set, [tr.mapping.maps[1]]), {from: 2, to: 3})
  })

  it("detects changes in deletions", () => {
    let {set} = mk(doc(p("abc")), tr => tr.delete(2, 3))
    same(set.changedRange(set.map(() => "b")), {from: 2, to: 2})
  })
})
