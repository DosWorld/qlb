# QLBWRT - Writing and linking a Quick Library (.QLB)

Writer guide. (c) DosWorld 2026, public domain (Unlicense, see
the end of this file).

How to write the routines of a library in NASM, how they receive
parameters and return values, how they take part in the life
cycle ("phases") and use what QuickBASIC provides ("imports"),
and how to link and test the result. All code is from
`QLOADER\DEMO.ASM`, which was built with the commands below and
run under QuickBASIC 4.50 (`QLOADER\`) and under the loader of
this folder (`ALOADER\`).

Read `QLBFMT.MD` for the definition of the file and `QLBUSE.MD`
for what the user of the library sees.

## 1. The tools

* NASM **0.98.39** (`BIN\NASM.EXE` of RTools)
  - what for: assembles `.ASM` to `.RDF`. Use `-s -f rdf`. Other
    NASM versions write RDF differently.
* `RLINK` (RTools)
  - what for: `rlink qlb /o=NAME.QLB A.RDF B.RDF`: the linker
    that writes the `.QLB`. Standalone: no Microsoft `LINK` and
    no `BQLB45.LIB` needed.
* QuickBASIC 4.0 or 4.5
  - what for: to run the library: `QB /L NAME.QLB /RUN
    PROG.BAS`.
* `ALOADER` (this folder)
  - what for: to run the routines **without QuickBASIC**, from a
    DOS program, with a trace of the life cycle.

The build of the demo (`ALOADER\MAKE.BAT`; `QLOADER\MAKE.BAT`
has the first two lines):

```bat
REM (c) DosWorld 2026
REM
REM This is free and unencumbered software released into the
REM public domain.
REM
REM Anyone is free to copy, modify, publish, use, compile, sell,
REM or distribute this software, either in source code form or
REM as a compiled binary, for any purpose, commercial or
REM non-commercial, and by any means.
REM
REM In jurisdictions that recognize copyright laws, the author
REM or authors of this software dedicate any and all copyright
REM interest in the software to the public domain. We make this
REM dedication for the benefit of the public at large and to the
REM detriment of our heirs and successors. We intend this
REM dedication to be an overt act of relinquishment in
REM perpetuity of all present and future rights to this software
REM under copyright law.
REM
REM THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
REM KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
REM WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
REM PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
REM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
REM IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
REM OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
REM OTHER DEALINGS IN THE SOFTWARE.
REM
REM For more information, please refer to
REM <https://unlicense.org>

@echo off
nasm -s -f rdf DEMO.ASM
rlink qlb /o=DEMO.QLB DEMO.RDF
nasm -s -f rdf ALOADER.ASM
rlink mzs /o=ALOADER.EXE ALOADER.RDF
```

Microsoft's way, for objects written in C or MASM, is `LINK /Q
yourlib.LIB,yourlib.QLB,NUL,BQLB45.LIB;`; its runtime comes from
`BQLB45.LIB` (`MSRT.LST`). This guide is about the RLINK way.

## 2. The shape of a library source

One or more NASM modules. RLINK links **every module on the
command line** (not only the ones that are reached from the
entry point), gives each its own code, data and bss segments,
and exports **every `global` symbol of a code segment** by name.
BASIC finds them by name (`CALL ADDONE`), case does not matter,
use `A-Z`, `0-9`, `_`.

The skeleton (the demo is the complete example):

```nasm
        bits 16
        cpu 8086
        global  start
        global  ADDONE
        segment .text
start:
        retf    2
ADDONE:
        retf    2
```

* `bits 16`, `cpu 8086`: the library runs in real mode under
  QuickBASIC; keep to the 8086 instruction set unless you know
  the machine.
* **`start`** (default name, change it with `/entry=name`) is
  the *entry procedure*: RLINK's runtime calls it for every
  life-cycle selector that it does not handle itself (section
  5). It is a Pascal-style far procedure and ends with `retf 2`.
  With nothing to do it is just `retf 2`.
* Every routine is called with `call far`, so it ends with
  `retf`, or `retf 2*n` if it has `n` words of arguments
  (sections 3 and 4).
* Exports are limited to about 2000-2500 names (`Too many
  symbols.`, `QLBFMT.MD` section 13); code, data and bss of one
  module to 64 KB each, the library as a whole may be larger
  (tested: 80 KB).

### 2.1 Names, underscores and CDECL

A routine in C style has an underscore in front of its name
(`_foo`). Two ways to reach it (rules in `QLBFMT.MD` section
12):

```basic
DECLARE FUNCTION foo% CDECL (BYVAL a%, BYVAL b%)
DECLARE FUNCTION foo2% ALIAS "_foo" (BYVAL a%, BYVAL b%)
```

`CDECL` makes the runtime look for `_foo`, and the routine is
called with the C convention: arguments pushed **right to
left**, so the first one is at `[bp+6]`, by reference unless
`BYVAL`; it returns with a plain `retf` because the caller
removes the arguments:

```nasm
_foo:
        push    bp
        mov     bp, sp
        mov     ax, [bp+6]
        sub     ax, [bp+8]
        pop     bp
        retf
```

(`foo(10, 3)` gives 7.) The second declaration reaches the same
symbol with the BASIC convention (`retf 2*n`, section 3). A
routine exported without the underscore (`FOO`) is declared
plainly, `DECLARE FUNCTION foo ()`. Do not use BASIC keywords
(`EXIT`, `OFF`, ...) as names of routines or parameters.

## 3. The stack frame of a routine

BASIC pushes the arguments **left to right** and the routine
removes them. After the usual prologue:

```
        push    bp
        mov     bp, sp

    [bp+0]    saved BP
    [bp+2]    return IP
    [bp+4]    return CS
    [bp+6]    the LAST argument (rightmost)
    [bp+8]    the one before it
    ...       argument i, counted from the right,
              is at [bp + 4 + 2*i]
```

So a routine with `n` words of arguments ends with `pop bp` and
`retf 2*n`. **Wrong `n` breaks the stack of QuickBASIC.** Keep
`BP`, `SI`, `DI`, `DS` and `SS:SP`; `AX BX CX DX ES` and the
flags are free; use `cld` before string instructions. DS is the
**data segment of QuickBASIC**, not yours; load your own to
reach your data (section 6).

### 3.1 Reference parameters (the default)

`DECLARE SUB ADDONE (n AS INTEGER)`: one near pointer, in DS.
Read through it, write through it:

```nasm
ADDONE:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        inc     word [bx]
        pop     bp
        retf    2
```

`DECLARE FUNCTION SUMI% (a AS INTEGER, b AS INTEGER)`: two
pointers, `b` is the last (nearest, `[bp+6]`), `a` at `[bp+8]`.
An INTEGER function returns in `AX`:

```nasm
SUMI:
        push    bp
        mov     bp, sp
        mov     bx, [bp+8]
        mov     ax, [bx]
        mov     bx, [bp+6]
        add     ax, [bx]
        pop     bp
        retf    4
```

`DECLARE FUNCTION SUML& (a AS LONG, b AS LONG)`: the same with
4-byte values; a LONG function returns in `DX:AX`:

```nasm
SUML:
        push    bp
        mov     bp, sp
        mov     bx, [bp+8]
        mov     ax, [bx]
        mov     dx, [bx+2]
        mov     bx, [bp+6]
        add     ax, [bx]
        adc     dx, [bx+2]
        pop     bp
        retf    4
```

### 3.2 BYVAL parameters

`DECLARE FUNCTION ADDBV% (BYVAL a AS INTEGER, BYVAL b AS
INTEGER)`: the values are on the stack:

```nasm
ADDBV:
        push    bp
        mov     bp, sp
        mov     ax, [bp+8]
        add     ax, [bp+6]
        pop     bp
        retf    4
```

### 3.3 Strings

A variable-length string is passed by reference: the argument is
a near pointer to the **descriptor**, two words: the length and
the near pointer to the characters. The text is not
zero-terminated. A routine may change the characters in place
(never the length or the pointer, and never write past the
length):

```nasm
SLEN:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        mov     ax, [bx]
        pop     bp
        retf    2
```

```nasm
UPCASE:
        push    bp
        mov     bp, sp
        push    si
        mov     bx, [bp+6]
        mov     cx, [bx]
        mov     si, [bx+2]
.l:
        jcxz    .e
        mov     al, [si]
        cmp     al, 'a'
        jb      .n
        cmp     al, 'z'
        ja      .n
        sub     al, 20h
        mov     [si], al
.n:
        inc     si
        dec     cx
        jmp     .l
.e:
        pop     si
        pop     bp
        retf    2
```

(A routine that *returns* a string, or changes the length, has
to use QuickBASIC's string heap; not examined.)

### 3.4 Far pointers: addresses of arrays and variables

`CALL FILLB(VARSEG(arr(0)), VARPTR(arr(0)), 6, 65)` with `BYVAL`
parameters gives the routine a far pointer (segment pushed
first, so it is at the higher address):

```nasm
FILLB:
        push    bp
        mov     bp, sp
        push    di
        push    es
        mov     es, [bp+12]
        mov     di, [bp+10]
        mov     cx, [bp+8]
        mov     ax, [bp+6]
        cld
        rep     stosb
        pop     es
        pop     di
        pop     bp
        retf    8
```

### 3.5 SINGLE and DOUBLE results: the hidden argument

A `FUNCTION` that returns SINGLE or DOUBLE gets **one more
argument, the last one** (nearest to the return address,
`[bp+6]`): a near pointer to a buffer in the caller's data, 4 or
8 bytes. The routine stores the result there and returns that
pointer in `AX`. The real arguments are one place further:

```nasm
COPYS:
        push    bp
        mov     bp, sp
        push    si
        mov     bx, [bp+8]
        mov     si, [bp+6]
        mov     ax, [bx]
        mov     [si], ax
        mov     ax, [bx+2]
        mov     [si+2], ax
        mov     ax, si
        pop     si
        pop     bp
        retf    4
```

```nasm
COPYD:
        push    bp
        mov     bp, sp
        push    si
        mov     bx, [bp+8]
        mov     si, [bp+6]
        mov     cx, 4
.c:
        mov     ax, [bx]
        mov     [si], ax
        inc     bx
        inc     bx
        inc     si
        inc     si
        loop    .c
        mov     ax, [bp+6]
        pop     si
        pop     bp
        retf    4
```

(The routines return the argument unchanged; `retf 4` removes
the pointer to the argument and the hidden pointer.)

Summary of the return conventions:

* INTEGER
  - where the result goes: `AX`
* LONG
  - where the result goes: `DX:AX` (`DX` is the high word)
* SINGLE, DOUBLE
  - where the result goes: stored through the hidden last
    argument; `AX` = that pointer
* STRING
  - where the result goes: not examined

## 4. Imports: what you can take from QuickBASIC

A library has no import table; it uses the fixed places of
QuickBASIC's data segment (`QLBFMT.MD` section 11). DS is that
segment while a routine runs.

With `rlink qlb` a module just **declares the names with
`extern`** and RLINK resolves them: it writes a small module
with the thunks of the services and the data symbols of the
variables, and links it. Nothing is added when a library does
not use a name; a name that is not in the table and not exported
is an error (`Could not resolve`). The table, with the numbers
and offsets of QB 4.50, is in `DOC\QLB-IMP.MD` section 9; names
are matched without regard to case.

* **Reading a variable of QB.** `b_ULSymSeg` (`DS:00D3`) holds
  the segment of the library's symbol block (QB writes it when
  it loads the library). A variable is addressed through the
  segment of its symbol, which RLINK sets to the QB data
  segment; the routine loads `DS` with it:

```nasm
SYMSEG:
        push    ds
        mov     ax, seg b_ULSymSeg
        mov     ds, ax
        mov     ax, [b_ULSymSeg]
        pop     ds
        retf
```

  The other variables of the table: `b_errnum` (`010Ah`),
  `b_errlin` (`010Ch`), `b_errmod` (`0106h`), `b_erradr`
  (`0102h`), `b$ULDataLength`, `b$ULDataStart`, `b$pend`,
  `b$CtrlFlags` ...; valid for QuickBASIC 4.50.

* **Raising a BASIC run-time error.** `extern B$RUNERR`, `BX` =
  the error number, `call far B$RUNERR`. It does not return to
  you. The BASIC program sees `ERR` = the number and can use `ON
  ERROR` / `RESUME NEXT`. The thunk needs `DS` = QuickBASIC's
  data segment, which it is on entry to a routine (restore it
  before the call if you changed it). The ready-made `B$ERR_FC`
  (error 5), `B$ERR_OV` (6), `B$ERR_DV0` (11), `B$ERR_OM` (7) do
  the same with the code built in:

```nasm
RAISEERR:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        call    far B$RUNERR
        pop     bp
        retf    2
```

* **Other services of QuickBASIC** (`B$STDALC`, `B$IFHAlloc`,
  `B$FHDealloc`, `B$END` ...) are in the same table; their
  registers were not examined, only `B$RUNERR`, the four
  `B$ERR_*` and `B$STDALCTMP` (section 5) were executed.
* **Without RLINK** the thunk is `push di / mov di,N / call far
  [DS:00C2h] / pop di / retf` (or `mov bx,N / jmp far
  [DS:00BEh]`) with the number `N` of `QLBFMT.MD` section 11.
* DOS and BIOS are reached with `INT 21h`, `INT 10h` ... in the
  usual way.

## 5. The life cycle: phases and their codes

QuickBASIC talks to the library through a table of far pointers,
`b_ULVars`, and a **selector in CX**. RLINK's runtime is the
dispatcher; it answers `0Ah` (find a routine by name) and `10h`
(find the COMMON area) itself and passes the other selectors to
your **entry procedure** `start`, as a Pascal-style far call:
the selector is pushed as a word parameter and is in `CX` too.
`start` removes it with `retf 2`:

```
   [bp+6]   the selector  (the same value is in CX)
```

* `06h`
  - name: AllocDataImage
  - when QuickBASIC sends it: when the library is loaded
  - what `start` should do: prepare data (Microsoft's runtime
    saves a pristine copy of the data at this time)
* `00h`
  - name: Init
  - when QuickBASIC sends it: after the load, and again every
    time a program starts
  - what `start` should do: **reset your static data**:
    counters, flags, buffers; open files; a second `RUN` does
    not reload the library
* `02h`
  - name: Term
  - when QuickBASIC sends it: when the program ends
  - what `start` should do: close files, release memory, write
    out
* `04h`
  - name: DataRelease
  - when QuickBASIC sends it: when the saved copy of the data is
    released (not seen in the QB 4.5 runs)
  - what `start` should do: nothing
* `08h`
  - name: CONERR
  - when QuickBASIC sends it: a BASIC error happens while
    library code is active (not seen)
  - what `start` should do: nothing
* `0Ch`, `0Eh`
  - name: GetData, GetSeg
  - when QuickBASIC sends it: (not seen)
  - what `start` should do: nothing
* `0Ah`, `10h`
  - name: GETPROC, GETCOMMON
  - when QuickBASIC sends it: answered by the runtime, never
    reaches `start`

The order is in `QLBFMT.MD` section 9. **Init arrives twice**,
so what it does must be repeatable. Unknown selectors must just
return (`retf 2`).

The demo's `start` records every selector in a table and, at
`02h` (Term), writes the table to the file `TRACE.TXT` with DOS
calls - an example of work done at shut-down. It saves all
registers and loads DS for its own data:

```nasm
start:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    cx
        push    dx
        push    ds
        mov     ax, seg trace
        mov     ds, ax
        mov     bx, [tcount]
        cmp     bx, 16
        jae     .full
        mov     ax, [bp+6]
        shl     bx, 1
        mov     [trace+bx], ax
        inc     word [tcount]
.full:
        cmp     word [bp+6], 2
        jne     .done
        mov     ah, 3Ch
        xor     cx, cx
        mov     dx, fname
        int     21h
        jc      .done
        mov     bx, ax
        mov     ah, 40h
        mov     cx, 32
        mov     dx, trace
        int     21h
        mov     ah, 3Eh
        int     21h
.done:
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        pop     bp
        retf    2
```

Two routines give the table back to BASIC (`DEMO.BAS` prints it:
`6 0 0` before the program ends, `2` follows at the end):

```nasm
GETCNT:
        push    ds
        mov     ax, seg trace
        mov     ds, ax
        mov     ax, [tcount]
        pop     ds
        retf
```

```nasm
GETSEL:
        push    bp
        mov     bp, sp
        push    ds
        mov     ax, seg trace
        mov     ds, ax
        mov     bx, [bp+6]
        shl     bx, 1
        mov     ax, [trace+bx]
        pop     ds
        pop     bp
        retf    2
```

Your own dispatcher (without RLINK) is what `SRC\QBRT.ASM` of
RTools has: the entry at `b_ULVars[0]`, `CX` = selector, `0Ah`
and `10h` answered, everything else forwarded. A `GETPROC` does
this (rules in `QLBFMT.MD` section 12):

* read the name from the descriptor that the argument (`[bp+6]`
  after `push bp / mov bp,sp`) points to;
* with `DX` not zero, look for `_` + name; compare without
  regard to case;
* **free the name** with service 26 before it returns, or
  QuickBASIC hangs after a dozen lookups;
* answer the far address in `DX:AX` (relocated segment) or
  `0:0`, and return with `retf 2`.

The dispatcher and the lookup of RTools' runtime (comments left
out):

```nasm
disp:
        cmp     cl, 0Ah
        je      getproc
        cmp     cl, 10h
        je      getcommon
        push    cx
        push    cx
        call    far [cs:ep]
        pop     cx
        cmp     cl, 8
        jb      .r0
        retf    2
.r0:    retf
stub:   retf
getcommon:
        xor     ax, ax
        xor     bx, bx
        xor     dx, dx
        retf    2
```

```nasm
getproc:
        push    bp
        mov     bp, sp
        push    si
        push    di
        push    es
        push    ax
        push    ax
        cld
        mov     bx, [bp+6]
        mov     cx, [bx]
        mov     si, [bx+2]
        or      dx, dx
        jz      .f0
        mov     dl, 1
.f0:    xor     dh, dh
        push    cs
        pop     es
        push    cx
        push    si
        mov     ax, 1505h
        or      dl, dl
        jz      .h1
        mov     ax, 0B604h
.h1:    jcxz    .h9
        mov     di, ax
        lodsb
        call    xform
        xor     ah, ah
        mov     bx, ax
        mov     ax, di
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1
        add     ax, di
        add     ax, bx
        dec     cx
        jmp     short .h1
.h9:    pop     si
        pop     cx
        mov     di, ax
        or      ax, 8000h
        mov     [bp-8], ax
        mov     bx, [cs:htmask]
        and     di, bx
        shl     di, 1
        shl     di, 1
        mov     [bp-10], di
.probe: mov     di, [bp-10]
        mov     ax, [cs:di+htab]
        or      ax, ax
        jz      .none
        cmp     ax, [bp-8]
        jne     .nextslot
        mov     bx, [cs:di+htab+2]
        lea     di, [bx+4]
        or      dl, dl
        jz      .np
        cmp     byte [es:di], '_'
        jne     .nextslot
        inc     di
.np:    push    cx
        push    si
.cmp:   jcxz    .tail
        lodsb
        call    xform
        scasb
        jne     .miss
        dec     cx
        jmp     short .cmp
.tail:  cmp     byte [es:di], 0
.miss:  pop     si
        pop     cx
        jne     .nextslot
        mov     ax, [es:bx]
        mov     dx, [es:bx+2]
        jmp     short .done
.nextslot:
        mov     bx, [cs:htmask]
        shl     bx, 1
        shl     bx, 1
        or      bx, 3
        mov     di, [bp-10]
        add     di, 4
        and     di, bx
        mov     [bp-10], di
        jmp     short .probe
.none:  xor     ax, ax
        xor     dx, dx
.done:  add     sp, 4
        push    ax
        push    dx
        mov     bx, [bp+6]
        mov     di, 26
        call    far [0C2h]
        pop     dx
        pop     ax
        pop     es
        pop     di
        pop     si
        pop     bp
        retf    2
```

## 6. Data

* The `.data` and `.bss` of every module go to the data tail
  (QB's data segment, offset `D = 3360h` and up); `.bss` is
  stored as zero bytes.
* **`.data` and `.bss` are separate segments with separate
  segment values.** A pointer made with `seg` in one and an
  offset from the other addresses the wrong bytes. Keep what is
  used together in the same section; the demo keeps everything
  in `.data`.
* DS on entry is QuickBASIC's. Load your own with `mov ax, seg
  label` / `mov ds, ax` and restore it (`push ds` ... `pop ds`)
  before you return. For data that is in the code segment use
  `cs:`.
* Static data is **not** reset when a BASIC program runs again.
  Reset it at `Init` (section 5).

The data of the demo, one segment:

```nasm
        segment .data

fname:  db      'TRACE.TXT', 0
trace:  times 16 dw 0
tcount: dw      0
```

## 7. Linking

```
nasm -s -f rdf DEMO.ASM
rlink qlb /o=DEMO.QLB DEMO.RDF
rlink qlb /o=ALL.QLB A.RDF B.RDF C.RDF /entry=start
```

* `/o=` the output, `/entry=` the name of the entry procedure
  (default `start`); the file name list is the modules, in this
  order (their code segments follow each other).
* `/nonames` leaves the CODE table empty (it lists the exported
  names otherwise).
* If you see `Entry point start not found.` the RDF has no
  `global start`, or (with an old `RLINK`) the environment
  variable `TMP` is not set.
* QuickBASIC loads one library only: put every module you need
  into one `rlink qlb` run (`QLBFMT.MD` section 13).

The `makefile` of the examples (`TEST\QLB`, tabs):

```make
all : HELLO.QLB IMPORT.QLB

HELLO.QLB : HELLO.RDF HELLO2.RDF ..\..\BIN\RLINK.EXE
	..\..\BIN\RLINK qlb /o=HELLO.QLB HELLO.RDF HELLO2.RDF
HELLO.RDF : HELLO.ASM
	nasm -f rdf HELLO.ASM
HELLO2.RDF : HELLO2.ASM
	nasm -f rdf HELLO2.ASM
IMPORT.QLB : IMPORT.RDF ..\..\BIN\RLINK.EXE
	..\..\BIN\RLINK qlb /o=IMPORT.QLB IMPORT.RDF
IMPORT.RDF : IMPORT.ASM
	nasm -f rdf IMPORT.ASM
clean:
	DEL *.RDF
	DEL HELLO.QLB
	DEL IMPORT.QLB
```

## 8. Testing

1. **Without QuickBASIC**: `aloader NAME.QLB` (`ALOADER\`) loads
   the file, runs the same checks as QuickBASIC, then the phases
   `06h 10h 00h`, a `0Ah` for every exported name, `00h`, and
   calls the demo routines. For your own routines, edit the
   `demo` section of `ALOADER.ASM` (`QLBUSE.MD`, part B) or use
   `aloader NAME.QLB /L` to see that the file is accepted and
   which names are in the CODE table.
2. **With QuickBASIC**: `QB /L NAME.QLB /RUN TEST.BAS`. Write a
   small BASIC program first: `DECLARE` lines and a few `CALL`s,
   and `SYSTEM` at the end. If QuickBASIC says *Invalid format*,
   one of the checks of `QLBFMT.MD` section 14 failed: run
   `aloader NAME.QLB /L` to see which.
3. A routine writes its results through the stack arguments; in
   the BASIC test program print them or write them into a file
   (`OPEN ... FOR OUTPUT`): `PRINT` is fine on the screen but is
   hard to capture in a script.

### If QuickBASIC hangs

Seen: the reserved word, the `retf 2` rule for selectors and the
freeze with many call sites. The other causes follow from the
stack rules and were not each reproduced.

* hang when the first `CALL` is compiled / run
  - probable cause: the routine ends with the wrong `retf n`
    (number of argument words), or a hidden result pointer was
    not counted
* hang at start, before the program
  - probable cause: a dispatcher selector `08h`-`10h` that ends
    with `retf` instead of `retf 2`, or the entry procedure
    `start` that does not end with `retf 2`
* hang at start, with no library problem
  - probable cause: a **BASIC reserved word** as parameter name
    in `DECLARE` (`off`); rename it
* random crash after the call
  - probable cause: `DS`, `SI`, `DI` or `BP` not restored; a
    pointer into the wrong segment (`.bss` / `.data` mix)
* freeze after a dozen `CALL`s, before the program starts
  - probable cause: the dispatcher's `GETPROC` did not free the
    name (service 26), `QLBFMT.MD` section 12
* `CDECL` routine "not found"
  - probable cause: the symbol has no leading underscore, or is
    not exported
* `Subprogram not defined`
  - probable cause: the name is not exported (`global` missing),
    or is not in a code segment

## 9. Writing a .QLB without RLINK

Everything is in `QLBFMT.MD`. In short, for a writer program:

1. Put the code (every segment on a paragraph boundary) into the
   code image: `w2` paragraphs. Make the data tail: the 16-byte
   `b_ULVars`, 16 bytes of scratch (`BC_SAB`), then your data.
2. Choose `D` (at least `3317h`, `3360h` is safe), `T` = tail
   size (a multiple of 16), `Z = D + T`, `w3 = w2 + Z/16`.
3. Write the dispatcher into the code image (section 5 above),
   put its far address, and two `retf` stubs, into
   `b_ULVars[0..2]`, with the word 0 at `+0Ch` and `13h` at
   `+0Eh`.
4. Build the symbol block: QB header (34 bytes), CODE table (may
   be empty), DATA table with `b_ULVars`, SEGMENT table `NULL,
   _DATA, BC_SAB, STACK, SYMBOL`, the name pool.
5. Write the MZ header: `e_cparhdr = 40h` or more, `e_ss = w3`,
   `QPOS = (e_cparhdr + e_cs)*16 + e_ip`; the relocation table
   with an entry for every segment word of code, data, tables
   and for the six header words (`QLBFMT.MD` section 8).
6. File layout: header, zero word `C`, code image, the word `D`,
   the tail, the symbol block.
7. Test with `ALOADER ... /L` (it makes all of QuickBASIC's
   checks) and then with QuickBASIC.

`SRC\RLOQBE.PAS` of RTools is a complete implementation
(`QbeFinish`).

## 10. Checklist before you ship a library

* [ ] `nasm -s -f rdf` with NASM 0.98.39; no warnings.
* [ ] every exported routine ends with `retf 2*n` and has the
  right `n`; the function result is in the right place (`AX`,
  `DX:AX`, hidden pointer).
* [ ] `BP`, `SI`, `DI`, `DS` preserved; `cld` before string
  instructions.
* [ ] data used with one `DS` is in one segment; data is reset
  at Init.
* [ ] the entry procedure `start` ends with `retf 2` and returns
  for selectors it does not know.
* [ ] all modules are in one `rlink qlb` command; the list of
  names is below about 2000.
* [ ] `aloader NAME.QLB /L` accepts the file; a test BASIC
  program runs under QuickBASIC 4.5 (and 4.0).
* [ ] BASIC parameter names in the `DECLARE` lines are not
  reserved words.

---

(c) DosWorld 2026. This document is released into the public
domain under the Unlicense (<https://unlicense.org>): anyone may
copy, modify, publish, use, compile, sell or distribute it, for
any purpose, without conditions. It comes without any warranty.
