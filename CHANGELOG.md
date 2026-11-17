# Beast Training Tracker 1.5.1

### Fixed
- Taint errors when entering dungeons with many nameplates ("attempted to index a table that cannot be indexed with secret keys"). Event handlers for nameplate alerts now wrapped in pcall to safely handle WoW's security restrictions.
- Missing RareData.lua file error on source installs. Added stub file to prevent load errors.

### Added
- Auto-disable on non-hunter characters. When logging in on a non-hunter, the addon will disable itself with a notification message, freeing up resources and preventing errors.
