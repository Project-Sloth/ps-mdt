'use strict';

function _toConsumableArray(arr) { return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _unsupportedIterableToArray(arr) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(o, minLen) { if (!o) return; if (typeof o === "string") return _arrayLikeToArray(o, minLen); var n = Object.prototype.toString.call(o).slice(8, -1); if (n === "Object" && o.constructor) n = o.constructor.name; if (n === "Map" || n === "Set") return Array.from(o); if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen); }
function _iterableToArray(iter) { if (typeof Symbol !== "undefined" && iter[Symbol.iterator] != null || iter["@@iterator"] != null) return Array.from(iter); }
function _arrayWithoutHoles(arr) { if (Array.isArray(arr)) return _arrayLikeToArray(arr); }
function _arrayLikeToArray(arr, len) { if (len == null || len > arr.length) len = arr.length; for (var i = 0, arr2 = new Array(len); i < len; i++) arr2[i] = arr[i]; return arr2; }
function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }
function _defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, _toPropertyKey(descriptor.key), descriptor); } }
function _createClass(Constructor, protoProps, staticProps) { if (protoProps) _defineProperties(Constructor.prototype, protoProps); if (staticProps) _defineProperties(Constructor, staticProps); Object.defineProperty(Constructor, "prototype", { writable: false }); return Constructor; }
function _toPropertyKey(arg) { var key = _toPrimitive(arg, "string"); return _typeof(key) === "symbol" ? key : String(key); }
function _toPrimitive(input, hint) { if (_typeof(input) !== "object" || input === null) return input; var prim = input[Symbol.toPrimitive]; if (prim !== undefined) { var res = prim.call(input, hint || "default"); if (_typeof(res) !== "object") return res; throw new TypeError("@@toPrimitive must return a primitive value."); } return (hint === "string" ? String : Number)(input); }
function typeID(type) {
  var cache = type.schema.cached.changeSetIDs || (type.schema.cached.changeSetIDs = Object.create(null));
  var id = cache[type.name];
  if (id == null) cache[type.name] = id = Object.keys(type.schema.nodes).indexOf(type.name) + 1;
  return id;
}
var DefaultEncoder = {
  encodeCharacter: function encodeCharacter(_char) {
    return _char;
  },
  encodeNodeStart: function encodeNodeStart(node) {
    return node.type.name;
  },
  encodeNodeEnd: function encodeNodeEnd(node) {
    return -typeID(node.type);
  },
  compareTokens: function compareTokens(a, b) {
    return a === b;
  }
};
function tokens(frag, encoder, start, end, target) {
  for (var i = 0, off = 0; i < frag.childCount; i++) {
    var child = frag.child(i),
      endOff = off + child.nodeSize;
    var from = Math.max(off, start),
      to = Math.min(endOff, end);
    if (from < to) {
      if (child.isText) {
        for (var j = from; j < to; j++) target.push(encoder.encodeCharacter(child.text.charCodeAt(j - off), child.marks));
      } else if (child.isLeaf) {
        target.push(encoder.encodeNodeStart(child));
      } else {
        if (from == off) target.push(encoder.encodeNodeStart(child));
        tokens(child.content, encoder, Math.max(off + 1, from) - off - 1, Math.min(endOff - 1, to) - off - 1, target);
        if (to == endOff) target.push(encoder.encodeNodeEnd(child));
      }
    }
    off = endOff;
  }
  return target;
}
var MAX_DIFF_SIZE = 5000;
function minUnchanged(sizeA, sizeB) {
  return Math.min(15, Math.max(2, Math.floor(Math.max(sizeA, sizeB) / 10)));
}
function computeDiff(fragA, fragB, range) {
  var encoder = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : DefaultEncoder;
  var tokA = tokens(fragA, encoder, range.fromA, range.toA, []);
  var tokB = tokens(fragB, encoder, range.fromB, range.toB, []);
  var start = 0,
    endA = tokA.length,
    endB = tokB.length;
  var cmp = encoder.compareTokens;
  while (start < tokA.length && start < tokB.length && cmp(tokA[start], tokB[start])) start++;
  if (start == tokA.length && start == tokB.length) return [];
  while (endA > start && endB > start && cmp(tokA[endA - 1], tokB[endB - 1])) endA--, endB--;
  if (endA == start || endB == start || endA == endB && endA == start + 1) return [range.slice(start, endA, start, endB)];
  var lenA = endA - start,
    lenB = endB - start;
  var max = Math.min(MAX_DIFF_SIZE, lenA + lenB),
    off = max + 1;
  var history = [];
  var frontier = [];
  for (var len = off * 2, i = 0; i < len; i++) frontier[i] = -1;
  for (var size = 0; size <= max; size++) {
    var _loop = function _loop(_diag) {
        var next = frontier[_diag + 1 + max],
          prev = frontier[_diag - 1 + max];
        var x = next < prev ? prev : next + 1,
          y = x + _diag;
        while (x < lenA && y < lenB && cmp(tokA[start + x], tokB[start + y])) x++, y++;
        frontier[_diag + max] = x;
        if (x >= lenA && y >= lenB) {
          var diff = [],
            minSpan = minUnchanged(endA - start, endB - start);
          var fromA = -1,
            toA = -1,
            fromB = -1,
            toB = -1;
          var add = function add(fA, tA, fB, tB) {
            if (fromA > -1 && fromA < tA + minSpan) {
              fromA = fA;
              fromB = fB;
            } else {
              if (fromA > -1) diff.push(range.slice(fromA, toA, fromB, toB));
              fromA = fA;
              toA = tA;
              fromB = fB;
              toB = tB;
            }
          };
          for (var _i = size - 1; _i >= 0; _i--) {
            var _next = frontier[_diag + 1 + max],
              _prev = frontier[_diag - 1 + max];
            if (_next < _prev) {
              _diag--;
              x = _prev + start;
              y = x + _diag;
              add(x, x, y, y + 1);
            } else {
              _diag++;
              x = _next + start;
              y = x + _diag;
              add(x, x + 1, y, y);
            }
            frontier = history[_i >> 1];
          }
          if (fromA > -1) diff.push(range.slice(fromA, toA, fromB, toB));
          return {
            v: diff.reverse()
          };
        }
        diag = _diag;
      },
      _ret;
    for (var diag = -size; diag <= size; diag += 2) {
      _ret = _loop(diag);
      if (_ret) return _ret.v;
    }
    if (size % 2 == 0) history.push(frontier.slice());
  }
  return [range.slice(start, endA, start, endB)];
}
var Span = function () {
  function Span(length, data) {
    _classCallCheck(this, Span);
    this.length = length;
    this.data = data;
  }
  _createClass(Span, [{
    key: "cut",
    value: function cut(length) {
      return length == this.length ? this : new Span(length, this.data);
    }
  }], [{
    key: "slice",
    value: function slice(spans, from, to) {
      if (from == to) return Span.none;
      if (from == 0 && to == Span.len(spans)) return spans;
      var result = [];
      for (var i = 0, off = 0; off < to; i++) {
        var span = spans[i],
          end = off + span.length;
        var overlap = Math.min(to, end) - Math.max(from, off);
        if (overlap > 0) result.push(span.cut(overlap));
        off = end;
      }
      return result;
    }
  }, {
    key: "join",
    value: function join(a, b, combine) {
      if (a.length == 0) return b;
      if (b.length == 0) return a;
      var combined = combine(a[a.length - 1].data, b[0].data);
      if (combined == null) return a.concat(b);
      var result = a.slice(0, a.length - 1);
      result.push(new Span(a[a.length - 1].length + b[0].length, combined));
      for (var i = 1; i < b.length; i++) result.push(b[i]);
      return result;
    }
  }, {
    key: "len",
    value: function len(spans) {
      var len = 0;
      for (var i = 0; i < spans.length; i++) len += spans[i].length;
      return len;
    }
  }]);
  return Span;
}();
Span.none = [];
var Change = function () {
  function Change(fromA, toA, fromB, toB, deleted, inserted) {
    _classCallCheck(this, Change);
    this.fromA = fromA;
    this.toA = toA;
    this.fromB = fromB;
    this.toB = toB;
    this.deleted = deleted;
    this.inserted = inserted;
  }
  _createClass(Change, [{
    key: "lenA",
    get: function get() {
      return this.toA - this.fromA;
    }
  }, {
    key: "lenB",
    get: function get() {
      return this.toB - this.fromB;
    }
  }, {
    key: "slice",
    value: function slice(startA, endA, startB, endB) {
      if (startA == 0 && startB == 0 && endA == this.toA - this.fromA && endB == this.toB - this.fromB) return this;
      return new Change(this.fromA + startA, this.fromA + endA, this.fromB + startB, this.fromB + endB, Span.slice(this.deleted, startA, endA), Span.slice(this.inserted, startB, endB));
    }
  }], [{
    key: "merge",
    value: function merge(x, y, combine) {
      if (x.length == 0) return y;
      if (y.length == 0) return x;
      var result = [];
      for (var iX = 0, iY = 0, curX = x[0], curY = y[0];;) {
        if (!curX && !curY) {
          return result;
        } else if (curX && (!curY || curX.toB < curY.fromA)) {
          var off = iY ? y[iY - 1].toB - y[iY - 1].toA : 0;
          result.push(off == 0 ? curX : new Change(curX.fromA, curX.toA, curX.fromB + off, curX.toB + off, curX.deleted, curX.inserted));
          curX = iX++ == x.length ? null : x[iX];
        } else if (curY && (!curX || curY.toA < curX.fromB)) {
          var _off = iX ? x[iX - 1].toB - x[iX - 1].toA : 0;
          result.push(_off == 0 ? curY : new Change(curY.fromA - _off, curY.toA - _off, curY.fromB, curY.toB, curY.deleted, curY.inserted));
          curY = iY++ == y.length ? null : y[iY];
        } else {
          var pos = Math.min(curX.fromB, curY.fromA);
          var fromA = Math.min(curX.fromA, curY.fromA - (iX ? x[iX - 1].toB - x[iX - 1].toA : 0)),
            toA = fromA;
          var fromB = Math.min(curY.fromB, curX.fromB + (iY ? y[iY - 1].toB - y[iY - 1].toA : 0)),
            toB = fromB;
          var deleted = Span.none,
            inserted = Span.none;
          var enteredX = false,
            enteredY = false;
          for (;;) {
            var nextX = !curX ? 2e8 : pos >= curX.fromB ? curX.toB : curX.fromB;
            var nextY = !curY ? 2e8 : pos >= curY.fromA ? curY.toA : curY.fromA;
            var next = Math.min(nextX, nextY);
            var inX = curX && pos >= curX.fromB,
              inY = curY && pos >= curY.fromA;
            if (!inX && !inY) break;
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
          if (fromA < toA || fromB < toB) result.push(new Change(fromA, toA, fromB, toB, deleted, inserted));
        }
      }
    }
  }]);
  return Change;
}();
var letter;
try {
  letter = new RegExp("[\\p{Alphabetic}_]", "u");
} catch (_) {}
var nonASCIISingleCaseWordChar = /[\u00df\u0587\u0590-\u05f4\u0600-\u06ff\u3040-\u309f\u30a0-\u30ff\u3400-\u4db5\u4e00-\u9fcc\uac00-\ud7af]/;
function isLetter(code) {
  if (code < 128) return code >= 48 && code <= 57 || code >= 65 && code <= 90 || code >= 79 && code <= 122;
  var ch = String.fromCharCode(code);
  if (letter) return letter.test(ch);
  return ch.toUpperCase() != ch.toLowerCase() || nonASCIISingleCaseWordChar.test(ch);
}
function getText(frag, start, end) {
  var out = "";
  function convert(frag, start, end) {
    for (var i = 0, off = 0; i < frag.childCount; i++) {
      var child = frag.child(i),
        endOff = off + child.nodeSize;
      var from = Math.max(off, start),
        to = Math.min(endOff, end);
      if (from < to) {
        if (child.isText) {
          out += child.text.slice(Math.max(0, start - off), Math.min(child.text.length, end - off));
        } else if (child.isLeaf) {
          out += " ";
        } else {
          if (from == off) out += " ";
          convert(child.content, Math.max(0, from - off - 1), Math.min(child.content.size, end - off));
          if (to == endOff) out += " ";
        }
      }
      off = endOff;
    }
  }
  convert(frag, start, end);
  return out;
}
var MAX_SIMPLIFY_DISTANCE = 30;
function simplifyChanges(changes, doc) {
  var result = [];
  for (var i = 0; i < changes.length; i++) {
    var end = changes[i].toB,
      start = i;
    while (i < changes.length - 1 && changes[i + 1].fromB <= end + MAX_SIMPLIFY_DISTANCE) end = changes[++i].toB;
    simplifyAdjacentChanges(changes, start, i + 1, doc, result);
  }
  return result;
}
function simplifyAdjacentChanges(changes, from, to, doc, target) {
  var start = Math.max(0, changes[from].fromB - MAX_SIMPLIFY_DISTANCE);
  var end = Math.min(doc.content.size, changes[to - 1].toB + MAX_SIMPLIFY_DISTANCE);
  var text = getText(doc.content, start, end);
  for (var i = from; i < to; i++) {
    var startI = i,
      last = changes[i],
      deleted = last.lenA,
      inserted = last.lenB;
    while (i < to - 1) {
      var next = changes[i + 1],
        boundary = false;
      var prevLetter = last.toB == end ? false : isLetter(text.charCodeAt(last.toB - 1 - start));
      for (var pos = last.toB; !boundary && pos < next.fromB; pos++) {
        var nextLetter = pos == end ? false : isLetter(text.charCodeAt(pos - start));
        if ((!prevLetter || !nextLetter) && pos != changes[startI].fromB) boundary = true;
        prevLetter = nextLetter;
      }
      if (boundary) break;
      deleted += next.lenA;
      inserted += next.lenB;
      last = next;
      i++;
    }
    if (inserted > 0 && deleted > 0 && !(inserted == 1 && deleted == 1)) {
      var _from = changes[startI].fromB,
        _to = changes[i].toB;
      if (_from < end && isLetter(text.charCodeAt(_from - start))) while (_from > start && isLetter(text.charCodeAt(_from - 1 - start))) _from--;
      if (_to > start && isLetter(text.charCodeAt(_to - 1 - start))) while (_to < end && isLetter(text.charCodeAt(_to - start))) _to++;
      var joined = fillChange(changes.slice(startI, i + 1), _from, _to);
      var _last = target.length ? target[target.length - 1] : null;
      if (_last && _last.toA == joined.fromA) target[target.length - 1] = new Change(_last.fromA, joined.toA, _last.fromB, joined.toB, _last.deleted.concat(joined.deleted), _last.inserted.concat(joined.inserted));else target.push(joined);
    } else {
      for (var j = startI; j <= i; j++) target.push(changes[j]);
    }
  }
  return changes;
}
function combine(a, b) {
  return a === b ? a : null;
}
function fillChange(changes, fromB, toB) {
  var fromA = changes[0].fromA - (changes[0].fromB - fromB);
  var last = changes[changes.length - 1];
  var toA = last.toA + (toB - last.toB);
  var deleted = Span.none,
    inserted = Span.none;
  var delData = (changes[0].deleted.length ? changes[0].deleted : changes[0].inserted)[0].data;
  var insData = (changes[0].inserted.length ? changes[0].inserted : changes[0].deleted)[0].data;
  for (var posA = fromA, posB = fromB, i = 0;; i++) {
    var next = i == changes.length ? null : changes[i];
    var endA = next ? next.fromA : toA,
      endB = next ? next.fromB : toB;
    if (endA > posA) deleted = Span.join(deleted, [new Span(endA - posA, delData)], combine);
    if (endB > posB) inserted = Span.join(inserted, [new Span(endB - posB, insData)], combine);
    if (!next) break;
    deleted = Span.join(deleted, next.deleted, combine);
    inserted = Span.join(inserted, next.inserted, combine);
    if (deleted.length) delData = deleted[deleted.length - 1].data;
    if (inserted.length) insData = inserted[inserted.length - 1].data;
    posA = next.toA;
    posB = next.toB;
  }
  return new Change(fromA, toA, fromB, toB, deleted, inserted);
}
var ChangeSet = function () {
  function ChangeSet(config, changes) {
    _classCallCheck(this, ChangeSet);
    this.config = config;
    this.changes = changes;
  }
  _createClass(ChangeSet, [{
    key: "addSteps",
    value: function addSteps(newDoc, maps, data) {
      var _this = this;
      var stepChanges = [];
      var _loop2 = function _loop2() {
        var d = Array.isArray(data) ? data[i] : data;
        var off = 0;
        maps[i].forEach(function (fromA, toA, fromB, toB) {
          stepChanges.push(new Change(fromA + off, toA + off, fromB, toB, fromA == toA ? Span.none : [new Span(toA - fromA, d)], fromB == toB ? Span.none : [new Span(toB - fromB, d)]));
          off = toB - fromB - (toA - fromA);
        });
      };
      for (var i = 0; i < maps.length; i++) {
        _loop2();
      }
      if (stepChanges.length == 0) return this;
      var newChanges = mergeAll(stepChanges, this.config.combine);
      var changes = Change.merge(this.changes, newChanges, this.config.combine);
      var updated = changes;
      var _loop3 = function _loop3(_i3) {
          var change = updated[_i3];
          if (change.fromA == change.toA || change.fromB == change.toB || !newChanges.some(function (r) {
            return r.toB > change.fromB && r.fromB < change.toB;
          })) {
            _i2 = _i3;
            return 0;
          }
          var diff = computeDiff(_this.config.doc.content, newDoc.content, change, _this.config.encoder);
          if (diff.length == 1 && diff[0].fromB == 0 && diff[0].toB == change.toB - change.fromB) {
            _i2 = _i3;
            return 0;
          }
          if (updated == changes) updated = changes.slice();
          if (diff.length == 1) {
            updated[_i3] = diff[0];
          } else {
            var _updated;
            (_updated = updated).splice.apply(_updated, [_i3, 1].concat(_toConsumableArray(diff)));
            _i3 += diff.length - 1;
          }
          _i2 = _i3;
        },
        _ret2;
      for (var _i2 = 0; _i2 < updated.length; _i2++) {
        _ret2 = _loop3(_i2);
        if (_ret2 === 0) continue;
      }
      return new ChangeSet(this.config, updated);
    }
  }, {
    key: "startDoc",
    get: function get() {
      return this.config.doc;
    }
  }, {
    key: "map",
    value: function map(f) {
      var mapSpan = function mapSpan(span) {
        var newData = f(span);
        return newData === span.data ? span : new Span(span.length, newData);
      };
      return new ChangeSet(this.config, this.changes.map(function (ch) {
        return new Change(ch.fromA, ch.toA, ch.fromB, ch.toB, ch.deleted.map(mapSpan), ch.inserted.map(mapSpan));
      }));
    }
  }, {
    key: "changedRange",
    value: function changedRange(b, maps) {
      if (b == this) return null;
      var touched = maps && touchedRange(maps);
      var moved = touched ? touched.toB - touched.fromB - (touched.toA - touched.fromA) : 0;
      function map(p) {
        return !touched || p <= touched.fromA ? p : p + moved;
      }
      var from = touched ? touched.fromB : 2e8,
        to = touched ? touched.toB : -2e8;
      function add(start) {
        var end = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : start;
        from = Math.min(start, from);
        to = Math.max(end, to);
      }
      var rA = this.changes,
        rB = b.changes;
      for (var iA = 0, iB = 0; iA < rA.length && iB < rB.length;) {
        var rangeA = rA[iA],
          rangeB = rB[iB];
        if (rangeA && rangeB && sameRanges(rangeA, rangeB, map)) {
          iA++;
          iB++;
        } else if (rangeB && (!rangeA || map(rangeA.fromB) >= rangeB.fromB)) {
          add(rangeB.fromB, rangeB.toB);
          iB++;
        } else {
          add(map(rangeA.fromB), map(rangeA.toB));
          iA++;
        }
      }
      return from <= to ? {
        from: from,
        to: to
      } : null;
    }
  }], [{
    key: "create",
    value: function create(doc) {
      var combine = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : function (a, b) {
        return a === b ? a : null;
      };
      var tokenEncoder = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : DefaultEncoder;
      return new ChangeSet({
        combine: combine,
        doc: doc,
        encoder: tokenEncoder
      }, []);
    }
  }]);
  return ChangeSet;
}();
ChangeSet.computeDiff = computeDiff;
function mergeAll(ranges, combine) {
  var start = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 0;
  var end = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : ranges.length;
  if (end == start + 1) return [ranges[start]];
  var mid = start + end >> 1;
  return Change.merge(mergeAll(ranges, combine, start, mid), mergeAll(ranges, combine, mid, end), combine);
}
function endRange(maps) {
  var from = 2e8,
    to = -2e8;
  for (var i = 0; i < maps.length; i++) {
    var map = maps[i];
    if (from != 2e8) {
      from = map.map(from, -1);
      to = map.map(to, 1);
    }
    map.forEach(function (_s, _e, start, end) {
      from = Math.min(from, start);
      to = Math.max(to, end);
    });
  }
  return from == 2e8 ? null : {
    from: from,
    to: to
  };
}
function touchedRange(maps) {
  var b = endRange(maps);
  if (!b) return null;
  var a = endRange(maps.map(function (m) {
    return m.invert();
  }).reverse());
  return {
    fromA: a.from,
    toA: a.to,
    fromB: b.from,
    toB: b.to
  };
}
function sameRanges(a, b, map) {
  return map(a.fromB) == b.fromB && map(a.toB) == b.toB && sameSpans(a.deleted, b.deleted) && sameSpans(a.inserted, b.inserted);
}
function sameSpans(a, b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) if (a[i].length != b[i].length || a[i].data !== b[i].data) return false;
  return true;
}
exports.Change = Change;
exports.ChangeSet = ChangeSet;
exports.Span = Span;
exports.simplifyChanges = simplifyChanges;
