# Tournaments Feature - Design

## Domain & Naming

We use a domain namespace mirroring the existing `Game::` domain. The tournament models live under `Tournament::`:

- `Tournament::Tournament` (the tournament entity)
- `Tournament::Registration` (player signup/seed)
- `Tournament::Round` (Swiss/elimination rounds)
- `Tournament::Match` (scheduled pairing or bracket node)

Tournament services live under `app/services/tournament/`.

## What each model represents

- `Tournament::Match`: the scheduled pairing inside a tournament (who plays whom, in which round/bracket node, status/result). It is the canonical source for tournament structure and standings logic.
- `Game::Event`: the actual game played (participants/scores/timestamp/system). It is the canonical source for results, audit/history, and Elo updates.

### Connection between Match and Event

- `Tournament::Match` has an optional `game_event_id`. On result input, we create (or link) a `Game::Event` with `tournament_id` and assign it to the match, then derive `result` (a_win/b_win/draw) and `reported_at`.
- `Game::Event` has `tournament_id` (nullable), so tournament games are distinguishable from casual games and update Elo identically.

Special cases:
- Open tournaments: events can be recorded without a pre-existing match; the `Game::Event` simply carries `tournament_id`, and standings sum points from these events.
- Swiss/elimination: matches are pre-defined by pairing/bracket; exactly one event should be linked per match (enforced by app logic).

## Architecture Plan

### Goal
Add per-tournament competition with three formats, using Elo seeding and updating Elo after tournament games.

### Data model (new/changed)
- `tournaments`
  - `name`, `description`, `creator_id`, `game_system_id`, `format` (open|swiss|elimination), `rounds_count` (Swiss), `starts_at`, `ends_at`, `state` (draft|registration|running|completed), `settings` (JSONB), `slug`
- `tournament_registrations`
  - `tournament_id`, `user_id`, `seed` (Elo snapshot), `status` (pending|approved|checked_in)
- `tournament_rounds`
  - `tournament_id`, `number`, `state`, `paired_at`, `locked_at`
- `tournament_matches`
  - `tournament_id`, `tournament_round_id` (nullable), `a_user_id`, `b_user_id`, `result` (a_win|b_win|draw|pending), `reported_at`, `game_event_id`, optional bracket metadata
- `game_events`
  - add `tournament_id`

### Permissions
- Creator/admins: manage registration, seed/lock, generate pairings/bracket, resolve results, finalize.
- Players: register, check-in, report results (with confirmation).
- Public: view standings/rounds/bracket.

### Workflows
- **Open**: free play among participants; standings = sum(1/0.5/0). Events carry `tournament_id`.
- **Swiss**: fixed rounds; SwissPairingService pairings each round per [Swiss rules](https://en.wikipedia.org/wiki/Swiss-system_tournament); standings with tiebreaks.
- **Elimination**: bracket seeded by Elo; winners advance.

Elo:
- Seeding uses `EloRating` for the tournament’s `game_system_id`.
- Tournament games call existing Elo pipeline via `Game::Event` → `EloUpdateJob`.

### Pages (to build in later phases)
- Index, Show (Overview/Registration/Standings/Rounds/Bracket/Matches/Admin), result reporting modal.

### Services
- `Tournament::SeedingService` (seed from Elo)
- `Tournament::StandingsService` (format-aware)
- `Tournament::SwissPairingService` (pairing rules)
- `Tournament::BracketService` (tree generation/advance)

### Testing
- Services: Swiss pairing (no repeats, same-score), bracket progression, standings per format.
- Integration: registration → seed → pairings → result reporting → standings; bracket seeding and advancement; tournament games update Elo.
- Concurrency: pairing/advance idempotency, locking.

### Rollout
1. Phase 1: models/migrations/services skeletons; Open format minimal admin UI.
2. Phase 2: Swiss pairing + standings.
3. Phase 3: Elimination bracket + UI.
4. Phase 4: polish, exports, tiebreak options.

---

## Elimination Bracket (Implemented)

### Overview
- Bracket is generated at lock for elimination tournaments.
- We model the bracket as a tree: `Tournament::Match` nodes with `parent_match_id` and `child_slot` (`a` or `b`).
- Leaf matches correspond to the first round; internal nodes represent future rounds up to the final (root with no parent).
- Matches linked to rounds are reserved for Swiss/Open; elimination tree uses `tournament_round_id: nil`.

### Seeding
- Seeds are computed from `EloRating` for the tournament’s game system; missing ratings default to `EloRating::START_RATING`.
- We place seeds according to standard single-elimination positions for a power-of-two bracket size.
- If participants < power-of-two, byes are assigned to higher seeds.

### Service
- `Tournament::BracketBuilder` (app/services/tournament/bracket_builder.rb):
  - `#call` seeds players, computes power-of-two size, assigns positions, creates leaf matches, builds parent matches, and propagates byes upward.
  - Idempotent per lock transaction (assumes empty tree on first lock).

### Bye Propagation
- If a leaf has one player (bye), that player is assigned to the appropriate side of the parent node, advancing automatically.

### UI
- The Bracket tab renders an SVG from the tree, not rounds.
- Boxes show player names or `TBD`, and scores if reported.
- The “Open” link appears only when both players are present and the current user is a participant (or organizer).

### Tests
- `test/services/tournament/bracket_builder_test.rb` verifies:
  - For 5 players → 8-slot bracket: 4 leaf matches, 7 total matches, 3 byes, highest Elo receives a bye and advances.
  - For 16 players → full bracket: 15 total matches, 8 leaves, no byes.
  - For 33 players → 64-slot bracket: 63 matches, 32 leaves, 31 byes, and highest Elo receives a bye and advances.

### Future Work
- Seeding options (custom/manual, randomization, snake seeding).
- Persist snapshot of Elo seed on registration to keep historical seeding basis.
- Auto-advance parent node when a match result is reported.
- Bracket export, seed labels on nodes, better connectors and responsive layout. 