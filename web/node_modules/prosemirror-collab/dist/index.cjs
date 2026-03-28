'use strict';

function _defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } }

function _createClass(Constructor, protoProps, staticProps) { if (protoProps) _defineProperties(Constructor.prototype, protoProps); if (staticProps) _defineProperties(Constructor, staticProps); Object.defineProperty(Constructor, "prototype", { writable: false }); return Constructor; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

Object.defineProperty(exports, '__esModule', {
  value: true
});

var prosemirrorState = require('prosemirror-state');

var Rebaseable = _createClass(function Rebaseable(step, inverted, origin) {
  _classCallCheck(this, Rebaseable);

  this.step = step;
  this.inverted = inverted;
  this.origin = origin;
});

function rebaseSteps(steps, over, transform) {
  for (var i = steps.length - 1; i >= 0; i--) {
    transform.step(steps[i].inverted);
  }

  for (var _i = 0; _i < over.length; _i++) {
    transform.step(over[_i]);
  }

  var result = [];

  for (var _i2 = 0, mapFrom = steps.length; _i2 < steps.length; _i2++) {
    var mapped = steps[_i2].step.map(transform.mapping.slice(mapFrom));

    mapFrom--;

    if (mapped && !transform.maybeStep(mapped).failed) {
      transform.mapping.setMirror(mapFrom, transform.steps.length - 1);
      result.push(new Rebaseable(mapped, mapped.invert(transform.docs[transform.docs.length - 1]), steps[_i2].origin));
    }
  }

  return result;
}

var CollabState = _createClass(function CollabState(version, unconfirmed) {
  _classCallCheck(this, CollabState);

  this.version = version;
  this.unconfirmed = unconfirmed;
});

function unconfirmedFrom(transform) {
  var result = [];

  for (var i = 0; i < transform.steps.length; i++) {
    result.push(new Rebaseable(transform.steps[i], transform.steps[i].invert(transform.docs[i]), transform));
  }

  return result;
}

var collabKey = new prosemirrorState.PluginKey("collab");

function collab() {
  var config = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var conf = {
    version: config.version || 0,
    clientID: config.clientID == null ? Math.floor(Math.random() * 0xFFFFFFFF) : config.clientID
  };
  return new prosemirrorState.Plugin({
    key: collabKey,
    state: {
      init: function init() {
        return new CollabState(conf.version, []);
      },
      apply: function apply(tr, collab) {
        var newState = tr.getMeta(collabKey);
        if (newState) return newState;
        if (tr.docChanged) return new CollabState(collab.version, collab.unconfirmed.concat(unconfirmedFrom(tr)));
        return collab;
      }
    },
    config: conf,
    historyPreserveItems: true
  });
}

function receiveTransaction(state, steps, clientIDs) {
  var options = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : {};
  var collabState = collabKey.getState(state);
  var version = collabState.version + steps.length;
  var ourID = collabKey.get(state).spec.config.clientID;
  var ours = 0;

  while (ours < clientIDs.length && clientIDs[ours] == ourID) {
    ++ours;
  }

  var unconfirmed = collabState.unconfirmed.slice(ours);
  steps = ours ? steps.slice(ours) : steps;
  if (!steps.length) return state.tr.setMeta(collabKey, new CollabState(version, unconfirmed));
  var nUnconfirmed = unconfirmed.length;
  var tr = state.tr;

  if (nUnconfirmed) {
    unconfirmed = rebaseSteps(unconfirmed, steps, tr);
  } else {
    for (var i = 0; i < steps.length; i++) {
      tr.step(steps[i]);
    }

    unconfirmed = [];
  }

  var newCollabState = new CollabState(version, unconfirmed);

  if (options && options.mapSelectionBackward && state.selection instanceof prosemirrorState.TextSelection) {
    tr.setSelection(prosemirrorState.TextSelection.between(tr.doc.resolve(tr.mapping.map(state.selection.anchor, -1)), tr.doc.resolve(tr.mapping.map(state.selection.head, -1)), -1));
    tr.updated &= ~1;
  }

  return tr.setMeta("rebased", nUnconfirmed).setMeta("addToHistory", false).setMeta(collabKey, newCollabState);
}

function sendableSteps(state) {
  var collabState = collabKey.getState(state);
  if (collabState.unconfirmed.length == 0) return null;
  return {
    version: collabState.version,
    steps: collabState.unconfirmed.map(function (s) {
      return s.step;
    }),
    clientID: collabKey.get(state).spec.config.clientID,

    get origins() {
      return this._origins || (this._origins = collabState.unconfirmed.map(function (s) {
        return s.origin;
      }));
    }

  };
}

function getVersion(state) {
  return collabKey.getState(state).version;
}

exports.collab = collab;
exports.getVersion = getVersion;
exports.rebaseSteps = rebaseSteps;
exports.receiveTransaction = receiveTransaction;
exports.sendableSteps = sendableSteps;
