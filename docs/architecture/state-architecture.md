# State architecture

- work_id: WK-20260803-gh-19-riverpod-feature-boundaries
- date: 2026-08-03

## Top-level layers

`lib/` has three directories, and the dependency direction between them is
one-way:

- `app/`: the composition root — the root widget, the router, the shell, and
  the routes only they own. It may import `core/` and any feature's
  `presentation/` layer.
- `core/`: shared contracts and cross-feature building blocks — the design
  system, route paths, destinations, shared presentation widgets. It imports
  neither `app/` nor a feature.
- `features/`: one directory per feature, each with the layers below. A feature
  imports its own layers and `core/`, never `app/` and never another feature.

`lib/main.dart` is only the process entry point: it calls `runApp` on the root
widget in `app/` and holds nothing else, so everything worth testing is
reachable from a test.

**This direction is enforced, not merely documented.**
`test/architecture/layer_boundaries_test.dart` reads every import in `lib/` and
fails on any `features/` or `core/` file that reaches `app/`, and on any feature
that imports another feature — relative and `package:` spellings alike, resolved
by path rather than by how they are written. Until 2026-08-06 the rule lived only
in the paragraph above, which meant the next screen could invert it and merge
green. That is why `AppRoutes` and `AppDestination` stayed in
`core/navigation/`: moving them to `app/` would make four feature screens import
the composition root, and the test now says so out loud.

## Feature boundary

Each feature owns three layers:

- `domain/`: models and repository interfaces used by the feature.
- `data/`: adapters that implement those interfaces, including local mocks.
- `presentation/`: Riverpod providers and widgets for that feature.

A feature may import its own layers and `lib/core/`; it must not import another
feature's `presentation/` layer.

## State convention

Async feature state is exposed as `AsyncValue<T>` by a provider. Presentation
uses `AsyncStateView<T>` so loading, data, and error states remain consistent.

## Injectable repository convention

Every repository provider is typed as the feature's domain interface and has a
local mock as its default. Tests and future runtime composition override that
provider; widgets only watch the feature state provider.
