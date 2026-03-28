import {Plugin, PluginKey, TextSelection, EditorState, Transaction} from "prosemirror-state"
import {Step, Transform} from "prosemirror-transform"

class Rebaseable {
  constructor(
    readonly step: Step,
    readonly inverted: Step,
    readonly origin: Transform
  ) {}
}

/// Undo a given set of steps, apply a set of other steps, and then
/// redo them @internal
export function rebaseSteps(steps: readonly Rebaseable[], over: readonly Step[], transform: Transform) {
  for (let i = steps.length - 1; i >= 0; i--) transform.step(steps[i].inverted)
  for (let i = 0; i < over.length; i++) transform.step(over[i])
  let result = []
  for (let i = 0, mapFrom = steps.length; i < steps.length; i++) {
    let mapped = steps[i].step.map(transform.mapping.slice(mapFrom))
    mapFrom--
    if (mapped && !transform.maybeStep(mapped).failed) {
      transform.mapping.setMirror(mapFrom, transform.steps.length - 1)
      result.push(new Rebaseable(mapped, mapped.invert(transform.docs[transform.docs.length - 1]), steps[i].origin))
    }
  }
  return result
}

// This state field accumulates changes that have to be sent to the
// central authority in the collaborating group and makes it possible
// to integrate changes made by peers into our local document. It is
// defined by the plugin, and will be available as the `collab` field
// in the resulting editor state.
class CollabState {
  constructor(
    // The version number of the last update received from the central
    // authority. Starts at 0 or the value of the `version` property
    // in the option object, for the editor's value when the option
    // was enabled.
    readonly version: number,
    // The local steps that havent been successfully sent to the
    // server yet.
    readonly unconfirmed: readonly Rebaseable[]
  ) {}
}

function unconfirmedFrom(transform: Transform) {
  let result = []
  for (let i = 0; i < transform.steps.length; i++)
    result.push(new Rebaseable(transform.steps[i],
                               transform.steps[i].invert(transform.docs[i]),
                               transform))
  return result
}

const collabKey = new PluginKey("collab")

type CollabConfig = {
  /// The starting version number of the collaborative editing.
  /// Defaults to 0.
  version?: number

  /// This client's ID, used to distinguish its changes from those of
  /// other clients. Defaults to a random 32-bit number.
  clientID?: number | string
}

/// Creates a plugin that enables the collaborative editing framework
/// for the editor.
export function collab(config: CollabConfig = {}): Plugin {
  let conf: Required<CollabConfig> = {
    version: config.version || 0,
    clientID: config.clientID == null ? Math.floor(Math.random() * 0xFFFFFFFF) : config.clientID
  }

  return new Plugin({
    key: collabKey,

    state: {
      init: () => new CollabState(conf.version, []),
      apply(tr, collab) {
        let newState = tr.getMeta(collabKey)
        if (newState)
          return newState
        if (tr.docChanged)
          return new CollabState(collab.version, collab.unconfirmed.concat(unconfirmedFrom(tr)))
        return collab
      }
    },

    config: conf,

    // This is used to notify the history plugin to not merge steps,
    // so that the history can be rebased.
    historyPreserveItems: true
  })
}

/// Create a transaction that represents a set of new steps received from
/// the authority. Applying this transaction moves the state forward to
/// adjust to the authority's view of the document.
export function receiveTransaction(
  state: EditorState,
  steps: readonly Step[],
  clientIDs: readonly (string | number)[],
  options: {
    /// When enabled (the default is `false`), if the current
    /// selection is a [text selection](#state.TextSelection), its
    /// sides are mapped with a negative bias for this transaction, so
    /// that content inserted at the cursor ends up after the cursor.
    /// Users usually prefer this, but it isn't done by default for
    /// reasons of backwards compatibility.
    mapSelectionBackward?: boolean
  } = {}
) {
  // Pushes a set of steps (received from the central authority) into
  // the editor state (which should have the collab plugin enabled).
  // Will recognize its own changes, and confirm unconfirmed steps as
  // appropriate. Remaining unconfirmed steps will be rebased over
  // remote steps.
  let collabState = collabKey.getState(state)
  let version = collabState.version + steps.length
  let ourID: string | number = (collabKey.get(state)!.spec as any).config.clientID

  // Find out which prefix of the steps originated with us
  let ours = 0
  while (ours < clientIDs.length && clientIDs[ours] == ourID) ++ours
  let unconfirmed = collabState.unconfirmed.slice(ours)
  steps = ours ? steps.slice(ours) : steps

  // If all steps originated with us, we're done.
  if (!steps.length)
    return state.tr.setMeta(collabKey, new CollabState(version, unconfirmed))

  let nUnconfirmed = unconfirmed.length
  let tr = state.tr
  if (nUnconfirmed) {
    unconfirmed = rebaseSteps(unconfirmed, steps, tr)
  } else {
    for (let i = 0; i < steps.length; i++) tr.step(steps[i])
    unconfirmed = []
  }

  let newCollabState = new CollabState(version, unconfirmed)
  if (options && options.mapSelectionBackward && state.selection instanceof TextSelection) {
    tr.setSelection(TextSelection.between(tr.doc.resolve(tr.mapping.map(state.selection.anchor, -1)),
                                          tr.doc.resolve(tr.mapping.map(state.selection.head, -1)), -1))
    ;(tr as any).updated &= ~1
  }
  return tr.setMeta("rebased", nUnconfirmed).setMeta("addToHistory", false).setMeta(collabKey, newCollabState)
}

/// Provides data describing the editor's unconfirmed steps, which need
/// to be sent to the central authority. Returns null when there is
/// nothing to send.
///
/// `origins` holds the _original_ transactions that produced each
/// steps. This can be useful for looking up time stamps and other
/// metadata for the steps, but note that the steps may have been
/// rebased, whereas the origin transactions are still the old,
/// unchanged objects.
export function sendableSteps(state: EditorState): {
  version: number,
  steps: readonly Step[],
  clientID: number | string,
  origins: readonly Transaction[]
} | null {
  let collabState = collabKey.getState(state) as CollabState
  if (collabState.unconfirmed.length == 0) return null
  return {
    version: collabState.version,
    steps: collabState.unconfirmed.map(s => s.step),
    clientID: (collabKey.get(state)!.spec as any).config.clientID,
    get origins() {
      return (this as any)._origins || ((this as any)._origins = collabState.unconfirmed.map(s => s.origin))
    }
  }
}

/// Get the version up to which the collab plugin has synced with the
/// central authority.
export function getVersion(state: EditorState): number {
  return collabKey.getState(state).version
}
