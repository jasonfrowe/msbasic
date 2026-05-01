# Audio Parser Contract v1 (PSG-first)

Status: Draft for implementation on branch `music`.
Goal: Define exact syntax, ranges, and behavior for first-pass audio commands.

## Scope

This contract defines parser-level behavior for these statements:

- `SFX id[,voice]`
- `SFXSTOP`
- `SFXVOL n`
- `SFXBANK n`
- `SFXSTATUS`
- `TEMPO bpm`
- `VOICE v,inst`
- `NOTE v,pitch,dur[,vel]`

This version intentionally excludes `PLAY`, `REST`, `TIMER`, and `WAIT`.

## General Parser Rules

1. Commands are statement-level keywords and must be valid in direct mode and program mode.
2. Numeric arguments use existing BASIC numeric evaluation flow, then are range-checked as integers.
3. Fractional numeric results are accepted only if exact integer after conversion; otherwise `?ILLEGAL QUANTITY ERROR`.
4. Missing required separators (`,`), arguments, or trailing garbage produce `?SYNTAX ERROR`.
5. Out-of-range values produce `?ILLEGAL QUANTITY ERROR`.
6. On any parse/runtime audio error, interpreter stability must be preserved (no token-stream desync).

## Command Grammar and Ranges

Notation:

- `u8` means integer 0..255
- `u16` means integer 0..65535
- `voice` in v1 is PSG voice index 0..2

### SFX

Grammar:

- `SFX id`
- `SFX id,voice`

Arguments:

- `id`: u8 (effect id)
- `voice`: 0..2 (optional)

Behavior:

- If `voice` omitted, runtime picks a voice by current allocator policy.
- Starts one-shot effect playback from current `SFXBANK`.
- Starting a new SFX on an already-active voice replaces existing content on that voice.

### SFXSTOP

Grammar:

- `SFXSTOP`

Behavior:

- Immediate all-voices off for audio engine.
- Clears active SFX/music envelopes and pending note holds.

### SFXVOL

Grammar:

- `SFXVOL n`

Arguments:

- `n`: u8 global master volume scale for SFX lane.

Behavior:

- Applies to subsequent SFX starts.
- Active voices may apply new scale immediately or next step; implementation choice must be deterministic.

### SFXBANK

Grammar:

- `SFXBANK n`

Arguments:

- `n`: u8 bank id

Behavior:

- Selects effect table bank for future `SFX` calls.
- Invalid/unimplemented bank values must throw `?ILLEGAL QUANTITY ERROR`.

### SFXSTATUS

Grammar:

- `SFXSTATUS`

Behavior:

- Prints compact status line(s) including at minimum: bank, volume, and active voice bitmap.
- Output format may evolve, but command must never mutate audio state.

### TEMPO

Grammar:

- `TEMPO bpm`

Arguments:

- `bpm`: 30..300

Behavior:

- Sets global music tempo used by `NOTE` duration conversion.
- Change takes effect for notes scheduled after the command.

### VOICE

Grammar:

- `VOICE v,inst`

Arguments:

- `v`: 0..2
- `inst`: u8 instrument id

Behavior:

- Sets per-voice instrument profile used by future `NOTE` on voice `v`.
- Invalid/unimplemented instrument ids raise `?ILLEGAL QUANTITY ERROR`.

### NOTE

Grammar:

- `NOTE v,pitch,dur`
- `NOTE v,pitch,dur,vel`

Arguments:

- `v`: 0..2
- `pitch`: 0..127 (MIDI-like index for v1)
- `dur`: 1..255 (musical ticks; conversion defined by runtime)
- `vel`: 0..15 (optional; defaults to current voice default)

Behavior:

- Starts note on voice `v` with auto-release scheduled by `dur`.
- New `NOTE` on same voice replaces currently sounding note on that voice.
- `dur` is mandatory in v1 to guarantee no hanging notes.

## Safety and Lifecycle Guarantees

1. No hanging notes after any of: `STOP`, `END`, `NEW`, `RUN`, Ctrl-C break, or interpreter error path.
2. `SFXSTOP` is idempotent and safe to call repeatedly.
3. Warm restart leaves audio in silent, known baseline.

## Tick/Timing Contract (v1)

1. Runtime maintains a monotonic audio tick source.
2. `TEMPO` + `dur` map to expiry tick using deterministic integer math.
3. Timing precision target is stable behavior, not cycle-perfect music sequencing.

## Parser Acceptance Tests

Each line below must pass/fail exactly as indicated.

Should pass:

- `SFX 1`
- `SFX 1,2`
- `SFXSTOP`
- `SFXVOL 128`
- `SFXBANK 0`
- `SFXSTATUS`
- `TEMPO 120`
- `VOICE 0,1`
- `NOTE 1,69,24`
- `NOTE 2,72,12,10`

Should fail with `?SYNTAX ERROR`:

- `SFX`
- `SFX 1,`
- `SFXVOL`
- `VOICE 1`
- `NOTE 0,60`
- `NOTE 0,60,12,`

Should fail with `?ILLEGAL QUANTITY ERROR`:

- `SFX -1`
- `SFX 1,3`
- `TEMPO 10`
- `VOICE 3,0`
- `NOTE 0,128,10`
- `NOTE 0,60,0`
- `NOTE 0,60,10,99`

## Implementation Notes

1. Keep parser changes local to new command handlers.
2. Do not modify global token fallback behavior.
3. Add runtime hooks for all-stop early, before richer synthesis features.
4. Add `PLAY` only after this contract is stable in both direct/program execution.
