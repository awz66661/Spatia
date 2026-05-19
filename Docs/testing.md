# Testing

## Unit Tests

Current tests cover:

- squarified treemap bounds behavior
- small item grouping
- deletion safety policy basics

Run:

```sh
./Scripts/test.sh
```

## Required Test Areas

Scanner:

- size aggregation
- unreadable directories
- packages as opaque nodes
- symlink handling
- hidden files
- max-depth scans

Treemap:

- area conservation
- no negative dimensions
- small file grouping
- deterministic ordering
- hit testing

Actions:

- system path blocking
- user Library blocking
- cache warning
- package warning
- Move to Trash confirmation flow

## Fixture Plan

Synthetic fixture directories should be generated under a temporary location:

```text
TestData/
├─ HugeFiles/
├─ ManySmallFiles/
├─ DeepNestedFolders/
├─ Packages/
├─ Symlinks/
├─ PermissionDenied/
└─ SparseFiles/
```

Do not rely on a contributor's real home directory for scanner tests.
