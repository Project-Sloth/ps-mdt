import ist from "ist"
import {doc, p, img} from "prosemirror-test-builder"
import {Node} from "prosemirror-model"
import {simplifyChanges, Change, Span} from "prosemirror-changeset"

describe("simplifyChanges", () => {
  it("doesn't change insertion-only changes", () => test(
    [[1, 1, 1, 2], [2, 2, 3, 4]], doc(p("hello")), [[1, 1, 1, 2], [2, 2, 3, 4]]))

  it("doesn't change deletion-only changes", () => test(
    [[1, 2, 1, 1], [3, 4, 2, 2]], doc(p("hello")), [[1, 2, 1, 1], [3, 4, 2, 2]]))

  it("doesn't change single-letter-replacements", () => test(
    [[1, 2, 1, 2]], doc(p("hello")), [[1, 2, 1, 2]]))

  it("does expand multiple-letter replacements", () => test(
    [[2, 4, 2, 4]], doc(p("hello")), [[1, 6, 1, 6]]))

  it("does combine changes within the same word", () => test(
    [[1, 3, 1, 1], [5, 5, 3, 4]], doc(p("hello")), [[1, 7, 1, 6]]))

  it("expands changes to cover full words", () => test(
    [[7, 10]], doc(p("one two three four")), [[5, 14]]))

  it("doesn't expand across non-word text", () => test(
    [[7, 10]], doc(p("one two ----- four")), [[5, 10]]))

  it("treats leaf nodes as non-words", () => test(
    [[2, 3], [6, 7]], doc(p("one", img(), "two")), [[2, 3], [6, 7]]))

  it("treats node boundaries as non-words", () => test(
    [[2, 3], [7, 8]], doc(p("one"), p("two")), [[2, 3], [7, 8]]))

  it("can merge stretches of changes", () => test(
    [[2, 3], [4, 6], [8, 10], [15, 16]], doc(p("foo bar baz bug ugh")), [[1, 12], [15, 16]]))

  it("handles realistic word updates", () => test(
    [[8, 8, 8, 11], [10, 15, 13, 17]], doc(p("chonic condition")), [[8, 15, 8, 17]]))

  it("works when after significant content", () => test(
    [[63, 80, 63, 83]], doc(p("one long paragraph -----"), p("two long paragraphs ------"), p("a vote against the government")),
    [[62, 81, 62, 84]]))

  it("joins changes that grow together when simplifying", () => test(
    [[1, 5, 1, 5], [7, 13, 7, 9], [20, 21, 16, 16]], doc(p('and his co-star')),
    [[1, 13, 1, 9], [20, 21, 16, 16]]))

  it("properly fills in metadata", () => {
    let simple = simplifyChanges([range([2, 3], 0), range([4, 6], 1), range([8, 9, 8, 8], 2)],
                                 doc(p("1234567890")))
    ist(simple.length, 1)
    ist(JSON.stringify(simple[0].deleted.map(s => [s.length, s.data])),
        JSON.stringify([[3, 0], [4, 1], [4, 2]]))
    ist(JSON.stringify(simple[0].inserted.map(s => [s.length, s.data])),
        JSON.stringify([[3, 0], [4, 1], [3, 2]]))
  })
})

function range(array: number[], author = 0) {
  let [fromA, toA] = array
  let [fromB, toB] = array.length > 2 ? array.slice(2) : array
  return new Change(fromA, toA, fromB, toB, [new Span(toA - fromA, author)], [new Span(toB - fromB, author)])
}

function test(changes: number[][], doc: Node, result: number[][]) {
  let ranges = changes.map(range)
  ist(JSON.stringify(simplifyChanges(ranges, doc).map((r, i) => {
    if (result[i] && result[i].length > 2) return [r.fromA, r.toA, r.fromB, r.toB]
    else return [r.fromB, r.toB]
  })), JSON.stringify(result))
}
