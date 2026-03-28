import {Fragment, Node} from "prosemirror-model"
import {Span, Change} from "./change"

let letter: RegExp | undefined
// If the runtime support unicode properties in regexps, that's a good
// source of info on whether something is a letter.
try { letter = new RegExp("[\\p{Alphabetic}_]", "u") } catch(_) {}

// Otherwise, we see if the character changes when upper/lowercased,
// or if it is part of these common single-case scripts.
const nonASCIISingleCaseWordChar = /[\u00df\u0587\u0590-\u05f4\u0600-\u06ff\u3040-\u309f\u30a0-\u30ff\u3400-\u4db5\u4e00-\u9fcc\uac00-\ud7af]/

function isLetter(code: number) {
  if (code < 128)
    return code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 79 && code <= 122
  let ch = String.fromCharCode(code)
  if (letter) return letter.test(ch)
  return ch.toUpperCase() != ch.toLowerCase() || nonASCIISingleCaseWordChar.test(ch)
}

// Convert a range of document into a string, so that we can easily
// access characters at a given position. Treat non-text tokens as
// spaces so that they aren't considered part of a word.
function getText(frag: Fragment, start: number, end: number) {
  let out = ""
  function convert(frag: Fragment, start: number, end: number) {
    for (let i = 0, off = 0; i < frag.childCount; i++) {
      let child = frag.child(i), endOff = off + child.nodeSize
      let from = Math.max(off, start), to = Math.min(endOff, end)
      if (from < to) {
        if (child.isText) {
          out += child.text!.slice(Math.max(0, start - off), Math.min(child.text!.length, end - off))
        } else if (child.isLeaf) {
          out += " "
        } else {
          if (from == off) out += " "
          convert(child.content, Math.max(0, from - off - 1), Math.min(child.content.size, end - off))
          if (to == endOff) out += " "
        }
      }
      off = endOff
    }
  }
  convert(frag, start, end)
  return out
}

// The distance changes have to be apart for us to not consider them
// candidates for merging.
const MAX_SIMPLIFY_DISTANCE = 30

/// Simplifies a set of changes for presentation. This makes the
/// assumption that having both insertions and deletions within a word
/// is confusing, and, when such changes occur without a word boundary
/// between them, they should be expanded to cover the entire set of
/// words (in the new document) they touch. An exception is made for
/// single-character replacements.
export function simplifyChanges(changes: readonly Change[], doc: Node) {
  let result: Change[] = []
  for (let i = 0; i < changes.length; i++) {
    let end = changes[i].toB, start = i
    while (i < changes.length - 1 && changes[i + 1].fromB <= end + MAX_SIMPLIFY_DISTANCE)
      end = changes[++i].toB
    simplifyAdjacentChanges(changes, start, i + 1, doc, result)
  }
  return result
}

function simplifyAdjacentChanges(changes: readonly Change[], from: number, to: number, doc: Node, target: Change[]) {
  let start = Math.max(0, changes[from].fromB - MAX_SIMPLIFY_DISTANCE)
  let end = Math.min(doc.content.size, changes[to - 1].toB + MAX_SIMPLIFY_DISTANCE)
  let text = getText(doc.content, start, end)

  for (let i = from; i < to; i++) {
    let startI = i, last = changes[i], deleted = last.lenA, inserted = last.lenB
    while (i < to - 1) {
      let next = changes[i + 1], boundary = false
      let prevLetter = last.toB == end ? false : isLetter(text.charCodeAt(last.toB - 1 - start))
      for (let pos = last.toB; !boundary && pos < next.fromB; pos++) {
        let nextLetter = pos == end ? false : isLetter(text.charCodeAt(pos - start))
        if ((!prevLetter || !nextLetter) && pos != changes[startI].fromB) boundary = true
        prevLetter = nextLetter
      }
      if (boundary) break
      deleted += next.lenA; inserted += next.lenB
      last = next
      i++
    }

    if (inserted > 0 && deleted > 0 && !(inserted == 1 && deleted == 1)) {
      let from = changes[startI].fromB, to = changes[i].toB
      if (from < end && isLetter(text.charCodeAt(from - start)))
        while (from > start && isLetter(text.charCodeAt(from - 1 - start))) from--
      if (to > start && isLetter(text.charCodeAt(to - 1 - start)))
        while (to < end && isLetter(text.charCodeAt(to - start))) to++
      let joined = fillChange(changes.slice(startI, i + 1), from, to)
      let last = target.length ? target[target.length - 1] : null
      if (last && last.toA == joined.fromA)
        target[target.length - 1] = new Change(last.fromA, joined.toA, last.fromB, joined.toB,
                                               last.deleted.concat(joined.deleted), last.inserted.concat(joined.inserted))
      else
        target.push(joined)
    } else {
      for (let j = startI; j <= i; j++) target.push(changes[j])
    }
  }
  return changes
}

function combine<T>(a: T, b: T): T { return a === b ? a : null as any }

function fillChange(changes: readonly Change[], fromB: number, toB: number) {
  let fromA = changes[0].fromA - (changes[0].fromB - fromB)
  let last = changes[changes.length - 1]
  let toA = last.toA + (toB - last.toB)
  let deleted = Span.none, inserted = Span.none
  let delData = (changes[0].deleted.length ? changes[0].deleted : changes[0].inserted)[0].data
  let insData = (changes[0].inserted.length ? changes[0].inserted : changes[0].deleted)[0].data
  for (let posA = fromA, posB = fromB, i = 0;; i++) {
    let next = i == changes.length ? null : changes[i]
    let endA = next ? next.fromA : toA, endB = next ? next.fromB : toB
    if (endA > posA) deleted = Span.join(deleted, [new Span(endA - posA, delData)], combine)
    if (endB > posB) inserted = Span.join(inserted, [new Span(endB - posB, insData)], combine)
    if (!next) break
    deleted = Span.join(deleted, next.deleted, combine)
    inserted = Span.join(inserted, next.inserted, combine)
    if (deleted.length) delData = deleted[deleted.length - 1].data
    if (inserted.length) insData = inserted[inserted.length - 1].data
    posA = next.toA; posB = next.toB
  }
  return new Change(fromA, toA, fromB, toB, deleted, inserted)
}
