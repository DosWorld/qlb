# QLB - QuickBASIC Quick Library (.QLB) format

This folder is the result of reverse engineering of the **Quick
Library** format of Microsoft QuickBASIC 4.0 / 4.5: the file
format, how QuickBASIC loads a library, how it calls into it,
and how to write one. Everything is written down, checked
against the real QuickBASIC 4.50 and 4.0 and against Microsoft's
own `QB.QLB`, and released into the **public domain**
(Unlicense, `(c) DosWorld 2026`). Use it for anything, without
conditions.

## What is a .QLB?

A Quick Library is the file that QuickBASIC loads with `QB /L
name.QLB`. It contains compiled routines (assembler, C, anything
that produces `.OBJ`) that a BASIC program in the QuickBASIC
editor can then `CALL`. Without it the QuickBASIC *interpreter*
can only run BASIC: no interrupts, no absolute addresses, no
hand-written inner loops, no hardware access. With it a program
can do `CALL INTERRUPT(...)`, `CALL ABSOLUTE(...)` (that is the
library `QB.QLB` that ships with QuickBASIC) or call your own
routines.

Technically it is a **DOS MZ executable that nobody runs**, used
as a container: code image, data, a symbol block with name
tables, and an MZ relocation table. QuickBASIC maps the pieces
into memory, relocates them, and then talks to the library
through a small table of far pointers (a dispatcher with a *life
cycle*: load, init, find a routine by name, terminate).

```
QB /L MYLIB.QLB /RUN PROG.BAS
```

```basic
DECLARE FUNCTION SUMI% (a AS INTEGER, b AS INTEGER)
PRINT SUMI%(1000, 234)     ' assembler routine from MYLIB.QLB
```

## How useful is it for DOS software?

* **For QuickBASIC 4.x programmers: essential.** It is the only
  way to extend the editor/interpreter. Anything that needs a
  DOS or BIOS call, a port, a TSR, speed, graphics or a hardware
  driver goes through a Quick Library. The same assembler
  routines can also be linked into a compiled `.EXE` (as
  `.OBJ`), so a library is a convenient way to develop them.
  With the documentation here you can write libraries with NASM
  and the free RTools linker (`rlink qlb`) and need neither
  Microsoft `LINK` nor `BQLB45.LIB`.
* **For other DOS programs: a small, ready-made plug-in format**
  - useful, but niche. A `.QLB` is a relocatable module with
  named exports, its own data segment, a list of relocations and
  life-cycle hooks, loadable **without `EXEC`**, at any address,
  by a small 8086 assembler loader (`ALOADER\ALOADER.ASM`). You
  can use it as an overlay, plug-in, driver or script-extension
  container for your own DOS software, and any QuickBASIC 4.x
  user can load the same file. Its limits: one 64 KB data
  segment laid out for QuickBASIC 4.5, no import table (a
  library can take only what QuickBASIC offers at fixed places),
  names found through a dispatcher, and RLINK and Microsoft
  `LINK /Q` as the only writers. If you do not care about
  QuickBASIC, a plain RDF or MZ overlay with your own loader is
  simpler.
* **For preservation**: the format was undocumented; now it is
  documented and checked by working code.

## The documents

* [`QLBFMT.MD`](QLBFMT.MD)
  - what it is: **The format specification.** File layout, MZ
    header, QB header, the three tables, memory model,
    relocation, the dispatcher and its selectors, the calling
    convention, imports, limits, QuickBASIC's refusal checklist,
    an annotated byte dump, assembler examples.
* [`QLBUSE.MD`](QLBUSE.MD)
  - what it is: **Consumer manual.** Part A: using a library
    from a QuickBASIC program (parameters, return values,
    errors, pitfalls). Part B: loading a library from your own
    DOS program: load, relocate, resolve exports and imports,
    phases with codes, call routines, unload - with the
    assembler code.
* [`QLBWRT.MD`](QLBWRT.MD)
  - what it is: **Writer guide.** Writing routines in NASM
    (stack frames for every parameter type, return values), the
    life cycle hook, imports, data, linking with `rlink qlb`,
    testing, hang checklist, writing a `.QLB` without RLINK.
* [`MSRT.LST`](MSRT.LST)
  - what it is: **Disassembly of the runtime that Microsoft's
    `LINK /Q` embeds** (dispatcher, `GETPROC`, service thunks,
    `Init`, `Term` ...), annotated, with the variables of
    QuickBASIC's data segment.

## The demos (built: `.QLB`, and `.EXE` for the loader)

* `QLOADER\`
  - content: A **QuickBASIC program calls a library written in
    NASM**, with parameters of every kind. `DEMO.ASM` (the
    library), `DEMO.QLB` (built), `DEMO.BAS` (the BASIC
    program), `MAKE.BAT`, `RUN.BAT`, `OUTPUT.TXT` (output of the
    run under QuickBASIC 4.50). It needs `QB.EXE` to run: a
    `.QLB` is not an `.EXE`.
* `ALOADER\`
  - content: A **DOS program in NASM that loads a `.QLB` and
    calls it**, playing the part of QuickBASIC, **with all the
    phases** (`06h`, `10h`, `00h`, `0Ah` per name, `00h`, `02h`,
    `04h`), the imports (`DS:00D3`, the gateway `DS:00BE/00C2`)
    and the calls. `ALOADER.ASM`, `ALOADER.EXE` (built),
    `DEMO.ASM`, `DEMO.QLB`, `MAKE.BAT`, `RUN.BAT`, `OUTPUT.TXT`
    (full run), `OUTLOAD.TXT` (`aloader QB.QLB /L`: Microsoft's
    own library passes every check).

Try it:

```
cd ALOADER
aloader DEMO.QLB              full run, no QuickBASIC needed
aloader C:\QB45\QB.QLB /L     load and check any library

cd ..\QLOADER
qb /l DEMO.QLB /run DEMO.BAS   same routines from BASIC
                              (needs QuickBASIC 4.5 or 4.0)
```

## RLINK and the QLB format

The linker `rlink qlb` of RTools follows these findings:

* **Imports.** A module may `extern` the names of QuickBASIC
  (`B$RUNERR`, `B$ERR_FC`, `b_errnum`, `b_ULSymSeg` ...); RLINK
  builds the thunks and data symbols itself (`DEMO.ASM` uses
  it).
* **Lookup.** Like Microsoft's runtime: `CDECL` names get the
  underscore, case is ignored, the temporary name string is
  freed (`QLBFMT.MD` section 12), and the CODE table lists the
  exported names.

## Rebuild

NASM **0.98.39** and the linker **RLINK** of
[RTools](https://github.com/DosWorld/rtools) (`BIN\NASM.EXE`,
`BIN\RLINK.EXE`), under MS-DOS or DOSBox-X:

```
nasm -s -f rdf DEMO.ASM
rlink qlb /o=DEMO.QLB DEMO.RDF
nasm -s -f rdf ALOADER.ASM
rlink mzs /o=ALOADER.EXE ALOADER.RDF
```

## Tested with

* QuickBASIC 4.50 and 4.0 (`QB.EXE`) for the file format and the
  life cycle; the demo programs of `QLOADER` under 4.50.
* Microsoft's `QB.QLB` of QuickBASIC 4.5: read and accepted by
  `ALOADER` (all checks); BASIC PDS 7.1 files were read only.
* QBasic (`QBASIC.EXE` of MS-DOS 5/6) has no `/L` option and
  does not load libraries.

## Known problems and open points

* Only **one** library can be loaded by QuickBASIC (`/L` twice
  prints the usage line); all modules have to be linked into
  one.
* Not examined: selectors `04h 08h 0Ch 0Eh` at run time, STRING
  function results, far data/BSS areas, QuickBASIC PDS at run
  time.
* `ALOADER` runs libraries made by RLINK; libraries made by
  `LINK /Q` are loaded and checked only.

## License

`(c) DosWorld 2026`. Public domain: the **Unlicense**, full text
in [`LICENSE.TXT`](LICENSE.TXT) and in the header of every
source file. Microsoft, QuickBASIC and MS-DOS are trademarks of
Microsoft Corporation.
