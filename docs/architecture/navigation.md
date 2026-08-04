# Navigation and routing

- work_id: WK-20260803-gh-18-configure-primary-navigation
- date: 2026-08-03

## Shell

`GoRouter` drives navigation. `StatefulShellRoute.indexedStack` hosts one branch
per primary destination, and `AppShell` frames all of them.

The shell owns two things that must exist on every destination:

- the `NavigationBar` with the four primary destinations;
- the Decisions entry point.

Both live in the shell rather than in each screen, so a new destination cannot
be added without them and no screen has to remember to include them.

## Destinations

`AppDestination` (`lib/core/navigation/app_destinations.dart`) is the single
source of truth for a destination's path, label, and icon. The router builds one
branch per enum value and the navigation bar renders the same list in the same
order, so a branch index and a bar index cannot drift apart.

The four primary destinations are Projects, Work, Conversations, and Account.

## Route paths

Every path is declared in `AppRoutes` (`lib/core/navigation/app_routes.dart`).
Screens and tests navigate through those constants — or through
`AppDestination.detailPath` — and never spell a location by hand.

- `/<destination>` — the destination root.
- `/<destination>/detail` — a route nested inside that destination's own
  navigator; it exists so each destination has real navigation state.
- `/decisions` — hosted above the shell on the root navigator, so it covers the
  navigation bar instead of becoming a fifth destination.

## State preservation

Each `StatefulShellBranch` carries its own navigator key, so a destination's
route stack stays alive while another destination is on screen. Switching
destinations calls `goBranch(index, initialLocation: index == currentIndex)`:
selecting another destination restores its stack, and re-selecting the current
one returns it to its root.

This is the failure mode the shell has to defend against: a shell that rebuilds
its subtree on every destination change silently loses state and still looks
like normal navigation. `test/app/app_router_test.dart` asserts a pushed detail
route survives a round trip through another destination.

## Deep links

Deep linking is handled at the router level: `createAppRouter(initialLocation:)`
resolves any declared path — including a nested one — to the matching
destination with the shell intact.

OS-level registration (Android App Links, custom URL schemes) is **not**
configured. It needs domain verification and manifest intent filters, and is a
separate, explicitly gated change.

## Composition root

`lib/app/app_router.dart` is the navigation composition root and the only file
allowed to import a feature's `presentation/` layer. Features keep the boundary
described in [state-architecture.md](state-architecture.md): they import their
own layers and `lib/core/`, never another feature and never `lib/app/`.

That last direction is why `AppRoutes` and `AppDestination` stay in
`lib/core/navigation/` while the router, the shell, and the detail screen live
in `lib/app/`: feature screens read a destination's path to navigate, so moving
those two files into `lib/app/` would make every feature depend on the
composition root.

The router creates its navigator keys per call, so two routers can coexist —
for example across tests in one file — without sharing a `GlobalKey`.
