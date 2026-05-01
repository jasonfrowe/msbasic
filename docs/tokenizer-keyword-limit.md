# Tokenizer Keyword Table Limit (Hard Limit)

Date: 2026-05-01

## Summary

There is a hard parser limit in the keyword-name table (`TOKEN_NAME_TABLE`):

- Maximum size: 256 bytes total (including trailing `0` terminator)
- If exceeded: tokenizer can wrap index `Y` and hang while parsing

This is independent of available token IDs (`$80..$FF`) and independent of ROM free space.

## Root Cause

In `src/program.s`, the keyword scan path indexes keyword bytes using an 8-bit `Y` register only:

- `L24DB`: `lda MATHTBL+28+1,y`
- then `lda TOKEN_NAME_TABLE,y`

`Y` is 8-bit, so addressing wraps at 256.

When `TOKEN_NAME_TABLE` grows beyond 256 bytes, the end-of-table terminator can become unreachable by monotonic `Y` progression, causing incorrect scan behavior and runtime hangs (observed as `PRINT "HELLO"` hang in direct mode).

## Confirmed Repro

- Build without `SFX` top-level keyword: BASIC works
- Add one new keyword (`SFX`): BASIC hangs even on `PRINT "HELLO"`
- Mapping and handler-address checks were valid; failure was parser table size overflow

Measured keyword table totals:

- Without `SFX`: 256 bytes total (at limit)
- With `SFX`: 259 bytes total (overflow by 3)

## Guardrail Added

A build-time assertion was added in `src/token.s`:

```asm
.assert (*-TOKEN_NAME_TABLE) <= $100, error, "TOKEN_NAME_TABLE exceeds 256-byte parser limit"
```

This prevents creating a ROM that boots but hangs at runtime due to tokenizer overflow.

## Practical Implications

- Adding any keyword text now requires byte budgeting
- Every character in every keyword matters
- To add `SFX`, reclaim at least 3 keyword bytes first (or refactor tokenizer)

## Future Refactor Option

A robust fix is to rewrite keyword scanning in `src/program.s` to use a 16-bit pointer for table traversal instead of relying on 8-bit `Y` indexing.

That would remove this 256-byte keyword table ceiling.
