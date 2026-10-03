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
