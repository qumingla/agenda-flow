# Changelog

## 0.1.0-beta - 2026-06-27

### Added

- Created the iOS beta project under `apps/ios`.
- Added SwiftUI tab navigation for Capture, Inbox, Review, Calendar, and Settings.
- Added SwiftData models for raw inputs, preprocessing results, candidate events, calendar events, dynamic fields, and LLM traces.
- Added local text capture, clipboard parsing, image import, Apple Vision OCR, local rule-based MockLLM extraction, review editing, dynamic fields, planning validation, built-in calendar events, and local notification scheduling.
- Added Liquid Glass styling through iOS 26 `glassEffect`, with material fallback for older iOS.
- Added a temporary App icon and AgendaFlow display name.
- Added OpenAI-compatible LLM Provider settings, Keychain API Key storage, `/models` connection testing, manual model selection, cloud extraction, trace metadata, and local fallback.
- Added product, architecture, data model, LLM, privacy, and development documentation.
- Added JSON Schemas and prompt templates for future real LLM provider integration.

### Known Gaps

- Share Extension, EventKit sync, ASR, App Intents, and CloudKit are documented but not implemented in this beta.
