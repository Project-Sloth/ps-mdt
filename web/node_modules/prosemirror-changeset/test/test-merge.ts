import ist from "ist"
import {Change, Span} from "prosemirror-changeset"

describe("mergeChanges", () => {
  it("can merge simple insertions", () => test(
    [[1, 1, 1, 2]], [[1, 1, 1, 2]], [[1, 1, 1, 3]]
  ))

  it("can merge simple deletions", () => test(
    [[1, 2, 1, 1]], [[1, 2, 1, 1]], [[1, 3, 1, 1]]
  ))

  it("can merge insertion before deletion", () => test(
    [[2, 3, 2, 2]], [[1, 1, 1, 2]], [[1, 1, 1, 2], [2, 3, 3, 3]]
  ))

  it("can merge insertion after deletion", () => test(
    [[2, 3, 2, 2]], [[2, 2, 2, 3]], [[2, 3, 2, 3]]
  ))

  it("can merge deletion before insertion", () => test(
    [[2, 2, 2, 3]], [[1, 2, 1, 1]], [[1, 2, 1, 2]]
  ))

  it("can merge deletion after insertion", () => test(
    [[2, 2, 2, 3]], [[3, 4, 3, 3]], [[2, 3, 2, 3]]
  ))

  it("can merge deletion of insertion", () => test(
    [[2, 2, 2, 3]], [[2, 3, 2, 2]], []
  ))

  it("can merge insertion after replace", () => test(
    [[2, 3, 2, 3]], [[3, 3, 3, 4]], [[2, 3, 2, 4]]
  ))

  it("can merge insertion before replace", () => test(
    [[2, 3, 2, 3]], [[2, 2, 2, 3]], [[2, 3, 2, 4]]
  ))

  it("can merge replace after insert", () => test(
    [[2, 2, 2, 3]], [[2, 3, 2, 3]], [[2, 2, 2, 3]]
  ))
})

function range(array: number[], author = 0) {
  let [fromA, toA] = array
  let [fromB, toB] = array.length > 2 ? array.slice(2) : array
  return new Change(fromA, toA, fromB, toB, [new Span(toA - fromA, author)], [new Span(toB - fromB, author)])
}

function test(changeA: number[][], changeB: number[][], expected: number[][]) {
  const result = Change.merge(changeA.map(range), changeB.map(range), a => a)
    .map(r => [r.fromA, r.toA, r.fromB, r.toB])
  ist(JSON.stringify(result), JSON.stringify(expected))
}
