# Testing

## Unit Tests

Current tests cover:

- squarified treemap bounds behavior
- small item grouping
- treemap hit testing
- scanner aggregation and options
- package and symlink behavior
- deletion safety policy basics

Run:

```sh
./Scripts/test.sh
```

Scanner tests use temporary fixture directories and do not scan the contributor's home directory. Permission-denied behavior is skipped when the local filesystem still permits reading the chmod-restricted fixture.

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

## Benchmark Smoke Test

```sh
./Scripts/benchmark-scanner.sh
```

This runs the `SpatiaBenchmarks` executable target and emits JSON rows for synthetic scanner fixtures. It is intended as a lightweight local regression signal before broader profiling exists.
