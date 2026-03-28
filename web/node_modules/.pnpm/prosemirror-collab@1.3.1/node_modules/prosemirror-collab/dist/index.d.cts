import { Plugin, EditorState, Transaction } from 'prosemirror-state';
import { Step } from 'prosemirror-transform';

declare type CollabConfig = {
    /**
    The starting version number of the collaborative editing.
    Defaults to 0.
    */
    version?: number;
    /**
    This client's ID, used to distinguish its changes from those of
    other clients. Defaults to a random 32-bit number.
    */
    clientID?: number | string;
};
/**
Creates a plugin that enables the collaborative editing framework
for the editor.
*/
declare function collab(config?: CollabConfig): Plugin;
/**
Create a transaction that represents a set of new steps received from
the authority. Applying this transaction moves the state forward to
adjust to the authority's view of the document.
*/
declare function receiveTransaction(state: EditorState, steps: readonly Step[], clientIDs: readonly (string | number)[], options?: {
    /**
    When enabled (the default is `false`), if the current
    selection is a [text selection](https://prosemirror.net/docs/ref/#state.TextSelection), its
    sides are mapped with a negative bias for this transaction, so
    that content inserted at the cursor ends up after the cursor.
    Users usually prefer this, but it isn't done by default for
    reasons of backwards compatibility.
    */
    mapSelectionBackward?: boolean;
}): Transaction;
/**
Provides data describing the editor's unconfirmed steps, which need
to be sent to the central authority. Returns null when there is
nothing to send.

`origins` holds the _original_ transactions that produced each
steps. This can be useful for looking up time stamps and other
metadata for the steps, but note that the steps may have been
rebased, whereas the origin transactions are still the old,
unchanged objects.
*/
declare function sendableSteps(state: EditorState): {
    version: number;
    steps: readonly Step[];
    clientID: number | string;
    origins: readonly Transaction[];
} | null;
/**
Get the version up to which the collab plugin has synced with the
central authority.
*/
declare function getVersion(state: EditorState): number;

export { collab, getVersion, receiveTransaction, sendableSteps };
