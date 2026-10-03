' (c) DosWorld 2026
'
' This is free and unencumbered software released into the
' public domain.
'
' Anyone is free to copy, modify, publish, use, compile, sell,
' or distribute this software, either in source code form or as
' a compiled binary, for any purpose, commercial or
' non-commercial, and by any means.
'
' In jurisdictions that recognize copyright laws, the author or
' authors of this software dedicate any and all copyright
' interest in the software to the public domain. We make this
' dedication for the benefit of the public at large and to the
' detriment of our heirs and successors. We intend this
' dedication to be an overt act of relinquishment in perpetuity
' of all present and future rights to this software under
' copyright law.
'
' THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
' KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
' WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
' PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE
' LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
' AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
' OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
' DEALINGS IN THE SOFTWARE.
'
' For more information, please refer to <https://unlicense.org>

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
