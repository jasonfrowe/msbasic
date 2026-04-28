# Microsoft BASIC for the Picocomputer 6502

 - `INSTALL basic.rp6502` then `HELP basic` for usage.
 - `INFO basic.rp6502` for usage without installing.

Original source: https://github.com/microsoft/BASIC-M6502
Ported to cc65: https://github.com/mist64/msbasic

The mist64/msbasic project is designed to build byte-exact images
matching the ROMs in classic 6502 computers. We want to enhance
BASIC for the Picocomputer 6502 so the ability to merge our changes
upstream isn't needed. Many files were heavily modified to remove
the ifdef noise and enable the linker to manage memory. Files in
`src/mist64` could be used without modification.

## Graphics demos

Canonical `GFX` command style uses word-form subcommands (`GFX MODE`, `GFX CLEAR`, etc.).
Single-letter forms are kept only as compatibility aliases.

Example programs are in `examples/`:

- `graphics-smoke.bas` - quick primitive test with `GFX HLINE`, `GFX VLINE`, `GFX RECT`, and `GFX PSET`.
- `mandelbrot240.bas` - Mandelbrot render in `GFX MODE,240`.
- `mandelbrot180.bas` - Mandelbrot render in `GFX MODE,180`.
- `gfx-api.bas` - concise API tour for mode/layer/clear/reset behavior.
