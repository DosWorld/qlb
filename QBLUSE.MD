# QBLUSE - Using a Quick Library (.QLB)

Consumer manual. (c) DosWorld 2026, public domain (Unlicense,
see the end of this file).

"Consumer" is anybody who runs the code in a `.QLB`. There are
two kinds, and this manual covers both:

* **Part A**: a *QuickBASIC programmer* who calls the library
  from a BASIC program. Demo: `QLOADER\`.
* **Part B**: a *DOS program of your own* (here in NASM) that
  loads the library, plays the part of QuickBASIC (all the
  life-cycle calls, imports, exports) and calls the routines.
  Demo: `ALOADER\`.

The file format is in `QBLFMT.MD`; writing a library is in
`QBLWRT.MD`. Everything below was run: QuickBASIC 4.50 for part
A, DOSBox-X with the real MS-DOS programs of this folder for
part B. The library used is `DEMO.QLB`, made from `DEMO.ASM`
with `rlink qlb` (see `QBLWRT.MD`).

---

# Part A - from QuickBASIC

## A1. Loading a library

```
QB /L DEMO.QLB /RUN DEMO.BAS
```

* `/L name` loads the library when QB starts. `/L` without a
  name loads the default `QB.QLB` of QuickBASIC (INTERRUPT,
  ABSOLUTE ...), as Microsoft's manual says.
* **Only one library can be loaded.** Two `/L` options make QB
  print its usage line and stop (measured):

  ```
  Valid options: [/RUN] file /AH /B /C:buf /G /NOHI /H
                 /L [lib] /MBF /CMD string
  ```

  So *all* the routines you need must be linked into one `.QLB`
  (`rlink qlb /o=ALL.QLB A.RDF B.RDF C.RDF`, or one `LINK /Q`
  run). `.QLB` files cannot be merged afterwards.
* QuickBASIC 4.0 and 4.5 load libraries. **QBasic (`QBASIC.EXE`
  of MS-DOS 5/6) has no `/L` and does not load them.**
* The BASIC program `DEMO.BAS` is an ordinary program; `SYSTEM`
  at the end returns to DOS.

## A2. Declaring and calling

Every routine is declared with `DECLARE`, exactly as for a SUB
or FUNCTION written in BASIC. The name must match the exported
name (case does not matter; letters, digits and `_`):

```basic
DECLARE SUB ADDONE (n AS INTEGER)
DECLARE FUNCTION SUMI% (a AS INTEGER, b AS INTEGER)

CALL ADDONE(x%)
total% = SUMI%(a%, b%)
```

QB asks the library for the address of each routine **once for
every `CALL` / function reference in the source, before the
program runs** (selector `0Ah`, `QBLFMT.MD` section 9). If the
library does not know the name, QB reports an error and does not
run.

## A3. Parameters and return values

What the assembler routine receives is fixed by BASIC's
convention (`QBLFMT.MD` section 10). The table below is what
`DEMO.QLB` does with each kind; the output is from the run of
`DEMO.BAS` under QuickBASIC 4.50 (`QLOADER\OUTPUT1.TXT`).

* `SUB x (n AS INTEGER)`
  - what the routine sees on the stack: near pointer to `n`; the
    routine may change it
  - demo routine: `ADDONE`
* `FUNCTION f% (a AS INTEGER, b AS INTEGER)`
  - what the routine sees on the stack: two near pointers
  - result: `AX`
  - demo routine: `SUMI`
* `FUNCTION f& (a AS LONG, b AS LONG)`
  - what the routine sees on the stack: two near pointers to 4
    bytes
  - result: `DX:AX`
  - demo routine: `SUML`
* `FUNCTION f% (BYVAL a AS INTEGER, BYVAL b AS INTEGER)`
  - what the routine sees on the stack: the two values
  - result: `AX`
  - demo routine: `ADDBV`
* `FUNCTION f% (s AS STRING)`
  - what the routine sees on the stack: near pointer to the
    descriptor `{length, pointer to text}`
  - result: `AX`
  - demo routine: `SLEN`
* `SUB x (s AS STRING)`
  - what the routine sees on the stack: the same; the routine
    edits the text in place
  - demo routine: `UPCASE`
* `SUB x (BYVAL sg%, BYVAL ofs%, BYVAL n%, BYVAL v%)`
  - what the routine sees on the stack: four words; `sg%:ofs%`
    is a far pointer made with `VARSEG(a(0)), VARPTR(a(0))`
  - demo routine: `FILLB`
* `FUNCTION f! (a AS SINGLE)`
  - what the routine sees on the stack: near pointer to `a`
    **and** a hidden last argument: near pointer to a 4-byte
    result buffer
  - result: pointer in `AX`, value in the buffer
  - demo routine: `COPYS`
* `FUNCTION f# (a AS DOUBLE)`
  - what the routine sees on the stack: near pointer to `a` and
    a hidden pointer to an 8-byte result buffer
  - result: pointer in `AX`, value in the buffer
  - demo routine: `COPYD`

The program that produced the output (`DEMO.BAS`; `Say` prints
on the screen and into `RESULT.TXT`):

```basic
DECLARE SUB Say (s AS STRING)
DECLARE SUB ADDONE (n AS INTEGER)
DECLARE FUNCTION SUMI% (a AS INTEGER, b AS INTEGER)
DECLARE FUNCTION SUML& (a AS LONG, b AS LONG)
DECLARE FUNCTION ADDBV% (BYVAL a%, BYVAL b%)
DECLARE FUNCTION SLEN% (s AS STRING)
DECLARE SUB UPCASE (s AS STRING)
DECLARE SUB FILLB (BYVAL sg%, BYVAL ofs%, BYVAL n%, BYVAL v%)
DECLARE FUNCTION COPYS! (a AS SINGLE)
DECLARE FUNCTION COPYD# (a AS DOUBLE)

OPEN "RESULT.TXT" FOR OUTPUT AS #1
Say "QLOADER 1/2: parameters and results of DEMO.QLB"

x% = 41
CALL ADDONE(x%)
Say "ADDONE(41), by reference: x% =" + STR$(x%)

a% = 1000: b% = 234
Say "SUMI%(1000, 234) -> AX =" + STR$(SUMI%(a%, b%))

p& = 70000: q& = 5
Say "SUML&(70000, 5) -> DX:AX =" + STR$(SUML&(p&, q&))

Say "ADDBV%(7, 8), BYVAL -> AX =" + STR$(ADDBV%(7, 8))

t$ = "hello"
Say "SLEN%(t$), descriptor -> AX =" + STR$(SLEN%(t$))
CALL UPCASE(t$)
Say "UPCASE(t$) edits in place: " + t$

DIM arr(0 TO 9) AS INTEGER
CALL FILLB(VARSEG(arr(0)), VARPTR(arr(0)), 6, 65)
m$ = STR$(arr(0)) + STR$(arr(1)) + STR$(arr(2)) + STR$(arr(3))
Say "FILLB, far pointer BYVAL:" + m$

f! = 2.5
Say "COPYS!(2.5), hidden pointer:" + STR$(COPYS!(f!))
d# = 1234.5678#
Say "COPYD#(1234.5678), hidden ptr:" + STR$(COPYD#(d#))

Say "done"
CLOSE #1
SYSTEM

SUB Say (s AS STRING)
  PRINT s
  PRINT #1, s
END SUB
```

Output (`OUTPUT1.TXT`):

```
QLOADER 1/2: parameters and results of DEMO.QLB
ADDONE(41), by reference: x% = 42
SUMI%(1000, 234) -> AX = 1234
SUML&(70000, 5) -> DX:AX = 70005
ADDBV%(7, 8), BYVAL -> AX = 15
SLEN%(t$), descriptor -> AX = 5
UPCASE(t$) edits in place: HELLO
FILLB, far pointer BYVAL: 16705 16705 16705 0
COPYS!(2.5), hidden pointer: 2.5
COPYD#(1234.5678), hidden ptr: 1234.5678
done
```

Rules the assembler side must follow (`QBLWRT.MD` shows the
code): every routine ends with `retf 2*n` (`n` = number of words
pushed, the hidden pointer counts), keeps `BP`, `SI`, `DI`, `DS`
and `SS:SP`, and loads `DS` itself before it touches its own
data. A wrong `retf n` corrupts the stack of QuickBASIC.

## A4. Errors raised by the library

A routine can raise a BASIC run-time error through QuickBASIC's
own service (`BX` = code, service 34, `QBLFMT.MD` section 11).
It looks to the BASIC program like any other error:

```basic
DECLARE SUB Say (s AS STRING)
DECLARE SUB RAISEERR (BYVAL code AS INTEGER)
DECLARE FUNCTION SYMSEG% ()
DECLARE FUNCTION GETCNT% ()
DECLARE FUNCTION GETSEL% (BYVAL i AS INTEGER)

OPEN "RESULT2.TXT" FOR OUTPUT AS #1
Say "QLOADER 2/2: imports from QB, phases"

Say "SYMSEG% reads DS:00D3 = " + HEX$(SYMSEG%)

ON ERROR GOTO Handler
CALL RAISEERR(5)
Say "RAISEERR(5) returned, RESUME NEXT"
ON ERROR GOTO 0

n% = GETCNT%
s$ = ""
FOR i% = 0 TO n% - 1
  s$ = s$ + " " + HEX$(GETSEL%(i%))
NEXT
Say "selectors seen by start (hex):" + s$

Say "done"
CLOSE #1
SYSTEM

Handler:
Say "BASIC error" + STR$(ERR) + " raised by the library"
RESUME NEXT

SUB Say (s AS STRING)
  PRINT s
  PRINT #1, s
END SUB
```

Output (`OUTPUT2.TXT`):

```
QLOADER 2/2: imports from QB, phases
SYMSEG% reads DS:00D3 = 9FF3
BASIC error 5 raised by the library
RAISEERR(5) returned, RESUME NEXT
selectors seen by start (hex): 6 0 0
done
```

`ON ERROR GOTO` sees `ERR = 5`; `RESUME NEXT` continues with the
statement after `CALL RAISEERR`. Without a handler QuickBASIC
shows its normal error box. `SYMSEG` shows a variable of QB read
by the library (`DS:00D3`, the segment of the symbol block), and
the last line shows the life-cycle selectors that reached the
library's start-up procedure while this program ran: `6`
(AllocDataImage), `0` (Init), `0` (Init again, when the program
starts); `2` (Term) follows when the program ends.

## A5. Things that went wrong in practice

* **A BASIC reserved word as the name of a parameter in
  `DECLARE` hangs the QB editor.** `BYVAL off AS INTEGER` froze
  QuickBASIC 4.50; `ofs` works. Use names that are not keywords.
* **Unexplained freeze.** With `DEMO.QLB` (14 routines) some
  programs with 10 to 12 call sites hung QuickBASIC 4.50 before
  the first statement ran (the library had received only
  selectors `06h` and `00h`), while other programs with 10 call
  sites ran, and removing any one call from a hanging program
  made it run. The reason was not found: `ALOADER` gets the
  correct answer for all 13 names, so the name table is right,
  and an earlier test library with 40 trivial routines called
  once each worked. `DEMO.BAS` was therefore split into two
  programs of at most nine call sites. If QuickBASIC freezes at
  start, shorten the program and try again before you suspect
  your routines.
* A routine that does not remove its arguments, or removes the
  wrong number, or a dispatcher that ends selector 08h-10h with
  `retf` instead of `retf 2`, hangs QuickBASIC.

---

# Part B - from your own DOS program

This is what QuickBASIC does when it meets a library;
`ALOADER.ASM` (NASM 0.98, 8086) does the same:

1. read the MZ header and the QB header, make QB's checks;
2. allocate **one block** for the three regions, clear it, read
   the code image, the data tail and the symbol block into it;
3. apply the relocation entries;
4. check the segment table and find `b_ULVars` in the DATA
   table;
5. give the library what it expects from QuickBASIC (the
   variables at `DS:00D3...` and the gateway at `DS:00BE/00C2`);
6. run the life cycle: `06h`, `10h`, `00h`, then `0Ah` for each
   name, `00h`, then call the routines, `02h`, `04h`;
7. release the block.

Run it:

```
aloader DEMO.QLB       full run: all phases, the calls
aloader QB.QLB /L      load only: all checks, report, CODE
                       table lookup (any library)
```

`aloader` with no argument loads `DEMO.QLB`. Output of the full
run (`ALOADER\OUTPUT.TXT`):

```
ALOADER: loads a .QLB, plays the part of QuickBASIC
library file: DEMO.QLB
  block segment   = 0B8D
  block paragraphs= 037A
  w2 code paras   = 0036
  w3 data end     = 0371
  w4 symbol bytes = 0081
  data segment    = 0BC3
  D (tail offset) = 3360
  T (tail bytes)  = 0050
  relocations     = 33
checks passed: QB header, segments, b_ULVars.
-- phases QuickBASIC runs when it loads a library --
  dispatcher CX = 0006
  dispatcher CX = 0010 (GETCOMMON): none (AX=BX=DX=0)
  dispatcher CX = 0000
-- GETPROC (0Ah) once for every name called --
  GETPROC ADDONE -> 0B8D:004F
  GETPROC SUMI -> 0B8D:005B
  GETPROC SUML -> 0B8D:006C
  GETPROC ADDBV -> 0B8D:0083
  GETPROC SLEN -> 0B8D:0090
  GETPROC UPCASE -> 0B8D:009C
  GETPROC FILLB -> 0B8D:00C1
  GETPROC COPYS -> 0B8D:00DB
  GETPROC COPYD -> 0B8D:00F6
  GETPROC RAISEERR -> 0B8D:0115
  GETPROC SYMSEG -> 0B8D:0128
  GETPROC GETCNT -> 0B8D:012C
  GETPROC GETSEL -> 0B8D:0137
-- the program starts --
  dispatcher CX = 0000
-- the program calls the library --
  ADDONE(41) by reference, now 42
  SUMI(1000, 234) returns AX = 1234
  SUML(70000, 5) returns DX:AX = 70005
  ADDBV(7, 8) BYVAL returns AX = 15
  SLEN("hello") returns AX = 5
  UPCASE("hello") gives HELLO
  FILLB(seg, ofs, 6, 65) wrote AAAAAA
  COPYS(2.5) result bytes (hex) = 40200000, AX = pointer 0448
  COPYD(2.5) result bytes (hex) = 4004000000000000
  SYMSEG reads DS:00D3 = 0EFE (the segment of the symbol block)
  RAISEERR(5): BASIC error via gateway 34, ERR = 5
-- the program ends --
  dispatcher CX = 0002
  selectors seen by start (hex): 0006 0000 0000 0002 
-- the library is released --
  dispatcher CX = 0004
block released with AH=49h.
done.
```

Output of `aloader QB.QLB /L` for the real Microsoft library of
QuickBASIC 4.5 (`ALOADER\OUTLOAD.TXT`); it passes every check,
and the CODE table has `INT86OLD` at `block+0011h:0004h`, which
is what `DOC\QLB.MD` says:

```
ALOADER: loads a .QLB, plays the part of QuickBASIC
library file: QB.QLB
  block segment   = 0B8D
  block paragraphs= 045E
  w2 code paras   = 00A6
  w3 data end     = 03DE
  w4 symbol bytes = 07F1
  data segment    = 0C33
  D (tail offset) = 3317
  T (tail bytes)  = 0069
  relocations     = 143
checks passed: QB header, segments, b_ULVars.
CODE table lookup of INT86OLD: 0B9E:0004
block released with AH=49h.
done.
```

Libraries made by Microsoft's `LINK /Q` contain a runtime
(`BQLB45.LIB`) that calls QuickBASIC's services through the
gateway (heap allocation, error handling). `ALOADER` provides
the gateway but implements only service 34 (raise an error), so
for such a library it stops after the checks (`/L`) and does not
run the life cycle. The libraries made by `RLINK` need nothing
else and run completely.

## B1. Block and variables

```
block of qparas = w3 + ceil(w4/16) paragraphs

at +0 paragraphs   code image, w2 paragraphs
                   segment qseg
at +w2             QB data region, Z bytes: [0,D) free,
                   the tail at D;  segment datseg = qseg + w2
at +w3             symbol block, w4 bytes
                   segment qseg + w3
```

A relocation entry of the file adds the same `qseg` to every
word, because all three regions are in the one block
(`QBLFMT.MD` section 7). `datseg` is the segment that is passed
to the library as "QB's data segment": the library finds its
tail there at offset `D`, and the bytes below `D` are the place
for QuickBASIC's variables, which `ALOADER` fills in (`qbenv`)
and uses as scratch for the arguments (`ARGS`). `D` must be at
least `0500h` for this (`3360h` in RLINK libraries, `3317h` in
Microsoft's).

## B2. Load: read, allocate, read, relocate

```nasm
loadbody:
        need    rdmz
        need    rdqb
        need    rdsize
        need    alloc
        need    rdimage
        need    rdsym
        jmp     relocate
```

```nasm
rdmz:
        xor     cx, cx
        xor     dx, dx
        call    seekto
        jnc     .a
        ret
.a:
        mov     cx, 28
        mov     dx, mzh
        call    rdexact
        jnc     .b
        ret
.b:
        cmp     word [mzh], 'MZ'
        je      .ok
        stc
.ok:
        ret
```

```nasm
rdqb:
        mov     ax, [mzh+8]
        call    mulp
        mov     [hdrblo], ax
        mov     [hdrbhi], dx
        mov     ax, [mzh+8]
        add     ax, [mzh+0x16]
        mov     dx, 0
        adc     dx, 0
        call    shl4
        add     ax, [mzh+0x14]
        adc     dx, 0
        mov     cx, dx
        mov     dx, ax
        call    seekto
        jnc     .a
        ret
.a:
        mov     cx, 34
        mov     dx, qbh
        call    rdexact
        jnc     .b
        ret
.b:
        cmp     byte [qbh], 0EAh
        jne     .bad
        cmp     word [qbh+6], 0x6C75
        jne     .bad
        cmp     byte [qbh+5], 2
        jb      .bad
        clc
        ret
.bad:
        stc
        ret
```

```nasm
rdsize:
        mov     ax, [qbh+0x10]
        mov     [w2], ax
        mov     ax, [qbh+0x12]
        mov     [w3], ax
        mov     ax, [qbh+0x14]
        mov     [w4], ax
        mov     ax, [w2]
        cmp     ax, [w3]
        ja      .bad
        mov     ax, [w3]
        sub     ax, [w2]
        cmp     ax, 0x1000
        jae     .bad
        cmp     word [w4], 34
        jb      .bad
        mov     ax, [w4]
        add     ax, 15
        jc      .bad
        mov     cl, 4
        shr     ax, cl
        add     ax, [w3]
        jc      .bad
        mov     [qparas], ax
        clc
        ret
.bad:
        stc
        ret
```

```nasm
alloc:
        mov     bx, [qparas]
        mov     ah, 48h
        int     21h
        jnc     .o
        ret
.o:
        mov     [cs:qseg], ax
        add     ax, [w2]
        mov     [cs:datseg], ax
        mov     word [rgend], reg
        call    clrblk
        clc
        ret
```

* `rdmz` reads the 28 bytes of the MZ header. `rdqb` computes
  `QPOS = (e_cparhdr + e_cs) * 16 + e_ip`, reads the 34 bytes
  and makes QB's three checks.
* `rdsize` stores `w2, w3, w4` from the **unrelocated** header,
  checks `w2 <= w3`, `Z < 64 KB`, `w4 >= 34`, and computes the
  block size `w3 + ceil(w4/16)`.
* `alloc` asks DOS for the block (`AH=48h`; a DOS program that
  owns all memory must first shrink itself with `AH=4Ah`; the
  EXE of `ALOADER` is linked so that DOS gives it only what it
  needs) and clears it, so no stale byte is left in the gaps.

The three reads. The tail goes to `datseg:D`, the symbol block
to `qseg+w3:0`; the file is read in chunks of at most 32 KB,
`rdblk` keeps the destination as `rseg:roff` and normalises it
for every chunk, so that it works for areas larger than 64 KB:

```nasm
rdimage:
        jmp     .st
.bad:
        stc
        ret
.st:
        mov     dx, [hdrblo]
        mov     cx, [hdrbhi]
        call    seekto
        jnc     .a
        ret
.a:
        mov     cx, 2
        mov     dx, cval
        call    rdexact
        jnc     .b
        ret
.b:
        cmp     word [cval], 0
        jne     .bad
        mov     ax, [w2]
        call    mulp
        mov     [cntlo], ax
        mov     [cnthi], dx
        mov     ax, [cs:qseg]
        mov     [rseg], ax
        mov     word [roff], 0
        call    rdblk
        jnc     .c
        ret
.c:
        need    fullread
        mov     cx, 2
        mov     dx, dval
        call    rdexact
        jnc     .d
        ret
.d:
        mov     bx, [cs:qhandle]
        mov     ax, 4201h
        xor     cx, cx
        xor     dx, dx
        int     21h
        jnc     .e
        ret
.e:
        mov     [tslo], ax
        mov     [tshi], dx
        mov     si, [dval]
        sub     si, 4
        jc      .bad
        mov     ax, [w3]
        call    mulp
        add     ax, [hdrblo]
        adc     dx, [hdrbhi]
        sub     ax, si
        sbb     dx, 0
        jc      .bad
        mov     [sylo], ax
        mov     [syhi], dx
        sub     ax, [tslo]
        sbb     dx, [tshi]
        jc      .bad
        test    dx, dx
        jnz     .bad
        mov     [tailn], ax
        mov     [cntlo], ax
        mov     word [cnthi], 0
        mov     bx, [dval]
        add     bx, ax
        jc      .bad
        mov     ax, [w3]
        sub     ax, [w2]
        mov     cl, 4
        shl     ax, cl
        cmp     bx, ax
        ja      .bad
        mov     ax, [cs:datseg]
        mov     [rseg], ax
        mov     ax, [dval]
        mov     [roff], ax
        call    rdblk
        jnc     .f
        ret
.f:
        jmp     fullread
```

```nasm
rdsym:
        mov     dx, [sylo]
        mov     cx, [syhi]
        call    seekto
        jnc     .a
        ret
.a:
        mov     ax, [cs:qseg]
        add     ax, [w3]
        mov     [rseg], ax
        mov     word [roff], 0
        mov     ax, [w4]
        mov     [cntlo], ax
        mov     word [cnthi], 0
        call    rdblk
        jnc     .b
        ret
.b:
        jmp     fullread
```

```nasm
rdblk:
.l:
        mov     ax, [roff]
        mov     cl, 4
        shr     ax, cl
        add     [rseg], ax
        and     word [roff], 15
        mov     cx, 0x8000
        cmp     word [cnthi], 0
        jne     .go
        mov     cx, [cntlo]
        cmp     cx, 0x8000
        jbe     .go
        mov     cx, 0x8000
.go:
        jcxz    .done
        mov     ax, [rseg]
        mov     dx, [roff]
        mov     bx, [cs:qhandle]
        push    cx
        mov     ds, ax
        mov     ah, 3Fh
        int     21h
        mov     [cs:rdn], ax
        call    rds
        pop     cx
        jc      .err
        mov     ax, [cs:rdn]
        sub     [cntlo], ax
        sbb     word [cnthi], 0
        cmp     ax, cx
        jb      .done
        add     word [rseg], 0x0800
        jmp     .l
.done:
        clc
        ret
.err:
        stc
        ret
```

`rdimage` also checks the prefix word `C` is 0, that the tail is
not larger than the declared data (`D + T <= Z`) and computes
`T` as the difference of the file positions, which equals `Z -
D`.

**Relocation** is read from the file in chunks of 128 entries.
Before that, three *regions* are registered; an entry is
accepted only if its word lies fully inside one of them:

```nasm
relocate:
        mov     ax, [w2]
        call    mulp
        mov     cx, dx
        mov     bx, ax
        xor     ax, ax
        xor     dx, dx
        call    addreg
        mov     ax, [w2]
        call    mulp
        add     ax, [dval]
        adc     dx, 0
        mov     bx, [tailn]
        xor     cx, cx
        call    addreg
        mov     ax, [w3]
        call    mulp
        mov     bx, [w4]
        xor     cx, cx
        call    addreg
        mov     dx, [mzh+0x18]
        xor     cx, cx
        call    seekto
        jnc     .s
        ret
.s:
        mov     ax, [mzh+6]
        mov     [remain], ax
.chunk:
        cmp     word [remain], 0
        je      .done
        mov     ax, [remain]
        cmp     ax, 128
        jbe     .n
        mov     ax, 128
.n:
        sub     [remain], ax
        mov     [nchunk], ax
        add     ax, ax
        add     ax, ax
        mov     cx, ax
        mov     dx, rbuf
        call    rdexact
        jnc     .r
        ret
.r:
        mov     si, rbuf
        mov     bp, [nchunk]
        call    applychunk
        jnc     .chunk
        ret
.done:
        clc
        ret
```

```nasm
applychunk:
.loop:
        test    bp, bp
        jz      .ok
        lodsw
        xchg    ax, di
        lodsw
        mov     bx, ax
        mov     cx, 16
        mul     cx
        add     ax, di
        adc     dx, 0
        cmp     di, 0xFFFF
        je      .out
        call    inreg
        jc      .out
        mov     ax, [cs:qseg]
        mov     dx, ax
        add     ax, bx
        mov     es, ax
        add     [es:di], dx
        dec     bp
        jmp     .loop
.out:
        call    rds
        stc
        ret
.ok:
        call    rds
        clc
        ret
```

```nasm
addreg:
        sub     bx, 2
        sbb     cx, 0
        jc      .o
        add     bx, ax
        adc     cx, dx
        mov     di, [rgend]
        mov     [di], ax
        mov     [di+2], dx
        mov     [di+4], bx
        mov     [di+6], cx
        add     word [rgend], 8
.o:
        ret
```

```nasm
inreg:
        push    si
        mov     si, reg
.l:
        cmp     si, [rgend]
        jae     .no
        cmp     dx, [si+2]
        jb      .n
        ja      .a
        cmp     ax, [si]
        jb      .n
.a:
        cmp     dx, [si+6]
        ja      .n
        jb      .y
        cmp     ax, [si+4]
        ja      .n
.y:
        pop     si
        clc
        ret
.n:
        add     si, 8
        jmp     .l
.no:
        pop     si
        stc
        ret
```

## B3. Resolve the export names (how QuickBASIC does it)

QuickBASIC does **not** read the CODE table. It calls the
dispatcher with `CX = 0Ah` and a pointer to a BASIC string
descriptor, and the library answers with the far address. This
is the one way that works for every library, with or without a
CODE table:

```nasm
getproc:
        push    di
        mov     es, [cs:datseg]
        mov     di, GPNAME
        xor     cx, cx
.c:
        lodsb
        stosb
        test    al, al
        jz      .e
        inc     cx
        jmp     .c
.e:
        mov     bx, GPDESC
        mov     [es:bx], cx
        mov     word [es:bx+2], GPNAME
        mov     ax, es
        mov     ds, ax
        push    bx
        xor     dx, dx
        mov     cx, 0Ah
        call    far [cs:vars]
        mov     [cs:r_ax], ax
        mov     [cs:r_dx], dx
        pop     di
        call    rds
        mov     ax, [cs:r_ax]
        mov     dx, [cs:r_dx]
        ret
```

```nasm
resolve:
        mov     si, names
        xor     di, di
.n:
        cmp     byte [si], 0
        je      .end
        mov     [cs:cur], si
        call    getproc
        mov     [cs:fntab+di], ax
        mov     [cs:fntab+di+2], dx
        push    si
        push    di
        mov     dx, m_gp
        call    puts
        mov     dx, [cs:cur]
        call    putz
        mov     dx, m_arrow
        call    puts
        pop     di
        push    di
        mov     ax, [cs:fntab+di+2]
        call    puthexw
        mov     al, ':'
        call    putchar
        mov     ax, [cs:fntab+di]
        call    puthexw
        call    crlf
        pop     di
        pop     si
        add     di, 4
        jmp     .n
.end:
        ret
```

The descriptor `{length, pointer}` and the text of the name live
in the data segment the library sees (`GPDESC`, `GPNAME` inside
`ARGS`). `DX` is the flag (`DX = 0`: no dot conversion). The
result `DX:AX` is the far address of the routine (`0:0` =
unknown); `ALOADER` keeps it in `fntab`.

If you do not want to start the library (for a tool that only
lists it), walk the **CODE table** yourself, as `showtab` does
(it works only for libraries whose writer filled the table;
RLINK libraries have an empty one):

```nasm
showtab:
        mov     dx, m_tab
        call    puts
        mov     ax, [qbh+8]
        mov     dx, n_int86
        call    lookup
        jnc     .y
        mov     dx, m_tabno
        jmp     puts
.y:
        mov     ax, [es:si+6]
        call    puthexw
        mov     al, ':'
        call    putchar
        mov     ax, [es:si+4]
        call    puthexw
        call    rds
        jmp     crlf
```

## B4. Resolve the imports (what the library takes from you)

A library has no import table (`QBLFMT.MD` section 11). Its code
expects QuickBASIC's data segment to hold a few variables and
two far pointers. `qbenv` first checks the segment table and
`b_ULVars`, then writes those into the data segment, and reads
the dispatcher address out of `b_ULVars`:

```nasm
checkseg:
        mov     ax, [qbh+0x0C]
        mov     dx, n_null
        call    lookup
        jnc     .a
        ret
.a:
        mov     ax, [es:si+6]
        cmp     ax, [cs:datseg]
        jne     .bad
        mov     ax, [qbh+0x0C]
        mov     dx, n_bcsab
        call    lookup
        jnc     .b
        ret
.b:
        mov     ax, [es:si+4]
        mov     [bcsab], ax
        mov     ax, [qbh+0x0C]
        mov     dx, n_stack
        call    lookup
        jnc     .c
        ret
.c:
        mov     bx, si
        mov     ax, bx
        add     ax, 18
        jc      .bad
        cmp     ax, [w4]
        ja      .bad
        mov     di, [es:bx+10]
        mov     si, n_symbol
        call    ncmp
        jne     .bad
        cmp     word [es:bx+16], 0
        jne     .bad
        clc
        ret
.bad:
        stc
        ret
```

```nasm
qbenv:
        cmp     word [dval], 0x0500
        jae     .a
        stc
        ret
.a:
        need    checkseg
        mov     es, [cs:datseg]
        mov     ax, [cs:qseg]
        add     ax, [w3]
        mov     [es:0D3h], ax
        mov     ax, [tailn]
        mov     [es:0D5h], ax
        mov     ax, [dval]
        mov     [es:0D7h], ax
        mov     ax, [bcsab]
        mov     [es:0B8h], ax
        mov     word [es:0BEh], qbsvc
        mov     [es:0C0h], cs
        mov     word [es:0C2h], qbsvc
        mov     [es:0C4h], cs
        mov     ax, [qbh+0x0A]
        mov     dx, n_vars
        call    lookup
        jnc     .b
        ret
.b:
        mov     bx, [es:si+4]
        mov     ax, [es:si+6]
        mov     es, ax
        cmp     word [es:bx+0Ch], 0
        jne     .bad
        cmp     byte [es:bx+0Eh], 13h
        jne     .bad
        mov     ax, [es:bx]
        mov     [cs:vars], ax
        mov     ax, [es:bx+2]
        mov     [cs:vars+2], ax
        call    rds
        clc
        ret
.bad:
        call    rds
        stc
        ret
```

* `DS:00D3` is the segment of the symbol block; `DS:00D5` /
  `DS:00D7` are the length and the start of the data image (`T`
  and `D`); `DS:00B8` is the near pointer of the `BC_SAB` entry
  (the library's runtime reads them). `DS:00BE` and `DS:00C2`
  are the far pointers of the gateway.
* The word at `b_ULVars+0Ch` must be 0 and the byte at `+0Eh`
  must be `13h`, otherwise the file is not a library (QB refuses
  it).

The **gateway** is a far procedure that gets the service number
in `DI`. `ALOADER` implements one service, 34 = `B$RUNERR` (`BX`
= BASIC error code). QuickBASIC does not return to the library
after it; it unwinds to the `ON ERROR` handler of the BASIC
program. `ALOADER` does the same with a saved stack pointer and
a resume address: the macro `gcall` records `SP` (before the
arguments were pushed) and the address after the call, the
service restores them:

```nasm
%macro gcall 2
        mov     [cs:gsp], sp
        add     word [cs:gsp], %1
        mov     word [cs:gres], %%r
        call    far [cs:fntab+%2]
%%r:
%endmacro
```

```nasm
qbsvc:
        cmp     di, 34
        je      .e
        retf
.e:
        mov     [cs:errcode], bx
        mov     ds, [cs:datseg]
        mov     sp, [cs:gsp]
        jmp     word [cs:gres]
```

Any other service number just returns here; a loader for
libraries that use more services has to implement them (the
numbers are in `QBLFMT.MD` section 11).

## B5. The life cycle (phases) with codes

The library is called through `b_ULVars[0]` with the **selector
in CX**, DS = data segment of QuickBASIC, and the stack of the
caller. Selectors without arguments return with `retf`; `10h`
and `0Ah` have one argument word and return with `retf 2`
(pushed by the caller, removed by the library). The sequence is
the one that QuickBASIC 4.5 and 4.0 use:

* 1
  - CX: `06h` AllocDataImage
  - when: right after the library is loaded
  - code in `ALOADER`: `phase`
* 2
  - CX: `10h` GETCOMMON
  - when: QB asks for the COMMON area (argument 0)
  - code in `ALOADER`: `phase10`
* 3
  - CX: `00h` Init
  - when: the library is initialised
  - code in `ALOADER`: `phase`
* 4
  - CX: `0Ah` GETPROC
  - when: once for every name the program calls, before it runs
  - code in `ALOADER`: `getproc`, `resolve`
* 5
  - CX: `00h` Init
  - when: the program starts
  - code in `ALOADER`: `phase`
* 6
  - when: the program calls the routines directly (`call far` to
    the address from step 4)
  - code in `ALOADER`: `demo`
* 7
  - CX: `02h` Term
  - when: the program ends
  - code in `ALOADER`: `phase`
* 8
  - CX: `04h` DataRelease
  - when: the library is released (the choice of `ALOADER`; QB
    4.5 was not seen to send it)
  - code in `ALOADER`: `phase`

```nasm
session:
        mov     dx, m_phases
        call    puts
        mov     cx, 6
        call    phase
        call    phase10
        mov     cx, 0
        call    phase
        mov     dx, m_resolve
        call    puts
        call    resolve
        mov     dx, m_start
        call    puts
        mov     cx, 0
        call    phase
        mov     dx, m_run
        call    puts
        call    demo
        mov     dx, m_term
        call    puts
        mov     cx, 2
        call    phase
        call    showsel
        mov     dx, m_unload
        call    puts
        mov     cx, 4
        call    phase
        ret
```

```nasm
phase:
        push    cx
        mov     dx, m_sel
        call    puts
        pop     ax
        push    ax
        call    puthexw
        call    crlf
        pop     cx
        mov     ds, [cs:datseg]
        call    far [cs:vars]
        jmp     rds
```

```nasm
phase10:
        mov     dx, m_sel
        call    puts
        mov     ax, 0x10
        call    puthexw
        mov     dx, m_common
        call    puts
        mov     ds, [cs:datseg]
        xor     ax, ax
        push    ax
        mov     cx, 0x10
        call    far [cs:vars]
        mov     [cs:r_ax], ax
        mov     [cs:r_dx], dx
        call    rds
        mov     ax, [cs:r_ax]
        or      ax, bx
        or      ax, [cs:r_dx]
        mov     dx, m_zero
        jz      .p
        mov     dx, m_nonzero
.p:
        call    puts
        ret
```

What the RLINK dispatcher does with them: `0Ah` and `10h` are
answered by the dispatcher itself; every other selector is
passed to the **entry procedure** of the library (`start` in
`DEMO.ASM`), which therefore sees `6, 0, 0, 2` and later `4` in
this run. `DEMO.ASM` records them and a routine `GETSEL` hands
them back, which is the last line of the output ("selectors seen
by start (hex): 0006 0000 0000 0002").

## B6. Calling the routines

The arguments are built **in the data segment that the library
sees**, because BASIC passes near pointers (`ARGS` is a scratch
area inside the free part of the region). DS is set to that
segment before the call and `gcall` makes the call; after the
call the program reads the result. The five cases of the table
in A3 are all here:

```nasm
demo:
        call    setds
        mov     word [ARGS], 41
        mov     ax, ARGS
        push    ax
        gcall   2, F_ADDONE
        mov     ax, [ARGS]
        call    rds
        mov     dx, t_addone
        call    kvd

        call    setds
        mov     word [ARGS+2], 1000
        mov     word [ARGS+4], 234
        mov     ax, ARGS+2
        push    ax
        mov     ax, ARGS+4
        push    ax
        gcall   4, F_SUMI
        call    rds
        mov     dx, t_sumi
        call    kvd

        call    setds
        mov     word [ARGS+6], 0x1170
        mov     word [ARGS+8], 1
        mov     word [ARGS+10], 5
        mov     word [ARGS+12], 0
        mov     ax, ARGS+6
        push    ax
        mov     ax, ARGS+10
        push    ax
        gcall   4, F_SUML
        call    rds
        mov     [cs:r_ax], ax
        mov     [cs:r_dx], dx
        mov     bx, t_suml
        call    kvl

        call    setds
        mov     ax, 7
        push    ax
        mov     ax, 8
        push    ax
        gcall   4, F_ADDBV
        call    rds
        mov     dx, t_addbv
        call    kvd

        mov     es, [cs:datseg]
        mov     di, ARGS+0x20
        mov     si, s_hello
        mov     cx, 6
        rep     movsb
        call    setds
        mov     word [ARGS+0x10], 5
        mov     word [ARGS+0x12], ARGS+0x20
        mov     ax, ARGS+0x10
        push    ax
        gcall   2, F_SLEN
        call    rds
        mov     dx, t_slen
        call    kvd

        call    setds
        mov     ax, ARGS+0x10
        push    ax
        gcall   2, F_UPCASE
        call    rds
        mov     dx, t_upcase
        call    puts
        mov     dx, ARGS+0x20
        call    putzx
        call    crlf

        call    setds
        mov     ax, [cs:datseg]
        push    ax
        mov     ax, ARGS+0x30
        push    ax
        mov     ax, 6
        push    ax
        mov     ax, 65
        push    ax
        gcall   8, F_FILLB
        call    rds
        mov     dx, t_fillb
        call    puts
        mov     dx, ARGS+0x30
        call    putzx
        call    crlf

        call    setds
        mov     word [ARGS+0x40], 0
        mov     word [ARGS+0x42], 0x4020
        mov     ax, ARGS+0x40
        push    ax
        mov     ax, ARGS+0x48
        push    ax
        gcall   4, F_COPYS
        mov     [cs:r_ax], ax
        mov     ax, [ARGS+0x4A]
        mov     [cs:r_dx], ax
        mov     ax, [ARGS+0x48]
        mov     bx, ax
        call    rds
        mov     dx, t_copys
        call    puts
        mov     ax, [cs:r_dx]
        call    puthexw
        mov     ax, bx
        call    puthexw
        mov     dx, t_ptr
        call    puts
        mov     ax, [cs:r_ax]
        call    puthexw
        call    crlf

        call    setds
        mov     word [ARGS+0x50], 0
        mov     word [ARGS+0x52], 0
        mov     word [ARGS+0x54], 0
        mov     word [ARGS+0x56], 0x4004
        mov     ax, ARGS+0x50
        push    ax
        mov     ax, ARGS+0x58
        push    ax
        gcall   4, F_COPYD
        mov     ax, [ARGS+0x5E]
        mov     [cs:r_ax], ax
        mov     ax, [ARGS+0x5C]
        mov     [cs:r_dx], ax
        mov     ax, [ARGS+0x5A]
        mov     bx, ax
        mov     ax, [ARGS+0x58]
        mov     cx, ax
        call    rds
        mov     dx, t_copyd
        call    puts
        mov     ax, [cs:r_ax]
        call    puthexw
        mov     ax, [cs:r_dx]
        call    puthexw
        mov     ax, bx
        call    puthexw
        mov     ax, cx
        call    puthexw
        call    crlf

        call    setds
        gcall   0, F_SYMSEG
        mov     [cs:r_ax], ax
        call    rds
        mov     dx, t_symseg
        call    puts
        mov     ax, [cs:r_ax]
        call    puthexw
        mov     ax, [cs:qseg]
        add     ax, [w3]
        cmp     ax, [cs:r_ax]
        mov     dx, t_same
        je      .sy
        mov     dx, t_diff
.sy:
        call    puts

        call    setds
        mov     word [cs:errcode], 0
        mov     ax, 5
        push    ax
        gcall   2, F_RAISE
        call    rds
        mov     ax, [cs:errcode]
        test    ax, ax
        jnz     .er
        mov     dx, t_noerr
        call    puts
        ret
.er:
        mov     dx, t_err
        call    kvd
        ret
```

* by reference: `push` the near pointers, in the order of the
  arguments; the routine removes them (`gcall 4, F_SUMI`: 4
  bytes of arguments);
* BYVAL: `push` the values;
* a far pointer BYVAL: the segment first, then the offset
  (`FILLB`);
* a string: a descriptor `{length, pointer}` in the data
  segment, and its text;
* SINGLE / DOUBLE: the pointer to the input, then the pointer to
  the result buffer, the result pointer comes back in `AX`;
* `RAISEERR`: the library calls the gateway; control comes back
  at the address saved by `gcall`, `errcode` holds the BASIC
  error.

## B7. Unload

DOS has no unload service for an overlay; the library is data in
a block that you own. After `Term` (`02h`) and `DataRelease`
(`04h`) free it:

```nasm
        mov     ax, [cs:qseg]
        mov     es, ax
        mov     ah, 49h
        int     21h
```

Do not free the block while a return address or a callback of
the library is still alive.

## B8. What `ALOADER` does not do

* It does not execute the entry far jump of the QB header
  (QuickBASIC never does either).
* It does not start libraries that need QuickBASIC services
  other than 34 (Microsoft's `LINK /Q` libraries); it only loads
  and checks them.
* It does not implement `08h` (CONERR), `0Ch`, `0Eh`; nobody
  calls them in these runs.
* It places the data tail inside one block with the other
  regions, so that one base is added to every relocation;
  QuickBASIC puts the tail at the end of its own data segment
  and the code in a separate block, with two bases.

---

(c) DosWorld 2026. This document is released into the public
domain under the Unlicense (<https://unlicense.org>): anyone may
copy, modify, publish, use, compile, sell or distribute it, for
any purpose, without conditions. It comes without any warranty.
