# XRAM Map (Draft)

Date: 2026-05-01

Purpose: central allocation guide for shared XRAM regions used by BASIC features.

## XRAM Limits

- XRAM range: 0x0000..0xFFFF (64 KB)
- Keep multi-byte structures aligned where required by device docs
- PSG config block must not cross a page boundary

## Current Allocations

### Graphics framebuffer base

- Base: 0x0000
- 320x240 @ 4bpp footprint: 320 * 240 / 2 = 38,400 bytes = 0x9600
  - Range used: 0x0000..0x95FF
- 320x180 @ 8bpp footprint: 320 * 180 = 57,600 bytes = 0xE100
  - Range used: 0x0000..0xE0FF

### Audio PSG config block

- Base: 0xFD00
- Size: 64 bytes (8 voices * 8 bytes)
- Range used: 0xFD00..0xFD3F
- Current code: src/audio.s (AUDIO_PSG_ADDR := $FD00)

### Graphics mode3 config struct

- Base: 0xFF00
- Used by graphics setup code and consumed by VGA mode3 path
- Current code: src/graphics.s (GFX_CFG_ADDR := $FF00)

## Free / Planned Regions (proposed)

These are suggestions to avoid collisions while features are added.

- 0xE100..0xFCFF: general feature pool (safe above worst-case framebuffer)
- 0xFD00..0xFD3F: reserved PSG config
- 0xFD40..0xFEFF: audio expansion (music tracks, SFX tables, envelopes)
- 0xFF00..0xFFFF: graphics config / high-priority control structs

## Candidate Future Reservations

- Gamepad mirror block (RIA keyboard/mouse/gamepad xreg mappings):
  - Suggest start at 0xF800 (40+ bytes needed for 4 pads, plus growth)
- Keyboard map mirror:
  - Suggest 0xF840 (32 bytes)
- Mouse struct mirror:
  - Suggest 0xF860 (5 bytes)

## Rules of Thumb

- Do not place long-lived feature state below 0xE100 if 320x180 8bpp may be active.
- Keep per-device config blocks grouped and documented with base + size.
- Any new xreg-backed feature should update this file in the same commit.
