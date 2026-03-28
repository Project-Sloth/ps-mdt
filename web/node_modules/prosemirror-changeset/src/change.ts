/// Stores metadata for a part of a change.
export class Span<Data = any> {
  /// @internal
  constructor(
    /// The length of this span.
    readonly length: number,
    /// The data associated with this span.
    readonly data: Data
  ) {}

  /// @internal
  cut(length: number) {
    return length == this.length ? this : new Span(length, this.data)
  }

  /// @internal
  static slice(spans: readonly Span[], from: number, to: number) {
    if (from == to) return Span.none
    if (from == 0 && to == Span.len(spans)) return spans
    let result = []
    for (let i = 0, off = 0; off < to; i++) {
      let span = spans[i], end = off + span.length
      let overlap = Math.min(to, end) - Math.max(from, off)
      if (overlap > 0) result.push(span.cut(overlap))
      off = end
    }
    return result
  }

  /// @internal
  static join<Data>(a: readonly Span<Data>[], b: readonly Span<Data>[], combine: (dataA: Data, dataB: Data) => Data) {
    if (a.length == 0) return b
    if (b.length == 0) return a
    let combined = combine(a[a.length - 1].data, b[0].data)
    if (combined == null) return a.concat(b)
    let result = a.slice(0, a.length - 1)
    result.push(new Span(a[a.length - 1].length + b[0].length, combined))
    for (let i = 1; i < b.length; i++) result.push(b[i])
    return result
  }

  /// @internal
  static len(spans: readonly Span[]) {
    let len = 0
    for (let i = 0; i < spans.length; i++) len += spans[i].length
    return len
  }

  /// @internal
  static none: readonly Span[] = []
}

/// A replaced range with metadata associated with it.
export class Change<Data = any> {
  /// @internal
  constructor(
    /// The start of the range deleted/replaced in the old document.
    readonly fromA: number,
    /// The end of the range in the old document.
    readonly toA: number,
    /// The start of the range inserted in the new document.
    readonly fromB: number,
    /// The end of the range in the new document.
    readonly toB: number,
    /// Data associated with the deleted content. The length of these
    /// spans adds up to `this.toA - this.fromA`.
    readonly deleted: readonly Span<Data>[],
    /// Data associated with the inserted content. Length adds up to
    /// `this.toB - this.fromB`.
    readonly inserted: readonly Span<Data>[]
  ) {}

  /// @internal
  get lenA() { return this.toA - this.fromA }
  /// @internal
  get lenB() { return this.toB - this.fromB }

  /// @internal
  slice(startA: number, endA: number, startB: number, endB: number): Change<Data> {
    if (startA == 0 && startB == 0 && endA == this.toA - this.fromA &&
        endB == this.toB - this.fromB) return this
    return new Change(this.fromA + startA, this.fromA + endA,
                      this.fromB + startB, this.fromB + endB,
                      Span.slice(this.deleted, startA, endA),
                      Span.slice(this.inserted, startB, endB))
  }

  /// This merges two changesets (the end document of x should be the
  /// start document of y) into a single one spanning the start of x to
  /// the end of y.
  static merge<Data>(x: readonly Change<Data>[],
                     y: readonly Change<Data>[],
                     combine: (dataA: Data, dataB: Data) => Data): readonly Change<Data>[] {
    if (x.length == 0) return y
    if (y.length == 0) return x

    let result = []
    // Iterate over both sets in parallel, using the middle coordinate
    // system (B in x, A in y) to synchronize.
    for (let iX = 0, iY = 0, curX: Change<Data> | null = x[0], curY: Change<Data> | null = y[0];;) {
      if (!curX && !curY) {
        return result
      } else if (curX && (!curY || curX.toB < curY.fromA)) { // curX entirely in front of curY
        let off = iY ? y[iY - 1].toB - y[iY - 1].toA : 0
        result.push(off == 0 ? curX :
                    new Change(curX.fromA, curX.toA, curX.fromB + off, curX.toB + off,
                               curX.deleted, curX.inserted))
        curX = iX++ == x.length ? null : x[iX]
      } else if (curY && (!curX || curY.toA < curX.fromB)) { // curY entirely in front of curX
        let off = iX ? x[iX - 1].toB - x[iX - 1].toA : 0
        result.push(off == 0 ? curY :
                    new Change(curY.fromA - off, curY.toA - off, curY.fromB, curY.toB,
                               curY.deleted, curY.inserted))
        curY = iY++ == y.length ? null : y[iY]
      } else { // Touch, need to merge
        // The rules for merging ranges are that deletions from the
        // old set and insertions from the new are kept. Areas of the
        // middle document covered by a but not by b are insertions
        // from a that need to be added, and areas covered by b but
        // not a are deletions from b that need to be added.
        let pos = Math.min(curX!.fromB, curY!.fromA)
        let fromA = Math.min(curX!.fromA, curY!.fromA - (iX ? x[iX - 1].toB - x[iX - 1].toA : 0)), toA = fromA
        let fromB = Math.min(curY!.fromB, curX!.fromB + (iY ? y[iY - 1].toB - y[iY - 1].toA : 0)), toB = fromB
        let deleted = Span.none, inserted = Span.none

        // Used to prevent appending ins/del range for the same Change twice
        let enteredX = false, enteredY = false

        // Need to have an inner loop since any number of further
        // ranges might be touching this group
        for (;;) {
          let nextX = !curX ? 2e8 : pos >= curX.fromB ? curX.toB : curX.fromB
          let nextY = !curY ? 2e8 : pos >= curY.fromA ? curY.toA : curY.fromA
          let next = Math.min(nextX, nextY)
          let inX = curX && pos >= curX.fromB, inY = curY && pos >= curY.fromA
          if (!inX && !inY) break
          if (inX && pos == curX!.fromB && !enteredX) {
            deleted = Span.join(deleted, curX!.deleted, combine)
            toA += curX!.lenA
            enteredX = true
          }
          if (inX && !inY) {
            inserted = Span.join(inserted, Span.slice(curX!.inserted, pos - curX!.fromB, next - curX!.fromB), combine)
            toB += next - pos
          }
          if (inY && pos == curY!.fromA && !enteredY) {
            inserted = Span.join(inserted, curY!.inserted, combine)
            toB += curY!.lenB
            enteredY = true
          }
          if (inY && !inX) {
            deleted = Span.join(deleted, Span.slice(curY!.deleted, pos - curY!.fromA, next - curY!.fromA), combine)
            toA += next - pos
          }

          if (inX && next == curX!.toB) {
            curX = iX++ == x.length ? null : x[iX]
            enteredX = false
          }
          if (inY && next == curY!.toA) {
            curY = iY++ == y.length ? null : y[iY]
            enteredY = false
          }
          pos = next
        }
        if (fromA < toA || fromB < toB)
          result.push(new Change(fromA, toA, fromB, toB, deleted, inserted))
      }
    }
  }
}
