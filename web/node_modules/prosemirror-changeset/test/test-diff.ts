import ist from "ist"
import {doc, p, em, strong, h1, h2} from "prosemirror-test-builder"
import {Node} from "prosemirror-model"
import {Span, Change, ChangeSet} from "prosemirror-changeset"
const {computeDiff} = ChangeSet

describe("computeDiff", () => {
  function test(doc1: Node, doc2: Node, ...ranges: number[][]) {
    let diff = computeDiff(doc1.content, doc2.content,
                           new Change(0, doc1.content.size, 0, doc2.content.size,
                                      [new Span(doc1.content.size, 0)],
                                      [new Span(doc2.content.size, 0)]))
    ist(JSON.stringify(diff.map(r => [r.fromA, r.toA, r.fromB, r.toB])), JSON.stringify(ranges))
  }

  it("returns an empty diff for identical documents", () =>
     test(doc(p("foo"), p("bar")), doc(p("foo"), p("bar"))))

  it("finds single-letter changes", () =>
     test(doc(p("foo"), p("bar")), doc(p("foa"), p("bar")),
          [3, 4, 3, 4]))

  it("finds simple structure changes", () =>
     test(doc(p("foo"), p("bar")), doc(p("foobar")),
          [4, 6, 4, 4]))

  it("finds multiple changes", () =>
     test(doc(p("foo"), p("---bar")), doc(p("fgo"), p("---bur")),
          [2, 4, 2, 4], [10, 11, 10, 11]))

  it("ignores single-letter unchanged parts", () =>
     test(doc(p("abcdef")), doc(p("axydzf")), [2, 6, 2, 6]))

  it("ignores matching substrings in longer diffs", () =>
     test(doc(p("One two three")), doc(p("One"), p("And another long paragraph that has wo and ee in it")),
          [4, 14, 4, 57]))

  it("finds deletions", () =>
     test(doc(p("abc"), p("def")), doc(p("ac"), p("d")),
          [2, 3, 2, 2], [7, 9, 6, 6]))

  it("ignores marks", () =>
     test(doc(p("abc")), doc(p(em("a"), strong("bc")))))

  it("ignores marks in diffing", () =>
     test(doc(p("abcdefghi")), doc(p(em("x"), strong("bc"), "defgh", em("y"))),
          [1, 2, 1, 2], [9, 10, 9, 10]))

  it("ignores attributes", () =>
     test(doc(h1("x")), doc(h2("x"))))

  it("finds huge deletions", () => {
     let xs = "x".repeat(200), bs = "b".repeat(20)
     test(doc(p("a" + bs + "c")), doc(p("a" + xs + bs + xs + "c")),
          [2, 2, 2, 202], [22, 22, 222, 422])
  })

  it("finds huge insertions", () => {
     let xs = "x".repeat(200), bs = "b".repeat(20)
     test(doc(p("a" + xs + bs + xs + "c")), doc(p("a" + bs + "c")),
          [2, 202, 2, 2], [222, 422, 22, 22])
  })

  it("can handle ambiguous diffs", () =>
     test(doc(p("abcbcd")), doc(p("abcd")), [4, 6, 4, 4]))

  it("sees the difference between different closing tokens", () =>
     test(doc(p("a")), doc(h1("oo")), [0, 3, 0, 4]))
})
