import { Mark, Node } from 'prosemirror-model';
import { StepMap } from 'prosemirror-transform';

/**
Stores metadata for a part of a change.
*/
declare class Span<Data = any> {
    /**
    The length of this span.
    */
    readonly length: number;
    /**
    The data associated with this span.
    */
    readonly data: Data;
}
/**
A replaced range with metadata associated with it.
*/
declare class Change<Data = any> {
    /**
    The start of the range deleted/replaced in the old document.
    */
    readonly fromA: number;
    /**
    The end of the range in the old document.
    */
    readonly toA: number;
    /**
    The start of the range inserted in the new document.
    */
    readonly fromB: number;
    /**
    The end of the range in the new document.
    */
    readonly toB: number;
    /**
    Data associated with the deleted content. The length of these
    spans adds up to `this.toA - this.fromA`.
    */
    readonly deleted: readonly Span<Data>[];
    /**
    Data associated with the inserted content. Length adds up to
    `this.toB - this.fromB`.
    */
    readonly inserted: readonly Span<Data>[];
    /**
    This merges two changesets (the end document of x should be the
    start document of y) into a single one spanning the start of x to
    the end of y.
    */
    static merge<Data>(x: readonly Change<Data>[], y: readonly Change<Data>[], combine: (dataA: Data, dataB: Data) => Data): readonly Change<Data>[];
}

/**
A token encoder can be passed when creating a `ChangeSet` in order
to influence the way the library runs its diffing algorithm. The
encoder determines how document tokens (such as nodes and
characters) are encoded and compared.

Note that both the encoding and the comparison may run a lot, and
doing non-trivial work in these functions could impact
performance.
*/
interface TokenEncoder<T> {
    /**
    Encode a given character, with the given marks applied.
    */
    encodeCharacter(char: number, marks: readonly Mark[]): T;
    /**
    Encode the start of a node or, if this is a leaf node, the
    entire node.
    */
    encodeNodeStart(node: Node): T;
    /**
    Encode the end token for the given node. It is valid to encode
    every end token in the same way.
    */
    encodeNodeEnd(node: Node): T;
    /**
    Compare the given tokens. Should return true when they count as
    equal.
    */
    compareTokens(a: T, b: T): boolean;
}

/**
Simplifies a set of changes for presentation. This makes the
assumption that having both insertions and deletions within a word
is confusing, and, when such changes occur without a word boundary
between them, they should be expanded to cover the entire set of
words (in the new document) they touch. An exception is made for
single-character replacements.
*/
declare function simplifyChanges(changes: readonly Change[], doc: Node): Change<any>[];

/**
A change set tracks the changes to a document from a given point
in the past. It condenses a number of step maps down to a flat
sequence of replacements, and simplifies replacments that
partially undo themselves by comparing their content.
*/
declare class ChangeSet<Data = any> {
    /**
    Replaced regions.
    */
    readonly changes: readonly Change<Data>[];
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
    addSteps(newDoc: Node, maps: readonly StepMap[], data: Data | readonly Data[]): ChangeSet<Data>;
    /**
    The starting document of the change set.
    */
    get startDoc(): Node;
    /**
    Map the span's data values in the given set through a function
    and construct a new set with the resulting data.
    */
    map(f: (range: Span<Data>) => Data): ChangeSet<Data>;
    /**
    Compare two changesets and return the range in which they are
    changed, if any. If the document changed between the maps, pass
    the maps for the steps that changed it as second argument, and
    make sure the method is called on the old set and passed the new
    set. The returned positions will be in new document coordinates.
    */
    changedRange(b: ChangeSet, maps?: readonly StepMap[]): {
        from: number;
        to: number;
    } | null;
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
    static create<Data = any>(doc: Node, combine?: (dataA: Data, dataB: Data) => Data, tokenEncoder?: TokenEncoder<any>): ChangeSet<Data>;
}

export { Change, ChangeSet, Span, type TokenEncoder, simplifyChanges };
