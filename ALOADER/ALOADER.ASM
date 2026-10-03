; (c) DosWorld 2026
;
; This is free and unencumbered software released into the
; public domain.
;
; Anyone is free to copy, modify, publish, use, compile, sell,
; or distribute this software, either in source code form or as
; a compiled binary, for any purpose, commercial or
; non-commercial, and by any means.
;
; In jurisdictions that recognize copyright laws, the author or
; authors of this software dedicate any and all copyright
; interest in the software to the public domain. We make this
; dedication for the benefit of the public at large and to the
; detriment of our heirs and successors. We intend this
; dedication to be an overt act of relinquishment in perpetuity
; of all present and future rights to this software under
; copyright law.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
; KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
; WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
; PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
; AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
; OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;
; For more information, please refer to <https://unlicense.org>

        bits 16
        cpu 8086
        global  start

%define ARGS     0x0400
%define GPDESC   (ARGS+0x7C)
%define GPNAME   (ARGS+0x80)

%define F_ADDONE 0
%define F_SUMI   4
%define F_SUML   8
%define F_ADDBV  12
%define F_SLEN   16
%define F_UPCASE 20
%define F_FILLB  24
%define F_COPYS  28
%define F_COPYD  32
%define F_RAISE  36
%define F_SYMSEG 40
%define F_GETCNT 44
%define F_GETSEL 48

%macro need 1
        call    %1
        jnc     %%o
        ret
%%o:
%endmacro

%macro jcf 1
        jnc     %%o
        jmp     %1
%%o:
%endmacro

%macro gcall 2
        mov     [cs:gsp], sp
        add     word [cs:gsp], %1
        mov     word [cs:gres], %%r
        call    far [cs:fntab+%2]
%%r:
%endmacro

section .text

sv_ds   dw 0
pspseg  dw 0
qhandle dw 0
qseg    dw 0
datseg  dw 0
gsp     dw 0
gres    dw 0
errcode dw 0
rdn     dw 0
r_ax    dw 0
r_dx    dw 0
cur     dw 0
vars    dd 0
loadonly db 0
fntab   times 13 dd 0

start:
        cld
        mov     [cs:pspseg], ds
        mov     ax, seg banner
        mov     [cs:sv_ds], ax
        call    rds
        call    gettail
        mov     dx, banner
        call    puts
        mov     dx, m_file
        call    puts
        mov     dx, qlbname
        call    putz
        call    crlf
        call    loadqlb
        jnc     .ld
        mov     dx, m_loadbad
        call    puts
        jmp     bye
.ld:
        call    report
        call    qbenv
        jnc     .env
        mov     dx, m_envbad
        call    puts
        jmp     bye
.env:
        mov     dx, m_envok
        call    puts
        cmp     byte [cs:loadonly], 0
        je      .full
        call    showtab
        jmp     bye
.full:
        call    session
bye:
        call    rds
        cmp     word [cs:qseg], 0
        je      .x
        mov     ax, [cs:qseg]
        mov     es, ax
        mov     ah, 49h
        int     21h
        mov     dx, m_freed
        call    puts
.x:
        mov     dx, m_bye
        call    puts
        mov     ax, 4C00h
        int     21h

rds:
        push    ax
        mov     ax, [cs:sv_ds]
        mov     ds, ax
        mov     es, ax
        pop     ax
        ret

setds:
        mov     ax, [cs:datseg]
        mov     ds, ax
        mov     es, ax
        ret

gettail:
        push    ds
        mov     ds, [cs:pspseg]
        mov     si, 0x81
.s:
        lodsb
        cmp     al, ' '
        je      .s
        cmp     al, 9
        je      .s
        cmp     al, 13
        je      .def
        cmp     al, '/'
        jne     .tok
        mov     byte [cs:loadonly], 1
.o:
        lodsb
        cmp     al, ' '
        ja      .o
        cmp     al, 13
        je      .def
        jmp     .s
.tok:
        mov     di, qlbname
        mov     cx, 62
.c:
        stosb
        lodsb
        cmp     al, ' '
        jbe     .e
        loop    .c
.e:
        mov     byte [es:di], 0
        cmp     al, 13
        jne     .s
.def:
        pop     ds
        ret

mulp:
        mov     cx, 16
        mul     cx
        ret

shl4:
        mov     cl, 4
        shl     dx, cl
        mov     bx, ax
        shl     ax, cl
        mov     cl, 12
        shr     bx, cl
        or      dx, bx
        ret

seekto:
        mov     bx, [cs:qhandle]
        mov     ax, 4200h
        int     21h
        ret

rdexact:
        mov     bx, [cs:qhandle]
        mov     ah, 3Fh
        int     21h
        jc      .r
        cmp     ax, cx
        je      .r
        stc
.r:
        ret

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

fullread:
        mov     ax, [cntlo]
        or      ax, [cnthi]
        jz      .ok
        stc
        ret
.ok:
        ret

clrblk:
        mov     dx, [qparas]
        mov     bx, [cs:qseg]
        xor     ax, ax
.l:
        mov     es, bx
        xor     di, di
        mov     cx, 8
        rep     stosw
        inc     bx
        dec     dx
        jnz     .l
        jmp     rds

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

loadqlb:
        mov     word [cs:qseg], 0
        mov     dx, qlbname
        mov     ax, 3D00h
        int     21h
        jnc     .o
        ret
.o:
        mov     [cs:qhandle], ax
        call    loadbody
        pushf
        mov     bx, [cs:qhandle]
        mov     ah, 3Eh
        int     21h
        popf
        ret

loadbody:
        need    rdmz
        need    rdqb
        need    rdsize
        need    alloc
        need    rdimage
        need    rdsym
        jmp     relocate

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

qbsvc:
        cmp     di, 34
        je      .e
        retf
.e:
        mov     [cs:errcode], bx
        mov     ds, [cs:datseg]
        mov     sp, [cs:gsp]
        jmp     word [cs:gres]

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

report:
        mov     dx, m_blk
        mov     ax, [cs:qseg]
        call    kv
        mov     dx, m_par
        mov     ax, [qparas]
        call    kv
        mov     dx, m_w2
        mov     ax, [w2]
        call    kv
        mov     dx, m_w3
        mov     ax, [w3]
        call    kv
        mov     dx, m_w4
        mov     ax, [w4]
        call    kv
        mov     dx, m_dseg
        mov     ax, [cs:datseg]
        call    kv
        mov     dx, m_dval
        mov     ax, [dval]
        call    kv
        mov     dx, m_tail
        mov     ax, [tailn]
        call    kv
        mov     dx, m_rel
        mov     ax, [mzh+6]
        call    kvd
        ret

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

showsel:
        call    setds
        gcall   0, F_GETCNT
        mov     [cs:r_ax], ax
        call    rds
        mov     dx, t_seen
        call    puts
        xor     bx, bx
.l:
        cmp     bx, [cs:r_ax]
        jae     .e
        push    bx
        call    setds
        pop     bx
        push    bx
        push    bx
        gcall   2, F_GETSEL
        mov     [cs:r_dx], ax
        call    rds
        mov     ax, [cs:r_dx]
        call    puthexw
        mov     al, ' '
        call    putchar
        pop     bx
        inc     bx
        jmp     .l
.e:
        call    crlf
        ret

puts:
        push    ax
        mov     ah, 9
        int     21h
        pop     ax
        ret

putz:
        push    ax
        push    si
        mov     si, dx
.l:
        lodsb
        test    al, al
        jz      .e
        call    putchar
        jmp     .l
.e:
        pop     si
        pop     ax
        ret

putzx:
        push    ax
        push    si
        mov     es, [cs:datseg]
        mov     si, dx
.l:
        mov     al, [es:si]
        test    al, al
        jz      .e
        call    putchar
        inc     si
        jmp     .l
.e:
        pop     si
        pop     ax
        call    rds
        ret

crlf:
        mov     dx, nl
        jmp     puts

putchar:
        push    ax
        push    dx
        mov     dl, al
        mov     ah, 2
        int     21h
        pop     dx
        pop     ax
        ret

kv:
        call    puts
        call    puthexw
        jmp     crlf

kvd:
        call    puts
        xor     dx, dx
        call    putdecw
        jmp     crlf

kvl:
        mov     dx, bx
        call    puts
        mov     ax, [cs:r_ax]
        mov     dx, [cs:r_dx]
        call    putdecw
        jmp     crlf

puthexw:
        push    bx
        push    cx
        push    dx
        mov     bx, ax
        mov     cx, 0x0404
.l:
        mov     al, bh
        shr     al, cl
        shl     bx, cl
        add     al, 0x90
        daa
        adc     al, 0x40
        daa
        mov     dl, al
        mov     ah, 2
        int     21h
        dec     ch
        jnz     .l
        pop     dx
        pop     cx
        pop     bx
        ret

putdecw:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        xor     bx, bx
        mov     cx, 10
.a:
        mov     si, ax
        mov     ax, dx
        xor     dx, dx
        div     cx
        xchg    ax, si
        div     cx
        push    dx
        inc     bx
        mov     dx, si
        mov     si, ax
        or      si, dx
        jnz     .a
.b:
        pop     dx
        add     dl, '0'
        mov     ah, 2
        int     21h
        dec     bx
        jnz     .b
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

section .data

nl              db 13, 10, '$'
banner:
        db      'ALOADER: loads a .QLB, plays the part of'
        db      ' QuickBASIC'
        db      13, 10, '$'
m_file          db 'library file: ', '$'
m_loadbad:
        db      'cannot load: not a QLB, or a check failed.'
        db      13, 10, '$'
m_envbad:
        db      'the library failed the QB checks.'
        db      13, 10, '$'
m_envok:
        db      'checks passed: QB header, segments, '
        db      'b_ULVars.'
        db      13, 10, '$'
m_tab           db 'CODE table lookup of INT86OLD: ', '$'
m_tabno         db 'not in the CODE table', 13, 10, '$'
m_blk           db '  block segment   = ', '$'
m_par           db '  block paragraphs= ', '$'
m_w2            db '  w2 code paras   = ', '$'
m_w3            db '  w3 data end     = ', '$'
m_w4            db '  w4 symbol bytes = ', '$'
m_dseg          db '  data segment    = ', '$'
m_dval          db '  D (tail offset) = ', '$'
m_tail          db '  T (tail bytes)  = ', '$'
m_rel           db '  relocations     = ', '$'
m_phases:
        db      '-- phases QuickBASIC runs when it loads '
        db      'a library --', 13, 10, '$'
m_sel:
        db      '  dispatcher CX = '
        db      '$'
m_common        db ' (GETCOMMON): ', '$'
m_zero:
        db      'none (AX=BX=DX=0)'
        db      13, 10, '$'
m_nonzero:
        db      'COMMON area reported'
        db      13, 10, '$'
m_resolve:
        db      '-- GETPROC (0Ah) once for every name '
        db      'called --'
        db      13, 10, '$'
m_gp            db '  GETPROC ', '$'
m_arrow         db ' -> ', '$'
m_start         db '-- the program starts --', 13, 10, '$'
m_run:
        db      '-- the program calls the library --'
        db      13, 10, '$'
m_term          db '-- the program ends --', 13, 10, '$'
m_unload        db '-- the library is released --', 13, 10, '$'
m_freed         db 'block released with AH=49h.', 13, 10, '$'
m_bye           db 'done.', 13, 10, '$'
t_addone        db '  ADDONE(41) by reference, now ', '$'
t_sumi          db '  SUMI(1000, 234) returns AX = ', '$'
t_suml          db '  SUML(70000, 5) returns DX:AX = ', '$'
t_addbv         db '  ADDBV(7, 8) BYVAL returns AX = ', '$'
t_slen          db '  SLEN("hello") returns AX = ', '$'
t_upcase        db '  UPCASE("hello") gives ', '$'
t_fillb         db '  FILLB(seg, ofs, 6, 65) wrote ', '$'
t_copys         db '  COPYS(2.5) result bytes (hex) = ', '$'
t_copyd         db '  COPYD(2.5) result bytes (hex) = ', '$'
t_ptr           db ', AX = pointer ', '$'
t_symseg        db '  SYMSEG reads DS:00D3 = ', '$'
t_same:
        db      ' (the segment of the symbol block)'
        db      13, 10, '$'
t_diff:
        db      ' (differs from the symbol block '
        db      'segment)', 13, 10, '$'
t_noerr:
        db      '  RAISEERR(5) came back without a BASIC '
        db      'error', 13, 10, '$'
t_err:
        db      '  RAISEERR(5): BASIC error via gateway '
        db      '34, ERR = '
        db      '$'
t_seen:
        db      '  selectors seen by start (hex): '
        db      '$'

qlbname         db 'DEMO.QLB', 0
                times 56 db 0
s_hello         db 'hello', 0
n_null          db 'NULL', 0
n_bcsab         db 'BC_SAB', 0
n_stack         db 'STACK', 0
n_symbol        db 'SYMBOL', 0
n_vars          db 'B_ULVARS', 0
n_int86         db 'INT86OLD', 0

names           db 'ADDONE', 0
                db 'SUMI', 0
                db 'SUML', 0
                db 'ADDBV', 0
                db 'SLEN', 0
                db 'UPCASE', 0
                db 'FILLB', 0
                db 'COPYS', 0
                db 'COPYD', 0
                db 'RAISEERR', 0
                db 'SYMSEG', 0
                db 'GETCNT', 0
                db 'GETSEL', 0
                db 0

section .bss

qparas          resw 1
hdrblo          resw 1
hdrbhi          resw 1
w2              resw 1
w3              resw 1
w4              resw 1
cval            resw 1
dval            resw 1
tslo            resw 1
tshi            resw 1
sylo            resw 1
syhi            resw 1
tailn           resw 1
cntlo           resw 1
cnthi           resw 1
rseg            resw 1
roff            resw 1
rgend           resw 1
remain          resw 1
nchunk          resw 1
bcsab           resw 1
reg             resw 12
mzh             resb 28
qbh             resb 34
rbuf            resb 512
