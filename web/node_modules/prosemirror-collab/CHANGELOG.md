## 1.3.1 (2023-05-17)

### Bug fixes

Include CommonJS type declarations in the package to please new TypeScript resolution settings.

## 1.3.0 (2022-05-30)

### New features

Include TypeScript type declarations.

## 1.2.2 (2019-11-20)

### Bug fixes

Rename ES module files to use a .js extension, since Webpack gets confused by .mjs

## 1.2.1 (2019-11-19)

### Bug fixes

The file referred to in the package's `module` field now is compiled down to ES5.

## 1.2.0 (2019-11-08)

### New features

Add a `module` field to package json file.

## 1.1.2 (2019-05-29)

### Bug fixes

Fix an issue where in `mapSelectionBackward` mode, the plugin flipped the head and anchor of the selection, leading to selection glitches during collaborative editing.

## 1.1.1 (2018-10-09)

### Bug fixes

Fix issue where `mapSelectionBackward` didn't work because of a typo.

## 1.1.0 (2018-08-21)

### New features

[`receiveTransaction`](https://prosemirror.net/docs/ref/#collab.receiveTransaction) now supports a `mapSelectionBackward` option that makes it so that text selections are mapped to stay in place when remote changes insert content at their position.

## 0.19.0 (2017-03-16)

### New features

You can now use strings (as well as numbers) as client IDs (this already worked, but now the documentation reflects this).

## 0.18.0 (2017-02-24)

### New features

[`sendableSteps`](https://prosemirror.net/docs/ref/version/0.18.0.html#collab.sendableSteps) now also returns information about the original transactions that produced the steps.

## 0.11.0 (2016-09-21)

### Breaking changes

Moved into a separate module.

Interface [adjusted](https://prosemirror.net/docs/ref/version/0.11.0.html#collab) to work with the new
[plugin](https://prosemirror.net/docs/ref/version/0.11.0.html#state.Plugin) system.

### New features

When receiving changes, the module now
[generates](https://prosemirror.net/docs/ref/version/0.11.0.html#collab.receiveAction) a regular
[transform action](https://prosemirror.net/docs/ref/version/0.11.0.html#state.TransformAction) instead of hard-setting
the editor's document. This solves problematic corner cases for code
keeping track of the document by listening to transform actions.

