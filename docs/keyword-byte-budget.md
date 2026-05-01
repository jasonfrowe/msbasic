# Keyword Byte Budget (For Re-adding SFX)

Date: 2026-05-01

## Target

Need to reclaim at least 3 keyword-name bytes to add top-level `SFX`.

Reason:

- Current table (without SFX): 256 bytes (full)
- `SFX` adds 3 bytes
- New total would be 259 -> overflow

## Byte Accounting Rule

Keyword table cost is approximately:

- Sum of all keyword string lengths
- plus one final `0` byte terminator

Each additional keyword character consumes one byte permanently.

## Candidate Reclamation Ideas

These are examples to evaluate, not final decisions:

1. Remove one low-priority/custom keyword with length >= 3
- Example: remove `CAPS` (4 bytes reclaimed)

2. Shorten one long custom keyword
- Example: `CLEAR` -> `CLR` (2 bytes reclaimed)
- Needs one extra 1-byte save elsewhere to reach 3 total

3. Remove/disable one reserved parser-only keyword pending later reintroduction
- Depends on compatibility goals and roadmap

## Compatibility Notes

- Removing/renaming a keyword changes source compatibility for programs using it
- Prefer reclaiming bytes from custom or low-usage additions before core BASIC terms

## Recommendation

For minimal risk and fastest SFX enablement:

- Reclaim 3+ bytes from custom extensions first
- Keep core Microsoft BASIC vocabulary stable

After SFX is enabled, maintain a running byte budget whenever adding new keywords.
