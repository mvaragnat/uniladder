# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] 

### Added
- Initial Rails project setup with Ruby 3.4.1 and Rails 8.0.1 
- Added RuboCop for code style enforcement 
- Added Kamal 2 deployment configuration => not used
- Created basic landing page with project title "Uniladder"
- Added environment variables configuration system
- Added Docker installation instructions for deployment => not used
- Added core models (User, Game::System, Game::Event) with migrations
- Added basic model and controller tests
- Added authentication system with login functionality
- Added user registration functionality
- Added game creation functionality with player search and modal form
- Added game history display on dashboard with ViewComponent
- Added ViewComponent gem for modular view components

### Changed
- Enforced presence validation for `Game::Participation.result` to prevent saving participations without a result and align with tests
- Updated `Game::EventsController` strong params to require `:event` (was `:game_event`) to match controller tests
- Enforced exactly two players per game at the model level; added distinct-players validation and auto-completion of opponent result
- Added Stimulus `game-form` validation to block submission unless exactly one opponent is selected; added localized error message in EN/FR
- Updated controller and system tests to cover no-players and exactly-two-players scenarios; added i18n messages for success and errors