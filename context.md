# Uniladder

## Overview
Uniladder is a game tracking and ranking app. Players can track their games and see their rankings across different game systems.

## Core Models

### User (Player)
- Represents a player in the system
- Has many game events (participations)

### Game::System
- Represents a game system (e.g., Chess, Go, Magic: The Gathering)
- Has many game events
- Has many players through game events

### Game::Event
- Represents a single game played
- Belongs to a game system
- Has many players (through participations)
- Tracks the outcome of the game

### Tournament Domain
- `Tournament::Tournament`
  - Root entity for a competition. Attributes: `name`, `description`, `creator_id`, `game_system_id`, `format` (open|swiss|elimination), `rounds_count` (for Swiss), `starts_at`, `ends_at`, `state` (draft|registration|running|completed), `settings`.
  - Associations: `has_many :registrations` (participants), `has_many :rounds`, `has_many :matches`.
- `Tournament::Registration`
  - Join between a `Tournament::Tournament` and a `User` with optional `seed` (Elo snapshot) and `status` (`pending|approved|checked_in`).
  - Unique per (tournament, user).
- `Tournament::Round`
  - Represents a numbered round within a tournament (`number`, `state`), mainly used by Swiss/Open formats.
  - `has_many :matches` in that round.
- `Tournament::Match`
  - The scheduled pairing inside a tournament; optional link to a `Game::Event` when reported.
  - Attributes: `a_user_id`, `b_user_id`, `result` (`a_win|b_win|draw|pending`), optional `tournament_round_id` (for Swiss/Open), and for elimination only: `parent_match_id`, `child_slot`.

## Features

### Authentication & User Management
- User registration with email and password
- Login/logout functionality
- Password reset capability
- Session management for logged-in users

### Game Management
- Create new games with multiple participants
- Real-time player search by username
- Track game results (win/loss/draw)
- Associate games with specific game systems
- Display game history with participants and results
- Use ViewComponent for modular game display
- Exactly two players are required for each game (current user + one opponent). Front-end prevents submission and back-end validates this rule.

### Tournaments
- Create and browse tournaments by game system and format (open, swiss, elimination)
- Register/unregister and check-in to tournaments
- View tournament rounds and matches; update match results
- Admin actions for the tournament creator: lock registration, generate pairings, close round, finalize
- Tournament games integrate with Elo the same way as casual games

#### Elimination Bracket (current)
- On lock, elimination tournaments generate a full bracket tree using `Tournament::BracketBuilder` (Elo-based seeding, power-of-two sizing, byes to top seeds).
- Tree is modeled via `Tournament::Match` with `parent_match_id` and `child_slot`.
- Bracket UI renders from the tree; “Open” link appears only when both players are assigned and the viewer is a participant or the organizer.

#### Swiss/Open Tournaments (current)
- Rounds progress via a single “Move to next round” action that closes the current round, validates all matches are reported, and creates next-round pairings (placeholder pairing: checked-in players or all registrants, deterministic pairing by twos). 
- Rounds tab lists compact match boxes (same design as elimination); “Open” is visible to organizer and participants. Reporting creates a `Game::Event`, highlights the winner, and redirects back to the Rounds tab.
- Ranking tab shows simple standings (win=1, draw=0.5); Swiss-specific tie-breakers will be added later (e.g., Buchholz, Sonneborn–Berger).

### Internationalization
- Full support for multiple languages
- English and French translations available
- Language selection via UI

### Technical Features
- Modern Rails 8.0.1 application
- RuboCop code style enforcement
- Comprehensive test coverage
- Environment variables configuration
- Hotwire for dynamic interactions
- Stimulus for JavaScript functionality
- Responsive design with Tailwind CSS 