function typeID(type) {
    let cache = type.schema.cached.changeSetIDs || (type.schema.cached.changeSetIDs = Object.create(null));
    let id = cache[type.name];
    if (id == null)
        cache[type.name] = id = Object.keys(type.schema.nodes).indexOf(type.name) + 1;
    return id;
}
// The default token encoder, which encodes node open tokens are
// encoded as strings holding the node name, characters as their
// character code, and node close tokens as negative numbers.
const DefaultEncoder = {
    encodeCharacter: char => char,
    encodeNodeStart: node => node.type.name,
    encodeNodeEnd: node => -typeID(node.type),
    compareTokens: (a, b) => a === b
};
// Convert the given range of a fragment to tokens.
function tokens(frag, encoder, start, end, target) {
    for (let i = 0, off = 0; i < frag.childCount; i++) {
        let child = frag.child(i), endOff = off + child.nodeSize;
        let from = Math.max(off, start), to = Math.min(endOff, end);
        if (from < to) {
            if (child.isText) {
                for (let j = from; j < to; j++)
                    target.push(encoder.encodeCharacter(child.text.charCodeAt(j - off), child.marks));
            }
            else if (child.isLeaf) {
                target.push(encoder.encodeNodeStart(child));
            }
            else {
                if (from == off)
                    target.push(encoder.encodeNodeStart(child));
                tokens(child.content, encoder, Math.max(off + 1, from) - off - 1, Math.min(endOff - 1, to) - off - 1, target);
                if (to == endOff)
                    target.push(encoder.encodeNodeEnd(child));
            }
        }
        off = endOff;
    }
    return target;
}
// The code below will refuse to compute a diff with more than 5000
// insertions or deletions, which takes about 300ms to reach on my
// machine. This is a safeguard against runaway computations.
const MAX_DIFF_SIZE = 5000;
// This obscure mess of constants computes the minimum length of an
// unchanged range (not at the start/end of the compared content). The
// idea is to make it higher in bigger replacements, so that you don't
// get a diff soup of coincidentally identical letters when replacing
// a paragraph.
function minUnchanged(sizeA, sizeB) {
    return Math.min(15, Math.max(2, Math.floor(Math.max(sizeA, sizeB) / 10)));
}
function computeDiff(fragA, fragB, range, encoder = DefaultEncoder) {
    let tokA = tokens(fragA, encoder, range.fromA, range.toA, []);
    let tokB = tokens(fragB, encoder, range.fromB, range.toB, []);
    // Scan from both sides to cheaply eliminate work
    let start = 0, endA = tokA.length, endB = tokB.length;
    let cmp = encoder.compareTokens;
    while (start < tokA.length && start < tokB.length && cmp(tokA[start], tokB[start]))
        start++;
    if (start == tokA.length && start == tokB.length)
        return [];
    while (endA > start && endB > start && cmp(tokA[endA - 1], tokB[endB - 1]))
        endA--, endB--;
    // If the result is simple _or_ too big to cheaply compute, return
    // the remaining region as the diff
    if (endA == start || endB == start || (endA == endB && endA == start + 1))
        return [range.slice(start, endA, start, endB)];
    // This is an implementation of Myers' diff algorithm
    // See https://neil.fraser.name/writing/diff/myers.pdf and
    // https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/
    let lenA = endA - start, lenB = endB - start;
    let max = Math.min(MAX_DIFF_SIZE, lenA + lenB), off = max + 1;
    let history = [];
    let frontier = [];
    for (let len = off * 2, i = 0; i < len; i++)
        frontier[i] = -1;
    for (let size = 0; size <= max; size++) {
        for (let diag = -size; diag <= size; diag += 2) {
            let next = frontier[diag + 1 + max], prev = frontier[diag - 1 + max];
            let x = next < prev ? prev : next + 1, y = x + diag;
            while (x < lenA && y < lenB && cmp(tokA[start + x], tokB[start + y]))
                x++, y++;
            frontier[diag + max] = x;
            // Found a match
            if (x >= lenA && y >= lenB) {
                // Trace back through the history to build up a set of changed ranges.
                let diff = [], minSpan = minUnchanged(endA - start, endB - start);
                // Used to add steps to a diff one at a time, back to front, merging
                // ones that are less than minSpan tokens apart
                let fromA = -1, toA = -1, fromB = -1, toB = -1;
                let add = (fA, tA, fB, tB) => {
                    if (fromA > -1 && fromA < tA + minSpan) {
                        fromA = fA;
                        fromB = fB;
                    }
                    else {
                        if (fromA > -1)
                            diff.push(range.slice(fromA, toA, fromB, toB));
                        fromA = fA;
                        toA = tA;
                        fromB = fB;
                        toB = tB;
                    }
                };
                for (let i = size - 1; i >= 0; i--) {
                    let next = frontier[diag + 1 + max], prev = frontier[diag - 1 + max];
                    if (next < prev) { // Deletion
                        diag--;
                        x = prev + start;
                        y = x + diag;
                        add(x, x, y, y + 1);
                    }
                    else { // Insertion
                        diag++;
                        x = next + start;
                        y = x + diag;
                        add(x, x + 1, y, y);
                    }
                    frontier = history[i >> 1];
                }
                if (fromA > -1)
                    diff.push(range.slice(fromA, toA, fromB, toB));
                return diff.reverse();
            }
        }
        // Since only either odd or even diagonals are read from each
        // frontier, we only copy them every other iteration.
        if (size % 2 == 0)
            history.push(frontier.slice());
    }
    // The loop exited, meaning the maximum amount of work was done.
    // Just return a change spanning the entire range.
    return [range.slice(start, endA, start, endB)];
}

/**
Stores metadata for a part of a change.
*/
class Span {
    /**
    @internal
    */
    constructor(
    /**
    The length of this span.
    */
    length, 
    /**
    The data associated with this span.
    */
    data) {
        this.length = length;
        this.data = data;
    }
    /**
    @internal
    */
    cut(length) {
        return length == this.length ? this : new Span(length, this.data);
    }
    /**
    @internal
    */
    static slice(spans, from, to) {
        if (from == to)
            return Span.none;
        if (from == 0 && to == Span.len(spans))
            return spans;
        let result = [];
        for (let i = 0, off = 0; off < to; i++) {
            let span = spans[i], end = off + span.length;
            let overlap = Math.min(to, end) - Math.max(from, off);
            if (overlap > 0)
                result.push(span.cut(overlap));
            off = end;
        }
        return result;
    }
    /**
    @internal
    */
    static join(a, b, combine) {
        if (a.length == 0)
            return b;
        if (b.length == 0)
            return a;
        let combined = combine(a[a.length - 1].data, b[0].data);
        if (combined == null)
            return a.concat(b);
        let result = a.slice(0, a.length - 1);
        result.push(new Span(a[a.length - 1].length + b[0].length, combined));
        for (let i = 1; i < b.length; i++)
            result.push(b[i]);
        return result;
    }
    /**
    @internal
    */
    static len(spans) {
        let len = 0;
        for (let i = 0; i < spans.length; i++)
            len += spans[i].length;
        return len;
    }
}
/**
@internal
*/
Span.none = [];
/**
A replaced range with metadata associated with it.
*/
class Change {
    /**
    @internal
    */
    constructor(
    /**
    The start of the range deleted/replaced in the old document.
    */
    fromA, 
    /**
    The end of the range in the old document.
    */
    toA, 
    /**
    The start of the range inserted in the new document.
    */
    fromB, 
    /**
    The end of the range in the new document.
    */
    toB, 
    /**
    Data associated with the deleted content. The length of these
    spans adds up to `this.toA - this.fromA`.
    */
    deleted, 
    /**
    Data associated with the inserted content. Length adds up to
    `this.toB - this.fromB`.
    */
    inserted) {
        this.fromA = fromA;
        this.toA = toA;
        this.fromB = fromB;
        this.toB = toB;
        this.deleted = deleted;
        this.inserted = inserted;
    }
    /**
    @internal
    */
    get lenA() { return this.toA - this.fromA; }
    /**
    @internal
    */
    get lenB() { return this.toB - this.fromB; }
    /**
    @internal
    */
    slice(startA, endA, startB, endB) {
        if (startA == 0 && startB == 0 && endA == this.toA - this.fromA &&
            endB == this.toB - this.fromB)
            return this;
        return new Change(this.fromA + startA, this.fromA + endA, this.fromB + startB, this.fromB + endB, Span.slice(this.deleted, startA, endA), Span.slice(this.inserted, startB, endB));
    }
    /**
    This merges two changesets (the end document of x should be the
    start document of y) into a single one spanning the start of x to
    the end of y.
    */
    static merge(x, y, combine) {
        if (x.length == 0)
            return y;
        if (y.length == 0)
            return x;
        let result = [];
        // Iterate over both sets in parallel, using the middle coordinate
        // system (B in x, A in y) to synchronize.
        for (let iX = 0, iY = 0, curX = x[0], curY = y[0];;) {
            if (!curX && !curY) {
                return result;
            }
            else if (curX && (!curY || curX.toB < curY.fromA)) { // curX entirely in front of curY
                let off = iY ? y[iY - 1].toB - y[iY - 1].toA : 0;
                result.push(off == 0 ? curX :
                    new Change(curX.fromA, curX.toA, curX.fromB + off, curX.toB + off, curX.deleted, curX.inserted));
                curX = iX++ == x.length ? null : x[iX];
            }
            else if (curY && (!curX || curY.toA < curX.fromB)) { // curY entirely in front of curX
                let off = iX ? x[iX - 1].toB - x[iX - 1].toA : 0;
                result.push(off == 0 ? curY :
                    new Change(curY.fromA - off, curY.toA - off, curY.fromB, curY.toB, curY.deleted, curY.inserted));
                curY = iY++ == y.length ? null : y[iY];
            }
            else { // Touch, need to merge
                // The rules for merging ranges are that deletions from the
                // old set and insertions from the new are kept. Areas of the
                // middle document covered by a but not by b are insertions
                // from a that need to be added, and areas covered by b but
                // not a are deletions from b that need to be added.
                let pos = Math.min(curX.fromB, curY.fromA);
                let fromA = Math.min(curX.fromA, curY.fromA - (iX ? x[iX - 1].toB - x[iX - 1].toA : 0)), toA = fromA;
                let fromB = Math.min(curY.fromB, curX.fromB + (iY ? y[iY - 1].toB - y[iY - 1].toA : 0)), toB = fromB;
                let deleted = Span.none, inserted = Span.none;
                // Used to prevent appending ins/del range for the same Change twice
                let enteredX = false, enteredY = false;
                // Need to have an inner loop since any number of further
                // ranges might be touching this group
                for (;;) {
                    let nextX = !curX ? 2e8 : pos >= curX.fromB ? curX.toB : curX.fromB;
                    let nextY = !curY ? 2e8 : pos >= curY.fromA ? curY.toA : curY.fromA;
                    let next = Math.min(nextX, nextY);
                    let inX = curX && pos >= curX.fromB, inY = curY && pos >= curY.fromA;
                    if (!inX && !inY)
                        break;
                    if (inX && pos == curX.fromB && !enteredX) {
                        deleted = Span.join(deleted, curX.deleted, combine);
                        toA += curX.lenA;
                        enteredX = true;
                    }
                    if (inX && !inY) {
                        inserted = Span.join(inserted, Span.slice(curX.inserted, pos - curX.fromB, next - curX.fromB), combine);
                        toB += next - pos;
                    }
                    if (inY && pos == curY.fromA && !enteredY) {
                        inserted = Span.join(inserted, curY.inserted, combine);
                        toB += curY.lenB;
                        enteredY = true;
                    }
                    if (inY && !inX) {
                        deleted = Span.join(deleted, Span.slice(curY.deleted, pos - curY.fromA, next - curY.fromA), combine);
                        toA += next - pos;
                    }
                    if (inX && next == curX.toB) {
                        curX = iX++ == x.length ? null : x[iX];
                        enteredX = false;
                    }
                    if (inY && next == curY.toA) {
                        curY = iY++ == y.length ? null : y[iY];
                        enteredY = false;
                    }
                    pos = next;
                }
                if (fromA < toA || fromB < toB)
                    result.push(new Change(fromA, toA, fromB, toB, deleted, inserted));
            }
        }
    }
}

let letter;
// If the runtime support unicode properties in regexps, that's a good
// source of info on whether something is a letter.
try {
    letter = new RegExp("[\\p{Alphabetic}_]", "u");
}
catch (_) { }
// Otherwise, we see if the character changes when upper/lowercased,
// or if it is part of these common single-case scripts.
const nonASCIISingleCaseWordChar = /[\u00df\u0587\u0590-\u05f4\u0600-\u06ff\u3040-\u309f\u30a0-\u30ff\u3400-\u4db5\u4e00-\u9fcc\uac00-\ud7af]/;
function isLetter(code) {
    if (code < 128)
        return code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 79 && code <= 122;
    let ch = String.fromCharCode(code);
    if (letter)
        return letter.test(ch);
    return ch.toUpperCase() != ch.toLowerCase() || nonASCIISingleCaseWordChar.test(ch);
}
// Convert a range of document into a string, so that we can easily
// access characters at a given position. Treat non-text tokens as
// spaces so that they aren't considered part of a word.
function getText(frag, start, end) {
    let out = "";
    function convert(frag, start, end) {
        for (let i = 0, off = 0; i < frag.childCount; i++) {
            let child = frag.child(i), endOff = off + child.nodeSize;
            let from = Math.max(off, start), to = Math.min(endOff, end);
            if (from < to) {
                if (child.isText) {
                    out += child.text.slice(Math.max(0, start - off), Math.min(child.text.length, end - off));
                }
                else if (child.isLeaf) {
                    out += " ";
                }
                else {
                    if (from == off)
                        out += " ";
                    convert(child.content, Math.max(0, from - off - 1), Math.min(child.content.size, end - off));
                    if (to == endOff)
                        out += " ";
                }
            }
            off = endOff;
        }
    }
    convert(frag, start, end);
    return out;
}
// The distance changes have to be apart for us to not consider them
// candidates for merging.
const MAX_SIMPLIFY_DISTANCE = 30;
/**
Simplifies a set of changes for presentation. This makes the
assumption that having both insertions and deletions within a word
is confusing, and, when such changes occur without a word boundary
between them, they should be expanded to cover the entire set of
words (in the new document) they touch. An exception is made for
single-character replacements.
*/
function simplifyChanges(changes, doc) {
    let result = [];
    for (let i = 0; i < changes.length; i++) {
        let end = changes[i].toB, start = i;
        while (i < changes.length - 1 && changes[i + 1].fromB <= end + MAX_SIMPLIFY_DISTANCE)
            end = changes[++i].toB;
        simplifyAdjacentChanges(changes, start, i + 1, doc, result);
    }
    return result;
}
function simplifyAdjacentChanges(changes, from, to, doc, target) {
    let start = Math.max(0, changes[from].fromB - MAX_SIMPLIFY_DISTANCE);
    let end = Math.min(doc.content.size, changes[to - 1].toB + MAX_SIMPLIFY_DISTANCE);
    let text = getText(doc.content, start, end);
    for (let i = from; i < to; i++) {
        let startI = i, last = changes[i], deleted = last.lenA, inserted = last.lenB;
        while (i < to - 1) {
            let next = changes[i + 1], boundary = false;
            let prevLetter = last.toB == end ? false : isLetter(text.charCodeAt(last.toB - 1 - start));
            for (let pos = last.toB; !boundary && pos < next.fromB; pos++) {
                let nextLetter = pos == end ? false : isLetter(text.charCodeAt(pos - start));
                if ((!prevLetter || !nextLetter) && pos != changes[startI].fromB)
                    boundary = true;
                prevLetter = nextLetter;
            }
            if (boundary)
                break;
            deleted += next.lenA;
            inserted += next.lenB;
            last = next;
            i++;
        }
        if (inserted > 0 && deleted > 0 && !(inserted == 1 && deleted == 1)) {
            let from = changes[startI].fromB, to = changes[i].toB;
            if (from < end && isLetter(text.charCodeAt(from - start)))
                while (from > start && isLetter(text.charCodeAt(from - 1 - start)))
                    from--;
            if (to > start && isLetter(text.charCodeAt(to - 1 - start)))
                while (to < end && isLetter(text.charCodeAt(to - start)))
                    to++;
            let joined = fillChange(changes.slice(startI, i + 1), from, to);
            let last = target.length ? target[target.length - 1] : null;
            if (last && last.toA == joined.fromA)
                target[target.length - 1] = new Change(last.fromA, joined.toA, last.fromB, joined.toB, last.deleted.concat(joined.deleted), last.inserted.concat(joined.inserted));
            else
                target.push(joined);
        }
        else {
            for (let j = startI; j <= i; j++)
                target.push(changes[j]);
        }
    }
    return changes;
}
function combine(a, b) { return a === b ? a : null; }
function fillChange(changes, fromB, toB) {
    let fromA = changes[0].fromA - (changes[0].fromB - fromB);
    let last = changes[changes.length - 1];
    let toA = last.toA + (toB - last.toB);
    let deleted = Span.none, inserted = Span.none;
    let delData = (changes[0].deleted.length ? changes[0].deleted : changes[0].inserted)[0].data;
    let insData = (changes[0].inserted.length ? changes[0].inserted : changes[0].deleted)[0].data;
    for (let posA = fromA, posB = fromB, i = 0;; i++) {
        let next = i == changes.length ? null : changes[i];
        let endA = next ? next.fromA : toA, endB = next ? next.fromB : toB;
        if (endA > posA)
            deleted = Span.join(deleted, [new Span(endA - posA, delData)], combine);
        if (endB > posB)
            inserted = Span.join(inserted, [new Span(endB - posB, insData)], combine);
        if (!next)
            break;
        deleted = Span.join(deleted, next.deleted, combine);
        inserted = Span.join(inserted, next.inserted, combine);
        if (deleted.length)
            delData = deleted[deleted.length - 1].data;
        if (inserted.length)
            insData = inserted[inserted.length - 1].data;
        posA = next.toA;
        posB = next.toB;
    }
    return new Change(fromA, toA, fromB, toB, deleted, inserted);
}

/**
A change set tracks the changes to a document from a given point
in the past. It condenses a number of step maps down to a flat
sequence of replacements, and simplifies replacments that
partially undo themselves by comparing their content.
*/
class ChangeSet {
    /**
    @internal
    */
    constructor(
    /**
    @internal
    */
    config, 
    /**
    Replaced regions.
    */
    changes) {
        this.config = config;
        this.changes = changes;
    }
    /**
    Computes a new changeset by adding the given step maps and
    metadata (either as an array, per-map, or as a single value to be
    associated with all maps) to the current set. Will not mutate the
    old set.
    
    Note that due to simplification that happens after each add,
    incrementally adding steps might create a different final set
    than adding all those changes at once, since different document
    tokens might be matched during simplification depending on the
    boundaries of the current changed ranges.
    */
    addSteps(newDoc, maps, data) {
        // This works by inspecting the position maps for the changes,
        // which indicate what parts of the document were replaced by new
        // content, and the size of that new content. It uses these to
        // build up Change objects.
        //
        // These change objects are put in sets and merged together using
        // Change.merge, giving us the changes created by the new steps.
        // Those changes can then be merged with the existing set of
        // changes.
        //
        // For each change that was touched by the new steps, we recompute
        // a diff to try to minimize the change by dropping matching
        // pieces of the old and new document from the change.
        let stepChanges = [];
        // Add spans for new steps.
        for (let i = 0; i < maps.length; i++) {
            let d = Array.isArray(data) ? data[i] : data;
            let off = 0;
            maps[i].forEach((fromA, toA, fromB, toB) => {
                stepChanges.push(new Change(fromA + off, toA + off, fromB, toB, fromA == toA ? Span.none : [new Span(toA - fromA, d)], fromB == toB ? Span.none : [new Span(toB - fromB, d)]));
                off = (toB - fromB) - (toA - fromA);
            });
        }
        if (stepChanges.length == 0)
            return this;
        let newChanges = mergeAll(stepChanges, this.config.combine);
        let changes = Change.merge(this.changes, newChanges, this.config.combine);
        let updated = changes;
        // Minimize changes when possible
        for (let i = 0; i < updated.length; i++) {
            let change = updated[i];
            if (change.fromA == change.toA || change.fromB == change.toB ||
                // Only look at changes that touch newly added changed ranges
                !newChanges.some(r => r.toB > change.fromB && r.fromB < change.toB))
                continue;
            let diff = computeDiff(this.config.doc.content, newDoc.content, change, this.config.encoder);
            // Fast path: If they are completely different, don't do anything
            if (diff.length == 1 && diff[0].fromB == 0 && diff[0].toB == change.toB - change.fromB)
                continue;
            if (updated == changes)
                updated = changes.slice();
            if (diff.length == 1) {
                updated[i] = diff[0];
            }
            else {
                updated.splice(i, 1, ...diff);
                i += diff.length - 1;
            }
        }
        return new ChangeSet(this.config, updated);
    }
    /**
    The starting document of the change set.
    */
    get startDoc() { return this.config.doc; }
    /**
    Map the span's data values in the given set through a function
    and construct a new set with the resulting data.
    */
    map(f) {
        let mapSpan = (span) => {
            let newData = f(span);
            return newData === span.data ? span : new Span(span.length, newData);
        };
        return new ChangeSet(this.config, this.changes.map((ch) => {
            return new Change(ch.fromA, ch.toA, ch.fromB, ch.toB, ch.deleted.map(mapSpan), ch.inserted.map(mapSpan));
        }));
    }
    /**
    Compare two changesets and return the range in which they are
    changed, if any. If the document changed between the maps, pass
    the maps for the steps that changed it as second argument, and
    make sure the method is called on the old set and passed the new
    set. The returned positions will be in new document coordinates.
    */
    changedRange(b, maps) {
        if (b == this)
            return null;
        let touched = maps && touchedRange(maps);
        let moved = touched ? (touched.toB - touched.fromB) - (touched.toA - touched.fromA) : 0;
        function map(p) {
            return !touched || p <= touched.fromA ? p : p + moved;
        }
        let from = touched ? touched.fromB : 2e8, to = touched ? touched.toB : -2e8;
        function add(start, end = start) {
            from = Math.min(start, from);
            to = Math.max(end, to);
        }
        let rA = this.changes, rB = b.changes;
        for (let iA = 0, iB = 0; iA < rA.length && iB < rB.length;) {
            let rangeA = rA[iA], rangeB = rB[iB];
            if (rangeA && rangeB && sameRanges(rangeA, rangeB, map)) {
                iA++;
                iB++;
            }
            else if (rangeB && (!rangeA || map(rangeA.fromB) >= rangeB.fromB)) {
                add(rangeB.fromB, rangeB.toB);
                iB++;
            }
            else {
                add(map(rangeA.fromB), map(rangeA.toB));
                iA++;
            }
        }
        return from <= to ? { from, to } : null;
    }
    /**
    Create a changeset with the given base object and configuration.
    
    The `combine` function is used to compare and combine metadata—it
    should return null when metadata isn't compatible, and a combined
    version for a merged range when it is.
    
    When given, a token encoder determines how document tokens are
    serialized and compared when diffing the content produced by
    changes. The default is to just compare nodes by name and text
    by character, ignoring marks and attributes.
    */
    static create(doc, combine = (a, b) => a === b ? a : null, tokenEncoder = DefaultEncoder) {
        return new ChangeSet({ combine, doc, encoder: tokenEncoder }, []);
    }
}
/**
Exported for testing @internal
*/
ChangeSet.computeDiff = computeDiff;
// Divide-and-conquer approach to merging a series of ranges.
function mergeAll(ranges, combine, start = 0, end = ranges.length) {
    if (end == start + 1)
        return [ranges[start]];
    let mid = (start + end) >> 1;
    return Change.merge(mergeAll(ranges, combine, start, mid), mergeAll(ranges, combine, mid, end), combine);
}
function endRange(maps) {
    let from = 2e8, to = -2e8;
    for (let i = 0; i < maps.length; i++) {
        let map = maps[i];
        if (from != 2e8) {
            from = map.map(from, -1);
            to = map.map(to, 1);
        }
        map.forEach((_s, _e, start, end) => {
            from = Math.min(from, start);
            to = Math.max(to, end);
        });
    }
    return from == 2e8 ? null : { from, to };
}
function touchedRange(maps) {
    let b = endRange(maps);
    if (!b)
        return null;
    let a = endRange(maps.map(m => m.invert()).reverse());
    return { fromA: a.from, toA: a.to, fromB: b.from, toB: b.to };
}
function sameRanges(a, b, map) {
    return map(a.fromB) == b.fromB && map(a.toB) == b.toB &&
        sameSpans(a.deleted, b.deleted) && sameSpans(a.inserted, b.inserted);
}
function sameSpans(a, b) {
    if (a.length != b.length)
        return false;
    for (let i = 0; i < a.length; i++)
        if (a[i].length != b[i].length || a[i].data !== b[i].data)
            return false;
    return true;
}

export { Change, ChangeSet, Span, simplifyChanges };
