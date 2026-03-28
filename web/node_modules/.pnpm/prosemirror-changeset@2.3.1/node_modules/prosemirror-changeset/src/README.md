# prosemirror-changeset

This is a helper module that can turn a sequence of document changes
into a set of insertions and deletions, for example to display them in
a change-tracking interface. Such a set can be built up incrementally,
in order to do such change tracking in a halfway performant way during
live editing.

This code is licensed under an [MIT
licence](https://github.com/ProseMirror/prosemirror-changeset/blob/master/LICENSE).

## Programming interface

Insertions and deletions are represented as ‘spans’—ranges in the
document. The deleted spans refer to the original document, whereas
the inserted ones point into the current document.

It is possible to associate arbitrary data values with such spans, for
example to track the user that made the change, the timestamp at which
it was made, or the step data necessary to invert it again.

@Change

@Span

@ChangeSet

@simplifyChanges

@TokenEncoder