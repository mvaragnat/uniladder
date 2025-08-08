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