# QLBFMT - The QuickBASIC Quick Library (.QLB) format

Specification. Result of reverse engineering, released into the
public domain ((c) DosWorld 2026, Unlicense, see the end of this
file).

A Quick Library is the file that QuickBASIC 4.0 / 4.5 loads with
`QB /L name.QLB`, so that a BASIC program can `CALL` routines
written in assembler or C. The extension is `.QLB`. This
document defines the file, how a loader must load it, and the
interface between the loaded library, QuickBASIC and the BASIC
program.

Companion documents in this folder:

* `QLBUSE.MD` - how to use a library: from a BASIC program, and
  from your own DOS program that loads it.
* `QLBWRT.MD` - how to write and link a library in NASM.
* `QLOADER\` and `ALOADER\` - the working demos that every
  example here is taken from.

## 0. Conventions

* All numbers are little-endian. `0x` or a trailing `h` mean
  hexadecimal. A *paragraph* is 16 bytes.
* **[M]** measured: seen in files and in running QuickBASIC 4.50
  / 4.0. **[D]** documented by Microsoft in a file that ships
  with QuickBASIC. **[I]** inferred: follows from [M], the step
  is ours.
* MUST / MUST NOT / MAY are used for the rules a *writer* has to
  follow so that QuickBASIC accepts the file, and for the checks
  a *loader* has to make.
* Roles: the *writer* makes the file (Microsoft `LINK /Q`, or
  `RLINK qlb`); the *loader* reads it (QuickBASIC, or your own
  program, see `QLBUSE.MD`); the *library code* is what is
  inside.
* `QB data segment` is the data segment (DGROUP) of QB.EXE, the
  segment that DS has while QB calls into the library.
* Tested: QuickBASIC 4.50 and 4.0. The files of BASIC PDS 7.1
  (`QBX.QLB`) have the same layout; they were read, not run. The
  loader in `ALOADER\` accepts the real `QB.QLB` of QuickBASIC
  4.5 with every check of section 14.

## 1. What a .QLB is

A `.QLB` is an ordinary DOS **MZ executable** that nobody
executes. QuickBASIC reads it as a container with:

1. a **code image** (the routines, already linked),
2. a **data tail** that becomes the continuation of QB's own
   data segment,
3. a **symbol block**: a header (the "QB header"), three tables
   of 8-byte entries and a pool of names,
4. an MZ **relocation table** that turns the paragraph numbers
   inside 1-3 into segment values.

QuickBASIC does not *execute* anything of it at load time. It
maps the pieces into memory, applies the relocations, finds a
table of far pointers called `b_ULVars` and from then on calls
the library through it (section 9). BASIC `CALL` statements find
their routine through that interface, by name.

## 2. File layout

```
file offset          size      content
-------------------  --------  ------------------------------
0                    28        MZ header (section 3)
e_lfarlc (1Eh)       4*e_crlc  MZ relocation table (section 8)
...                            zero padding up to HDRB
HDRB = e_cparhdr*16  2         word C (section 4), always 0
HDRB + 2             w2*16     code image
HDRB + 2 + w2*16     2         word D = X (tail offset)
HDRB + 4 + w2*16     T         data tail, T = Z - D bytes
QPOS                 w4        symbol block, to end of file
```

Definitions (writer chooses `w2`, `D`, `T`; everything else
follows):

* `HDRB`
  - meaning: size of the MZ header in bytes
  - value: `e_cparhdr * 16`, at least `1Eh + 4 * e_crlc`; RLINK
    and LINK write `400h`
* `w2`
  - meaning: size of the code image in paragraphs
  - value: header word `w2`
* `D`, `X`
  - meaning: offset in QB's data segment where the data tail
    begins
  - value: the word at `HDRB + 2 + w2*16`
* `Z`
  - meaning: declared size of the data region in bytes
  - value: `(w3 - w2) * 16`
* `T`
  - meaning: bytes of data tail in the file
  - value: `Z - D`
* `w3`
  - meaning: end of the data region in paragraphs, and start of
    the symbol block
  - value: `w2 + Z / 16`, equal to `e_ss`
* `w4`
  - meaning: size of the symbol block in bytes
  - value: header word `w4`
* `QPOS`
  - meaning: file offset of the QB header
  - value: `(e_cparhdr + e_cs) * 16 + e_ip`, which also equals
    `HDRB + 4 + w2*16 + T`

Notes:

* The file is **shorter** than the image it declares: the bytes
  of QB's own data (offsets 4 to `D`) are not in the file.
  `e_cblp`/`e_cp` declare `HDRB + w3*16 + w4` bytes, more than
  the file holds; QuickBASIC does not use them [I] and a DOS
  loader must not trust them.
* **The image begins at `HDRB + 2`, not at `HDRB`** [M]. The
  word at `HDRB` is `ULCodeSquishSize` (`C`); it is 0 in every
  library that exists. The MZ field `e_cparhdr` does not count
  it. This is why DOS's own overlay call (`INT 21h AH=4Bh
  AL=03h`) cannot load a `.QLB`: it puts file offset `HDRB` at
  offset 0 of the block, so the whole image sits two bytes low
  [M]. A loader MUST seek to `HDRB + 2` itself.
* `D` is never smaller than 4. The data tail is stored right
  after the word `D`, and `D` is also the offset where it goes.
  `QB.QLB` of QuickBASIC 4.5 uses `D = 3317h`, `Z = 3380h`;
  `RLINK` uses `D = 3360h`, `Z = 3360h + T`. `Z` MUST NOT be
  smaller than QB's own data size: `Z = 3380h` is accepted by
  4.0 and 4.5, `1000h` and `400h` are refused [M].

## 3. The MZ header

28 bytes at file offset 0. Only the fields below are used.

* 00h
  - field: `e_magic`
  - rule: `4D 5A` ("MZ"). MUST.
* 02h, 04h
  - field: `e_cblp`, `e_cp`
  - rule: declared image size = `HDRB + w3*16 + w4` [I]; not
    used by loaders
* 06h
  - field: `e_crlc`
  - rule: number of relocation entries (section 8)
* 08h
  - field: `e_cparhdr`
  - rule: header size in paragraphs, `HDRB / 16`; 40h in all
    known files
* 0Ah, 0Ch
  - field: `e_minalloc`, `e_maxalloc`
  - rule: `FFFF`, `FFFF` as LINK writes them; not used by
    loaders
* 0Eh
  - field: `e_ss`
  - rule: `w3` (the segment of the symbol block, relocated like
    every other paragraph)
* 10h
  - field: `e_sp`
  - rule: 0
* 14h, 16h
  - field: `e_ip`, `e_cs`
  - rule: position of the QB header: `QPOS = (e_cparhdr + e_cs)
    * 16 + e_ip` [M][D]
* 18h
  - field: `e_lfarlc`
  - rule: offset of the relocation table, 1Eh

`CS:IP` does not point at code; it is the way QuickBASIC finds
the QB header [M]. The entry far jump inside the QB header
(section 5) is never executed [M].

## 4. The code image and the data tail

* **Code image**: `w2 * 16` bytes at `HDRB + 2`. Every code
  segment of the library starts on a paragraph boundary inside
  it; a code address is the pair `paragraph:offset` and is
  counted from the start of the image.
* **Data tail**: `T` bytes that go to offset `D` of QB's data
  segment. The bytes below `D` are QB's own and are neither read
  from the file nor written by the loader [M]. Data addresses in
  the library are paragraph numbers `w2 + (D + n) / 16` for the
  byte `n` of the tail.
* The **first 16 bytes of the tail** are the structure
  `b_ULVars` (section 9). The next 16 bytes are the area that
  the segment table calls `BC_SAB` (RLINK keeps it as scratch).
* RLINK stores the library's `.data` and `.bss` of every module
  in the tail (the `.bss` as zero bytes), each as its own
  segment value. A library routine MUST load DS itself, DS is
  QB's data segment when it is called.

## 5. The QB header (34 bytes)

At `QPOS`, which is also offset 0 of the symbol block.

* +00h
  - size: 1
  - field: `EAh`
  - rule: opcode of a far jump. MUST (check 1).
* +01h
  - size: 4
  - field: far address
  - rule: target of that jump: `offset, segment`; not executed
    [M]. RLINK writes the address of its entry procedure, LINK
    the C start-up `_main`. The segment word has a relocation
    entry.
* +05h
  - size: 1
  - field: version
  - rule: at least `02h`, otherwise QB refuses the file (check
    3) [M]
* +06h
  - size: 2
  - field: magic
  - rule: `6C75h` ("ul", for *user library*). MUST (check 2)
    [M][D]
* +08h
  - size: 2
  - field: `symStart`
  - rule: offset, from the QB header, of the **CODE table** [D]
* +0Ah
  - size: 2
  - field: `datStart`
  - rule: offset, from the QB header, of the **DATA table** [D]
* +0Ch
  - size: 2
  - field: `w0`
  - rule: offset of the **segment table**
* +0Eh
  - size: 2
  - field: `w1`
  - rule: 0 in the file; relocated: the segment of the code
    image
* +10h
  - size: 2
  - field: `w2`
  - rule: size of the code image in paragraphs; relocated: QB's
    data segment (this is the data base)
* +12h
  - size: 2
  - field: `w3`
  - rule: end of the data region in paragraphs (= `e_ss`);
    relocated: the segment where it ends
* +14h
  - size: 2
  - field: `w4`
  - rule: size of the symbol block in bytes
* +16h
  - size: 2
  - field: `w5`
  - rule: `= w2` in the file; relocated: QB's data segment. Far
    data of the library: segment
* +18h, +1Ah
  - size: 2+2
  - field: `w6`, `w7`
  - rule: size in bytes of the far data (low, high); 0 in all
    libraries
* +1Ch
  - size: 2
  - field: `w8`
  - rule: `= w2` in the file; relocated: QB's data segment. Far
    BSS of the library: segment
* +1Eh, +20h
  - size: 2+2
  - field: `w9`, `w10`
  - rule: size in bytes of the far BSS (low, high); 0 in all
    libraries

The six words at `+03h` (segment of the far jump), `+0Eh`
(`w1`), `+10h` (`w2`), `+12h` (`w3`), `+16h` (`w5`) and `+1Ch`
(`w8`) have entries in the relocation table (section 8) and are
changed by the loader: after relocation `w2` is no longer a
size. **A loader that needs the sizes MUST read them from the
file before it applies the relocation** (or read them from a
copy; `ALOADER` keeps the unrelocated 34 bytes in `qbh`).

The checks QB makes on these 34 bytes before it does anything
else (it refuses the file with *Invalid format*) [M]:

1. the byte at `+00h` is `EAh`,
2. the word at `+06h` is `6C75h`,
3. the byte at `+05h` is at least 2.

## 6. The three tables and the name pool

All three tables use the same **8-byte entry**, and each ends
with a zero **flags** word. The next table starts 2 bytes after
the end of the previous one (the terminator is only that word).

```
+0  flags      word
+2  nameStart  word   offset, from the QB header, of the
                      NUL-terminated name
+4  offset     word   offset of the symbol in its segment
                      (flags 5: the value itself)
+6  segment    word   paragraph of the symbol (relocated by
                      the loader; flags 5: 0)
```

* CODE
  - at: `symStart`
  - flags: 1
  - content: exported code symbols. **May be empty** (just the
    terminator) [M]. RLINK fills it, `/nonames` leaves it empty.
* DATA
  - at: `datStart`
  - flags: 2 (5 = absolute value)
  - content: data symbols. MUST contain `b_ULVars` (flags 2).
* SEGMENT
  - at: `w0`
  - flags: 3 (4 for `NMALLOC`, `ENMALLOC`)
  - content: segments of the library; rules below

* **Names** are NUL-terminated and stored after the three tables
  (the "name pool"). QB walks the pool when it loads the file
  and **upper-cases every name in memory** [M]; the file keeps
  the case it was written with. Names that QB looks for are
  compared in upper case: `B_ULVARS`.
* **Exactly five names are looked up by QB** [M]: `B_ULVARS` in
  the DATA table, and `NULL`, `STACK`, `SYMBOL`, `BC_SAB` in the
  SEGMENT table. Nothing else is read by name, in particular
  **QB does not resolve a `CALL` from the CODE table** (section
  12).
* **SEGMENT table rules** (checks 4-7 of section 14): `NULL` has
  the segment `w2` (the data base = QB's data segment); the
  entry after `NULL` is above it (RLINK writes `_DATA` at `w2 +
  D/16`); `BC_SAB` exists, its address is kept by QB; `STACK` is
  directly followed by `SYMBOL`, and the table ends right after
  `SYMBOL`. The minimal SEGMENT table that QuickBASIC 4.0 and
  4.5 accept is `NULL, _DATA, BC_SAB, STACK, SYMBOL` (all flags
  3); `STACK` and `SYMBOL` are at paragraph `w3` [M].
* **Flags**: 1 code, 2 data, 3 segment, 4 segment (the near-heap
  markers), 5 absolute value (segment 0, the offset field is the
  value, e.g. `__acrtused = 9876h`). There is no flag for
  "private"; a BASIC name starts with a letter, so a name
  starting with `_` or `$` cannot be called from BASIC [M].
* `LINK /Q` exports every public name except those that start
  with `B$` or `b$`; RLINK exports every `global` code symbol
  (`/nonames` leaves the table empty). Both keep the spelling of
  the object (`_ArbAdd` stays `_ArbAdd`).

## 7. Memory model - where the three regions go

The declared image is addressed in paragraphs, counted from the
code image. Three regions [M]:

```
code image    paragraphs [0, w2)
    file:     HDRB + 2, w2*16 bytes
    loaded:   a block of w2 paragraphs (code segment)
data region   paragraphs [w2, w3), Z bytes
    file:     the word D, then T = Z - D bytes
    loaded:   QB's data segment, tail at offset D
symbol block  paragraphs [w3, w3 + ceil(w4/16))
    file:     QPOS, w4 bytes
    loaded:   a block of w4 bytes (symbol segment)
```

* QuickBASIC keeps the library's data in **its own data
  segment**, as the continuation of its data: the data base `w2`
  *is* QB's data segment, an offset in the data region is an
  offset in that segment, and the tail goes to offset `D`. It
  makes room by moving its own program image up. The bytes from
  offset 4 to `D` (`S = C + D - 4` of them) are QB's.
* The symbol block is read from file offset `HDRB + w3*16 - S`
  which equals `QPOS`. A writer places it right after the tail.
* The code image is loaded to a separate block; QB's variable
  `b$ULSymSeg` (`DS:00D3`) receives the segment of the symbol
  block.
* A loader that is *not* QuickBASIC may place the three regions
  in **one contiguous block** `[w2 + ... paragraphs]` so that
  `data segment = block + w2` and `symbol segment = block + w3`;
  every relocation then adds the same base `block`. `ALOADER`
  does this; the block has `w3 + ceil(w4/16)` paragraphs
  (`QLBUSE.MD`).

## 8. Relocation

The MZ relocation table (`e_crlc` entries of two words,
**`offset` first, then `segment`**, at `e_lfarlc`) names the
words of the declared image that hold a paragraph number. The
entry gives the location as `segment * 16 + offset` in the
declared image (so the paragraph is counted like in section 7:
below `w2` it is in the code image, from `w2` to below `w3` in
the data region, and `w3` is the symbol block).

A loader adds to the **word** at that location:

* the segment of the code image, if the stored value is below
  `w2`;
* QB's data segment minus `w2`, if the stored value is `w2` or
  more.

(A contiguous block, section 7, adds the block segment for
both.) The entries of `QB.QLB` are 143: 113 in the symbol block
(the segment word of every table entry and six words of the QB
header), 27 in the code (far pointers) and 3 in the data tail
(the three far pointers of `b_ULVars`) [M].

A writer MUST give an entry to: the segment word of every table
entry (location: paragraph `w3`, offset = offset of the entry in
the block + 6); the six QB header words of section 5 (offsets 3,
14, 16, 18, 22 and 28 of the block, in decimal); the three
segment words of `b_ULVars`; every segment value in code and
data (`mov ax, seg x`, far calls and jumps, far pointers). The
sizes `w4`, `w6`, `w7`, `w9`, `w10` have no entry. Example:
`HELLO.QLB` of section 15 has 20 entries: 3 in the code image
(segment 2), 3 in the data tail (the far pointers of `b_ULVars`,
segment 034Ah) and 14 in the symbol block (segment 034Ch): the
six header words and the segment word of the eight table entries
(2 CODE + 1 DATA + 5 SEGMENT).

A loader SHOULD refuse an entry whose word is outside the three
regions or straddles the end of a 64 KB segment (`ALOADER`
does).

## 9. b_ULVars and the dispatcher: the life cycle of a library

The data table entry `b_ULVars` points to 16 bytes in the tail
[M]:

```
+00h  far pointer 1  the DISPATCHER (offset, segment);
                     QB calls the library through it
+04h  far pointer 2  B$RTtoULNear in Microsoft libraries;
                     RLINK: a "retf" stub
+08h  far pointer 3  a stack-check routine in Microsoft
                     libraries; RLINK: a "retf" stub
+0Ch  word           0      (QB checks)
+0Eh  word           0013h  (QB checks, low byte is read)
```

**The dispatcher** is a far procedure of the library. QB calls
it with the **selector in CX** (CH = 0) and DS = QB's data
segment. The selectors, and what the dispatcher MUST do [M]:

* 00h
  - name: Init
  - ends with: `retf`
* 02h
  - name: Term
  - ends with: `retf`
* 04h
  - name: DataRelease
  - ends with: `retf`
* 06h
  - name: AllocDataImage
  - ends with: `retf`
* 08h
  - name: CONERR
  - arguments: 1 word
  - ends with: `retf 2`
* 0Ah
  - name: **GETPROC**
  - arguments: near pointer to a BASIC string descriptor
    `{length, pointer}` (a temporary string, section 12); DX =
    flag (`0040h` for CDECL)
  - returns: far address in `DX:AX`, `0:0` if unknown
  - ends with: `retf 2`
* 0Ch
  - name: GetData
  - arguments: 1 word (name descriptor)
  - returns: far address in `DX:AX`
  - ends with: `retf 2`
* 0Eh
  - name: GetSeg
  - arguments: 1 word (name descriptor)
  - returns: far address in `DX:AX`
  - ends with: `retf 2`
* 10h
  - name: GETCOMMON
  - arguments: 1 word (descriptor, or 0)
  - returns: `BX`, `DX` = offset and size of the COMMON area,
    `AX=BX=DX=0` if none
  - ends with: `retf 2`

**Selectors from 08h on take one word and the dispatcher MUST
end with `retf 2`; selectors 00h-06h end with `retf`. A mistake
here hangs QuickBASIC** [M].

**Order of the calls** (measured with a logging dispatcher on QB
4.50 and 4.0, `QB /L lib /RUN prog.bas`) [M]:

```
06h AllocDataImage  when the library is loaded
10h GETCOMMON       QB asks for the COMMON area
00h Init            the library is initialised
0Ah GETPROC         one for every CALL / SUB call / FUNCTION
                    reference in the BASIC source, before the
                    program runs - not one per execution
00h Init            the program starts (a second Init)
...                 the program runs; routines are called
                    directly, without the dispatcher
02h Term            the program ends (SYSTEM)
```

`04h DataRelease`, `08h`, `0Ch`, `0Eh` were not seen in these
runs. The meaning of the first six is [I] from the code of
Microsoft's runtime (`BQLB45.LIB`): Init clears the library's
BSS and starts its C runtime, Term runs its terminators,
AllocDataImage saves a pristine copy of the data (so that a
second `RUN` can restore it), DataRelease frees that copy,
CONERR hands a BASIC run-time error to the library, GETCOMMON
reports the COMMON area.

A library made by RLINK implements `0Ah` and `10h` itself and
forwards every other selector to its *entry procedure* as a
Pascal-style far call: the selector is a word parameter on the
stack and also in CX, the procedure ends with `retf 2`
(`QLBWRT.MD` section 4).

## 10. Calling a routine (the BASIC convention)

`GETPROC` returns the far address of the routine; QB then calls
it directly: `call far`, with the BASIC convention [M]:

* arguments are pushed **left to right**; the routine pops them
  itself (`retf 2*n`);
* **by reference** (the default): each argument is a **near
  pointer** (in DS = QB's data segment) to the variable: INTEGER
  2 bytes, LONG 4, SINGLE 4, DOUBLE 8 (`DECLARE SUB x (a AS
  INTEGER)`);
* a **variable-length string** argument is a near pointer to the
  string descriptor `{length word, near pointer to the text}`;
  the routine may change the characters in place;
* **BYVAL** (`DECLARE ... (BYVAL a AS INTEGER)`): the value
  itself is pushed (one word for INTEGER); an array element is
  passed as `BYVAL VARSEG(x), BYVAL VARPTR(x)`: two words,
  segment then offset: a far pointer;
* **return values**: INTEGER in `AX`; LONG in `DX:AX`; SINGLE
  and DOUBLE: QB passes one **extra last argument**, a near
  pointer to a buffer in its own data; the routine stores the 4
  or 8 bytes there and returns that pointer in `AX`. (A
  `FUNCTION` returning a STRING was not examined.)
* the routine MUST preserve `BP`, `SI`, `DI`, `DS` and `SS:SP`;
  `AX`, `BX`, `CX`, `DX`, `ES` and the flags are free. Clear the
  direction flag before string instructions.
* it runs on QB's stack; keep its use small.
* **`CDECL` declarations** use the C convention [M]: the
  arguments are pushed **right to left** (after `push bp / mov
  bp,sp` the *first* argument is at `[bp+6]`), by reference
  unless `BYVAL` is written, the routine ends with a plain
  `retf` and the caller removes the arguments. The name that QB
  looks up differs too (section 12).

## 11. What the library gets from QuickBASIC (imports)

A `.QLB` has **no import table** [M]. What a library takes from
QB it takes from fixed places that `LINK /Q` binds against
`BQLB45.LIB`:

* **Variables**: the DATA table lists many entries below offset
  `0120h`; these are variables of QB.EXE at the same offset of
  QB's data segment (`b_errlin = 010Ch`, `b_errnum = 010Ah`,
  `b_errmod = 0106h`, `b_erradr = 0102h` ...). The library
  addresses them with DS = QB's data segment. QB writes four
  words when it loads a library [M]: `DS:00D3` = segment of the
  symbol block (`b$ULSymSeg`), `DS:00D5` = length of the data
  image, `DS:00D7` = start of the data image, `DS:00B8` = near
  pointer from the `BC_SAB` entry.
* **Procedures of QB**: two far pointers in QB's data segment,
  `DS:00BE` (`b$pULtoRTFar`, for `jmp far`) and `DS:00C2`
  (`b$pULtoRTNear`, for `call far`) [M]. Every QB service is a
  **number** in `DI` (or `BX`) sent through the pointer; no name
  is passed. Numbers: 0, 2, ..., 42 for 22 services (for example
  34 = `B$RUNERR`, 24 = `B$STDALC`, 40 = `B$IFHAlloc`, 42 =
  `B$FHDealloc`), and 0, 4, ..., 20 for six more (`B$ULReload`,
  `B$IStop`, `B$END`, `B$GetNmalloc`, `B$IEND`, `B$SetUEvent`)
  [M].
* **Raising a BASIC error** [M]: `BX` = error code, `DI` = 34,
  `call far [DS:00C2]`. QB treats it as a run-time error of the
  program: `ON ERROR GOTO` sees `ERR` = the code, `RESUME NEXT`
  continues after the `CALL`. The call does not return into the
  library.
* A name that is not provided by `BQLB45.LIB` cannot be
  imported: `LINK` reports `L2029 unresolved external` and
  writes a call to `0000:0000`.
* **RLINK** resolves such imports itself: a module writes
  `extern B$RUNERR` or `extern b_errnum`, RLINK writes the
  thunks and the data symbols (table in `DOC\QLB-IMP.MD` section
  9, use in `QLBWRT.MD` section 4). The services and variables
  are those of QB 4.50.

## 12. How QuickBASIC finds a routine by name

QB calls `GETPROC` (selector 0Ah) **once for every `CALL`, SUB
call and FUNCTION reference in the source, before the program
runs** [M]. That includes the SUBs and FUNCTIONs that the BASIC
program defines itself: the library answers `0:0` for them and
QB uses its own. The argument is the name **as written in the
source** (a dot kept, no type suffix, no second try), `DX` is a
flag, and the library answers with the far address in `DX:AX` or
`0:0`. If nothing defines the name, QB stops with an error (a
dialog; a script sees a hang).

**What reaches `GETPROC`** [M] (QB 4.50, logging dispatcher):

```
DECLARE SUB HELLO ()                 "HELLO"  DX = 0000h
DECLARE SUB HELLO CDECL ()           "HELLO"  DX = 0040h
DECLARE SUB HELLO CDECL ALIAS "x" () "x"      DX = 0000h
DECLARE SUB Hel.lo ()                "Hel.lo" DX = 0000h
```

`CDECL` sets `DX = 0040h`, and the library turns that into the
underscore of a C symbol: a C routine `_foo` is declared
`DECLARE FUNCTION foo CDECL`. `ALIAS "_foo"` reaches the same
symbol with the BASIC convention. `FOO` (no underscore) is not
found by `foo CDECL`, and `_foo` is not found by a plain `foo`,
in Microsoft's libraries as in RLINK's. `ALIAS "foo" CDECL`
looks for `foo` (the alias is passed as written, `DX = 0`).
BASIC reserved words (`EXIT`, `OFF`, ...) cannot be routine
names and hang the editor in a `DECLARE`.

**The lookup of Microsoft's runtime** (read from `BQLB45.LIB`,
`MSRT.LST`, and measured with libraries written by `LINK /Q`):

1. If `DX` is not zero, the name becomes `_` + name. Every `.`
   becomes `_` (read from the code).
2. The name is searched in the **CODE table**, then in the
   **DATA table** [M]. The comparison ignores case (QB
   upper-cases the stored names), and the type word of the entry
   is not looked at (set to `FFFFh` it still binds). Renaming an
   entry (`_arbadd` to `_arbXdd`) makes it unfindable: for a
   library without a dispatcher of its own the directory is what
   QB reads.
3. The answer is accepted when its segment is not below `w1`
   (the code base); otherwise `0:0` (read from the code).

**The name is a temporary string that the library MUST release**
[M]. The descriptor `{length, pointer}` belongs to QuickBASIC's
string space. The library frees it with the QB service
`B$STDALCTMP` (`BX` = the descriptor, `DI` = 26, `call far
[DS:00C2]`, section 11); `B$STDALCALLTMP` (28) works as well,
while 0, 2, 22, 24 (`B$STDALC`) and 40 do not. Microsoft's
runtime copies the name into a local string and frees that. A
library that does not free it leaks one temporary string per
lookup, and QB hangs after about a dozen lookups (12 lookups of
an unknown name were fine, 30 hung, on 4.50 and 4.0); the more
calls a program contains, the earlier it happens. RLINK's
runtime skips the call when the far pointer at `DS:00C2` is
`0:0`, so a loader that does not provide the gateway still
works.

**Where the names are kept.** A library may keep them anywhere:
with an **empty CODE table** and a dispatcher that finds the
names itself, it loads and works in 4.0 and 4.5; a dispatcher
that answers `GETPROC` with the right far address binds without
the directory [M]. RLINK's runtime uses a hash table: `hash =
h*33 + c` over the upper-cased name, 16 bits, `h` starts at
`1505h` (`0B604h` for `DX` not zero: the seed already includes
the `_`); slot = `{hash OR 8000h, offset of the name entry}`,
linear probing, `slots = 2^k >= 2 * names`; the stored names are
upper case and keep their underscore, and the name itself is
compared, so a collision never gives a wrong routine
(`QLBWRT.MD` section 5). A *tool* or a loader of your own that
does not want to call the dispatcher reads the CODE table
instead (`QLBUSE.MD`, B3).

## 13. Limits

* Only **one** library can be loaded: `QB /L a.QLB /L b.QLB`
  prints the usage line (`Valid options: ... /L [lib] ...`) and
  does not start [M]. Microsoft's Knowledge Base says the same:
  `.QLB` files cannot be merged; link all modules into one
  (`rlink qlb` takes many `.RDF` files; `LINK /Q` takes many
  objects).
* The data region is one 64 KB segment: `Z < 10000h`, `D + T <=
  Z`; code segments are limited to 64 KB each, the whole image
  to about 1 MB.
* RLINK exports at most about 2000-2500 names (the hash table
  and the name entries must stay under 64 KB; `Too many
  symbols.`).

## 14. The refusal checklist: what QB checks

A file is refused with *Invalid format* (or the run does not
start) unless [M]:

1. MZ signature; QB header position by `(e_cparhdr + e_cs)*16 +
   e_ip`; byte `+00h` is `EAh`;
2. word `+06h` is `6C75h`;
3. byte `+05h` is at least 2;
4. SEGMENT table: `NULL` exists and is at QB's data base (`w2`);
5. the entry after `NULL` is high enough above it;
6. `BC_SAB` exists;
7. `STACK` is directly followed by `SYMBOL`, and the table ends
   right after `SYMBOL`;
8. DATA table has `b_ULVars`; the word at `+0Ch` is 0 and the
   byte at `+0Eh` is `13h`;
9. `Z` (declared data) fits in QB's free memory (*Out of
   memory*) and is not smaller than QB's own data;
10. the dispatcher returns correctly (`retf` / `retf 2`), or
    QuickBASIC hangs.

## 15. A worked example: the bytes of a small library

The library below is `HELLO.ASM` of `TEST\QLB` (one routine
`HELLO`) linked with `rlink qlb`; 1537 bytes. Its code image is
20 paragraphs, `D = 3360h`, `T = 32`, `Z = 3380h`, `w3 = 034Ch`.
The code image, the tail and the zero padding are summarised.

```
0000  4D 5A
      e_magic = 5A4D
0002  5D 01
      e_cblp = 015D
0004  1D 00
      e_cp = 001D
0006  14 00
      e_crlc = 0014
0008  40 00
      e_cparhdr = 0040
000A  FF FF
      e_minalloc = FFFF
000C  FF FF
      e_maxalloc = FFFF
000E  4C 03
      e_ss = 034C
0010  00 00
      e_sp = 0000
0012  00 00
      e_csum = 0000
0014  04 00
      e_ip = 0004
0016  16 00
      e_cs = 0016
0018  1E 00
      e_lfarlc = 001E
001A  00 00
      e_ovno = 0000
001E  0B 01 02 00
      relocation 0: offset 010B, segment 0002
0022  15 01 02 00
      relocation 1: offset 0115, segment 0002
0026  02 00 02 00
      relocation 2: offset 0002, segment 0002
002A  02 00 4A 03
      relocation 3: offset 0002, segment 034A
    (20 relocation entries in all, up to file offset 006E;
    zero padding up to 0400)
0400  00 00
      C = ULCodeSquishSize = 0000
0402  CA 02 00 1E 0E 1F ...
      code image, 0014 paragraphs = 320 bytes, up to 0542
0542  60 33
      D = 3360, the offset of the tail in QB data segment
0544  06 00 02 00 21 00 02 00 ...
      tail: b_ULVars: far pointers (offset, segment) to the
      dispatcher and two stubs
    (tail 32 bytes in all, up to 0564; D + T = 3380)
0564  EA 00 00 00 00
      QB header: EAh far jump 0000:0000
0569  02
      version = 02
056A  75 6C
      magic = 6C75
056C  22 00
      symStart = 0022 (CODE table)
056E  34 00
      datStart = 0034 (DATA table)
0570  3E 00
      w0 segment table offset = 003E
0572  00 00
      w1 (0; relocated: code segment) = 0000
0574  14 00
      w2 code paragraphs = 0014
0576  4C 03
      w3 end of data, paragraphs = 034C
0578  9D 00
      w4 symbol block bytes = 009D
057A  14 00
      w5 = w2 = 0014
057C  00 00
      w6 far data size low = 0000
057E  00 00
      w7 far data size high = 0000
0580  14 00
      w8 = w2 = 0014
0582  00 00
      w9 far BSS size low = 0000
0584  00 00
      w10 far BSS size high = 0000
0586  01 00 90 00 00 00 00 00
      CODE entry 0: flags 0001, name +0090 (start), offset
      0000, segment 0000
058E  01 00 96 00 03 00 00 00
      CODE entry 1: flags 0001, name +0096 (HELLO), offset
      0003, segment 0000
0596  00 00
      CODE table terminator
0598  02 00 68 00 60 33 14 00
      DATA entry 0: flags 0002, name +0068 (b_ULVars), offset
      3360, segment 0014
05A0  00 00
      DATA table terminator
05A2  03 00 71 00 00 00 14 00
      SEGMENT entry 0: flags 0003, name +0071 (NULL), offset
      0000, segment 0014
05AA  03 00 76 00 00 00 4A 03
      SEGMENT entry 1: flags 0003, name +0076 (_DATA), offset
      0000, segment 034A
05B2  03 00 7C 00 10 00 4A 03
      SEGMENT entry 2: flags 0003, name +007C (BC_SAB), offset
      0010, segment 034A
05BA  03 00 83 00 00 00 4C 03
      SEGMENT entry 3: flags 0003, name +0083 (STACK), offset
      0000, segment 034C
05C2  03 00 89 00 00 00 4C 03
      SEGMENT entry 4: flags 0003, name +0089 (SYMBOL), offset
      0000, segment 034C
05CA  00 00
      SEGMENT table terminator
05CC  62 5F 55 4C 56 61 72 73 ...
      name pool:
      'b_ULVars|NULL|_DATA|BC_SAB|STACK|SYMBOL|start|HELLO||'
0601  end of file (1537 bytes)
```

Position of the QB header: `(0040h + 0016h) * 16 + 0004h =
0564h`, and `HDRB + 4 + w2*16 + T = 400h + 4 + 140h + 20h =
564h`. The symbol block size `w4 = 9Dh` (157 bytes) = 564h to
the end of file at 601h.

## 16. Assembler examples

Every routine below is from `ALOADER\ALOADER.ASM` (NASM, 8086)
and was run. The complete use is in `QLBUSE.MD`.

**Locate and check the QB header** (checks 1-3; `mzh` holds the
28 bytes of the MZ header, `qbh` receives the 34 bytes):

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

**Read the sizes and compute the block size** (`w3 +
ceil(w4/16)` paragraphs, and `Z < 10000h`):

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

**Find a name in a table** (`AX` = table offset from the QB
header, `DX` = upper-case name; returns the entry at `ES:SI`;
the same routine walks the CODE, DATA and SEGMENT tables, and
compares in upper case like QB does):

```nasm
ncmp:
        push    si
        push    di
.l:
        cmp     di, [w4]
        jae     .nz
        mov     al, [es:di]
        cmp     al, 'a'
        jb      .u
        cmp     al, 'z'
        ja      .u
        sub     al, 20h
.u:
        cmp     al, [si]
        jne     .x
        inc     si
        inc     di
        test    al, al
        jnz     .l
        jmp     .x
.nz:
        or      al, 1
.x:
        pop     di
        pop     si
        ret
```

```nasm
lookup:
        mov     si, ax
        mov     ax, [cs:qseg]
        add     ax, [w3]
        mov     es, ax
.n:
        mov     ax, si
        add     ax, 8
        jc      .no
        cmp     ax, [w4]
        ja      .no
        cmp     word [es:si], 0
        je      .no
        mov     di, [es:si+2]
        push    si
        mov     si, dx
        call    ncmp
        pop     si
        je      .yes
        add     si, 8
        jmp     .n
.yes:
        clc
        ret
.no:
        stc
        ret
```

**Check the SEGMENT table** (checks 4-7):

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

**Apply the relocation entries** (each entry: location
`seg*16+off` is inside a loaded region, the word does not
straddle a segment end, then `word += block segment`):

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

## 17. Sources and confidence

* `MSRT.LST` (in this folder) is a disassembly of the runtime
  that `LINK /Q` puts into every library: the dispatcher, the
  service thunks, `GETPROC`, `Init`, `Term` ... with the
  variables of QB's data segment.

* Measured against QuickBASIC 4.50 (`QB.EXE` 278804 bytes) and
  4.0 with libraries written by `RLINK`, with Microsoft's
  `QB.QLB`, and with a logging dispatcher; the loader of
  QuickBASIC (`B$ULLoad`) was read from its disassembly. Longer
  notes are `DOC\QLB.MD`, `DOC\QLB-IMP.MD` and `DOC\QLBRT.MD` of
  the RTools repository.
* Open: the behaviour of selectors `04h 08h 0Ch 0Eh`, the flag
  `4` of `NMALLOC/ENMALLOC`, non-zero `w6..w10`, STRING function
  results, whether other parts of QB (IDE, debugger) read the
  tables by other names, BASIC PDS 7.1 at run time.

---

(c) DosWorld 2026. This document is released into the public
domain under the Unlicense (<https://unlicense.org>): anyone may
copy, modify, publish, use, compile, sell or distribute it, for
any purpose, without conditions. It comes without any warranty.
