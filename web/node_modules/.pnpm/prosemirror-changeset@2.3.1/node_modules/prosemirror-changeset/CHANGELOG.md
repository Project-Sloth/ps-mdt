## 2.3.1 (2025-05-28)

### Bug fixes

Improve diffing to not treat closing tokens of different node types as the same token.

## 2.3.0 (2025-05-05)

### New features

Change sets can now be passed a custom token encoder that controls the way changed content is diffed.

## 2.2.1 (2023-05-17)

### Bug fixes

Include CommonJS type declarations in the package to please new TypeScript resolution settings.

## 2.2.0 (2022-05-30)

### New features

Include TypeScript type declarations.

## 2.1.2 (2019-11-20)

### Bug fixes

Rename ES module files to use a .js extension, since Webpack gets confused by .mjs

## 2.1.1 (2019-11-19)

### Bug fixes

The file referred to in the package's `module` field now is compiled down to ES5.

## 2.1.0 (2019-11-08)

### New features

Add a `module` field to package json file.

## 2.0.4 (2019-03-12)

### Bug fixes

Fixes an issue where steps that cause multiple changed ranges (such as `ReplaceAroundStep`) would cause invalid change sets.

Fix a bug in incremental change set updates that would cause incorrect results in a number of cases.

## 2.0.3 (2019-01-09)

### Bug fixes

Make `simplifyChanges` merge adjacent simplified changes (which can occur when a word boundary is inserted).

## 2.0.2 (2019-01-08)

### Bug fixes

Fix a bug in simplifyChanges that only occurred when the changes weren't at the start of the document.

## 2.0.1 (2019-01-07)

### Bug fixes

Fixes issue in `simplifyChanges` where it sometimes returned nonsense when the inspected text wasn't at the start of the document.

## 2.0.0 (2019-01-04)

### Bug fixes

Solves various cases where complicated edits could corrupt the set of changes due to the mapped positions of deletions not agreeing with the mapped positions of insertions.

### New features

Moves to a more efficient diffing algorithm (Meyers), so that large replacements can be accurately diffed using reasonable time and memory.

You can now find the original document given to a `ChangeSet` with its `startDoc` accessor.

### Breaking changes

The way change data is stored in `ChangeSet` objects works differently in this version. Instead of keeping deletions and insertions in separate arrays, the object holds an array of changes, which cover all the changed regions between the old and new document. Each change has start and end positions in both the old and the new document, and contains arrays of insertions and deletions within it.

This representation avoids a bunch of consistency problems that existed in the old approach, where keeping positions coherent in the deletion and insertion arrays was hard.

This means the `deletions` and `insertions` members in `ChangeSet` are gone, and instead there is a `changes` property which holds an array of `Change` objects. Each of these has `fromA` and `toA` properties indicating its extent in the old document, and `fromB` and `toB` properties pointing into the new document. Actual insertions and deletions are stored in `inserted` and `deleted` arrays in `Change` objects, which hold `{data, length}` objects, where the total length of deletions adds up to `toA - fromA`, and the total length of insertions to `toB - fromB`.

When creating a `ChangeSet` object, you no longer need to pass separate compare and combine callbacks. Instead, these are now represented using a single function that returns a combined data value or `null` when the values are not compatible.

## 1.2.1 (2018-11-15)

### Bug fixes

Properly apply the heuristics for ignoring short matches when diffing, and adjust those heuristics to more agressively weed out tiny matches in large changes.

## 1.2.0 (2018-11-08)

### New features

The new `changedRange` method can be used to compare two change sets and find out which range has changed.

## 1.1.0 (2018-11-07)

### New features

Add a new method, `ChangeSet.map` to update the data associated with changed ranges.

## 1.0.5 (2018-09-25)

### Bug fixes

Fix another issue where overlapping changes that can't be merged could produce a corrupt change set.

## 1.0.4 (2018-09-24)

### Bug fixes

Fixes an issue where `addSteps` could produce invalid change sets when a new step's deleted range overlapped with an incompatible previous deletion.

## 1.0.3 (2017-11-10)

### Bug fixes

Fix issue where deleting, inserting, and deleting the same content would lead to an inconsistent change set.

## 1.0.2 (2017-10-19)

### Bug fixes

Fix a bug that caused `addSteps` to break when merging two insertions into a single deletion.

## 1.0.1 (2017-10-18)

### Bug fixes

Fix crash in `ChangeSet.addSteps`.

## 1.0.0 (2017-10-13)

First stable release.
