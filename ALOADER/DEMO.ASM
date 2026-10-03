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
        global  ADDONE
        global  SUMI
        global  SUML
        global  ADDBV
        global  SLEN
        global  UPCASE
        global  FILLB
        global  COPYS
        global  COPYD
        global  RAISEERR
        global  SYMSEG
        global  GETCNT
        global  GETSEL

        segment .text

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

ADDONE:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        inc     word [bx]
        pop     bp
        retf    2

SUMI:
        push    bp
        mov     bp, sp
        mov     bx, [bp+8]
        mov     ax, [bx]
        mov     bx, [bp+6]
        add     ax, [bx]
        pop     bp
        retf    4

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

ADDBV:
        push    bp
        mov     bp, sp
        mov     ax, [bp+8]
        add     ax, [bp+6]
        pop     bp
        retf    4

SLEN:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        mov     ax, [bx]
        pop     bp
        retf    2

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

RAISEERR:
        push    bp
        mov     bp, sp
        mov     bx, [bp+6]
        push    di
        mov     di, 22h
        call    far [0C2h]
        pop     di
        pop     bp
        retf    2

SYMSEG:
        mov     ax, [0D3h]
        retf

GETCNT:
        push    ds
        mov     ax, seg trace
        mov     ds, ax
        mov     ax, [tcount]
        pop     ds
        retf

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

        segment .data

fname:  db      'TRACE.TXT', 0
trace:  times 16 dw 0
tcount: dw      0
