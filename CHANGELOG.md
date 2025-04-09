# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.32.0 - March 11, 2025 (General Availability)
### Added
- Implemented model picker for selecting LLM model in chat
- Introduced new `/releaseNotes` slash command for accessing release information

### Changed
- Improved focus handling with automatic switching between chat text field and file search bar
- Enhanced keyboard navigation support for file picker in chat context
- Refined instructions for granting accessibility and extension permissions
- Enhanced accessibility compliance for the chat window
- Redesigned notification and status bar menu styles for better usability

### Fixed
- Resolved compatibility issues with macOS 12/13/14
- Fixed handling of invalid workspace switch event '/'
- Corrected chat attachment file picker to respect workspace scope
- Improved icon display consistency across different themes
- Added support for previously unsupported file types (.md, .txt) in attachments
- Adjusted incorrect margins in chat window UI

## 0.31.0 - February 11, 2025 (Public Preview)
### Added
- Added Copilot Chat support
- Added GitHub Freeplan support
- Implemented conversation and chat history management across multiple Xcode instances
- Introduced multi-file context support for comprehensive code understanding
- Added slash commands for specialized operations
