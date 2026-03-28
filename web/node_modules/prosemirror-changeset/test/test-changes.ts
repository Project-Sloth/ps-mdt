import ist from "ist"
import {schema, doc, p, blockquote, h1} from "prosemirror-test-builder"
import {Transform} from "prosemirror-transform"
import {Node} from "prosemirror-model"

import {ChangeSet} from "prosemirror-changeset"

describe("ChangeSet", () => {
  it("finds a single insertion",
     find(doc(p("hello")), tr => tr.insert(3, t("XY")), [[3, 3, 3, 5]]))

  it("finds a single deletion",
     find(doc(p("hello")), tr => tr.delete(3, 5), [[3, 5, 3, 3]]))

  it("identifies a replacement",
     find(doc(p("hello")), tr => tr.replaceWith(3, 5, t("juj")),
          [[3, 5, 3, 6]]))

  it("merges adjacent canceling edits",
     find(doc(p("hello")),
          tr => tr.delete(3, 5).insert(3, t("ll")),
          []))

  it("doesn't crash when cancelling edits are followed by others",
     find(doc(p("hello")),
          tr => tr.delete(2, 3).insert(2, t("e")).delete(5, 6),
          [[5, 6, 5, 5]]))

  it("stops handling an inserted span after collapsing it",
     find(doc(p("abcba")), tr => tr.insert(2, t("b")).insert(6, t("b")).delete(3, 6),
          [[3, 4, 3, 3]]))

  it("partially merges insert at start",
     find(doc(p("helLo")), tr => tr.delete(3, 5).insert(3, t("l")),
          [[4, 5, 4, 4]]))

  it("partially merges insert at end",
     find(doc(p("helLo")), tr => tr.delete(3, 5).insert(3, t("L")),
          [[3, 4, 3, 3]]))

  it("partially merges delete at start",
     find(doc(p("abc")), tr => tr.insert(3, t("xyz")).delete(3, 4),
          [[3, 3, 3, 5]]))

  it("partially merges delete at end",
     find(doc(p("abc")), tr => tr.insert(3, t("xyz")).delete(5, 6),
          [[3, 3, 3, 5]]))

  it("finds multiple insertions",
     find(doc(p("abc")), tr => tr.insert(1, t("x")).insert(5, t("y")),
          [[1, 1, 1, 2], [4, 4, 5, 6]]))

  it("finds multiple deletions",
     find(doc(p("xyz")), tr => tr.delete(1, 2).delete(2, 3),
          [[1, 2, 1, 1], [3, 4, 2, 2]]))

  it("identifies a deletion between insertions",
     find(doc(p("zyz")), tr => tr.insert(2, t("A")).insert(4, t("B")).delete(3, 4),
          [[2, 3, 2, 4]]))

  it("can add a deletion in a new addStep call", find(doc(p("hello")), [
    tr => tr.delete(1, 2),
    tr => tr.delete(2, 3)
  ], [[1, 2, 1, 1], [3, 4, 2, 2]]))

  it("merges delete/insert from different addStep calls", find(doc(p("hello")), [
    tr => tr.delete(3, 5),
    tr => tr.insert(3, t("ll"))
  ], []))

  it("revert a deletion by inserting the character again", find(doc(p("bar")), [
    tr => tr.delete(2, 3), // br
    tr => tr.insert(2, t("x")), // bxr
    tr => tr.insert(2, t("a")) // baxr
  ], [[3, 3, 3, 4]]))

  it("insert character before changed character", find(doc(p("bar")), [
    tr => tr.delete(2, 3), // br
    tr => tr.insert(2, t("x")), // bxr
    tr => tr.insert(2, t("x")) // bxxr
  ], [[2, 3, 2, 4]]))

  it("partially merges delete/insert from different addStep calls", find(doc(p("heljo")), [
    tr => tr.delete(3, 5),
    tr => tr.insert(3, t("ll"))
  ], [[4, 5, 4, 5]]))

  it("merges insert/delete from different addStep calls", find(doc(p("ok")), [
    tr => tr.insert(2, t("--")),
    tr => tr.delete(2, 4)
  ], []))

  it("partially merges insert/delete from different addStep calls", find(doc(p("ok")), [
    tr => tr.insert(2, t("--")),
    tr => tr.delete(2, 3)
  ], [[2, 2, 2, 3]]))

  it("maps deletions forward", find(doc(p("foobar")), [
    tr => tr.delete(5, 6),
    tr => tr.insert(1, t("OKAY"))
  ], [[1, 1, 1, 5], [5, 6, 9, 9]]))

  it("can incrementally undo then redo", find(doc(p("bar")), [
    tr => tr.delete(2, 3),
    tr => tr.insert(2, t("a")),
    tr => tr.delete(2, 3)
  ], [[2, 3, 2, 2]]))

  it("can map through complicated changesets", find(doc(p("12345678901234")), [
    tr => tr.delete(9, 12).insert(6, t("xyz")).replaceWith(2, 3, t("uv")),
    tr => tr.delete(14, 15).insert(13, t("90")).delete(8, 9)
  ], [[2, 3, 2, 4], [6, 6, 7, 9], [11, 12, 14, 14], [13, 14, 15, 15]]))

  it("computes a proper diff of the changes",
     find(doc(p("abcd"), p("efgh")), tr => tr.delete(2, 10).insert(2, t("cdef")),
          [[2, 3, 2, 2], [5, 7, 4, 4], [9, 10, 6, 6]]))

  it("handles re-adding content step by step", find(doc(p("one two three")), [
    tr => tr.delete(1, 14),
    tr => tr.insert(1, t("two")),
    tr => tr.insert(4, t(" ")),
    tr => tr.insert(5, t("three"))
  ], [[1, 5, 1, 1]]))

  it("doesn't get confused by split deletions", find(doc(blockquote(h1("one"), p("two four"))), [
    tr => tr.delete(7, 11),
    tr => tr.replaceWith(0, 13, blockquote(h1("one"), p("four")))
  ], [[7, 11, 7, 7, [[4, 0]], []]], true))

  it("doesn't get confused by multiply split deletions", find(doc(blockquote(h1("one"), p("two three"))), [
    tr => tr.delete(14, 16),
    tr => tr.delete(7, 11),
    tr => tr.delete(3, 5),
    tr => tr.replaceWith(0, 10, blockquote(h1("o"), p("thr")))
  ], [[3, 5, 3, 3, [[2, 2]], []], [8, 12, 6, 6, [[3, 1], [1, 3]], []],
      [14, 16, 8, 8, [[2, 0]], []]], true))

  it("won't lose the order of overlapping changes", find(doc(p("12345")), [
    tr => tr.delete(4, 5),
    tr => tr.replaceWith(2, 2, t("a")),
    tr => tr.delete(1, 6),
    tr => tr.replaceWith(1, 1, t("1a235"))
  ], [[2, 2, 2, 3, [], [[1, 1]]], [4, 5, 5, 5, [[1, 0]], []]], [0, 0, 1, 1]))

  it("properly maps deleted positions", find(doc(p("jTKqvPrzApX")), [
    tr => tr.delete(8, 11),
    tr => tr.replaceWith(1, 1, t("MPu")),
    tr => tr.delete(2, 12),
    tr => tr.replaceWith(2, 2, t("PujTKqvPrX"))
  ], [[1, 1, 1, 4, [], [[3, 2]]], [8, 11, 11, 11, [[3, 1]], []]], [1, 2, 2, 2]))

  it("fuzz issue 1", find(doc(p("hzwiKqBPzn")), [
    tr => tr.delete(3, 7),
    tr => tr.replaceWith(5, 5, t("LH")),
    tr => tr.replaceWith(6, 6, t("uE")),
    tr => tr.delete(1, 6),
    tr => tr.delete(3, 6)
  ], [[1, 11, 1, 3, [[2, 1], [4, 0], [2, 1], [2, 0]], [[2, 0]]]], [0, 1, 0, 1, 0]))

  it("fuzz issue 2", find(doc(p("eAMISWgauf")), [
    tr => tr.delete(5, 10),
    tr => tr.replaceWith(5, 5, t("KkM")),
    tr => tr.replaceWith(3, 3, t("UDO")),
    tr => tr.delete(1, 12),
    tr => tr.replaceWith(1, 1, t("eAUDOMIKkMf")),
    tr => tr.delete(5, 8),
    tr => tr.replaceWith(3, 3, t("qX"))
  ], [[3, 10, 3, 10, [[2, 0], [5, 2]], [[7, 0]]]], [2, 0, 0, 0, 0, 0, 0]))

  it("fuzz issue 3", find(doc(p("hfxjahnOuH")), [
    tr => tr.delete(1, 5),
    tr => tr.replaceWith(3, 3, t("X")),
    tr => tr.delete(1, 8),
    tr => tr.replaceWith(1, 1, t("ahXnOuH")),
    tr => tr.delete(2, 4),
    tr => tr.replaceWith(2, 2, t("tn")),
    tr => tr.delete(5, 7),
    tr => tr.delete(1, 6),
    tr => tr.replaceWith(1, 1, t("atnnH")),
    tr => tr.delete(2, 6)
  ], [[1, 11, 1, 2, [[4, 1], [1, 0], [1, 1], [1, 0], [2, 1], [1, 0]], [[1, 0]]]], [1, 0, 1, 1, 1, 1, 1, 0, 0, 0]))

  it("correctly handles steps with multiple map entries", find(doc(p()), [
    tr => tr.replaceWith(1, 1, t("ab")),
    tr => tr.wrap(tr.doc.resolve(1).blockRange()!, [{type: schema.nodes.blockquote}])
  ], [[0, 0, 0, 1], [1, 1, 2, 4], [2, 2, 5, 6]]))
})

function find(doc: Node, build: ((tr: Transform) => void) | ((tr: Transform) => void)[],
              changes: any[], sep?: number[] | boolean) {
  return () => {
    let set = ChangeSet.create(doc), curDoc = doc
    if (!Array.isArray(build)) build = [build]
    build.forEach((build, i) => {
      let tr = new Transform(curDoc)
      build(tr)
      set = set.addSteps(tr.doc, tr.mapping.maps, !sep ? 0 : Array.isArray(sep) ? sep[i] : i)
      curDoc = tr.doc
    })

    let owner = sep && changes.length && changes[0].length > 4
    ist(JSON.stringify(set.changes.map(ch => {
      let range: any[] = [ch.fromA, ch.toA, ch.fromB, ch.toB]
      if (owner) range.push(ch.deleted.map(d => [d.length, d.data]),
                            ch.inserted.map(d => [d.length, d.data]))
      return range
    })), JSON.stringify(changes))
  }
}

function t(str: string) { return schema.text(str) }
