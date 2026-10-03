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
