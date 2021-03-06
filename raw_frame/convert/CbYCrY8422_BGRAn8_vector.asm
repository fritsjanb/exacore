; Copyright 2011 Andrew H. Armenia.
; 
; This file is part of openreplay.
; 
; openreplay is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; 
; openreplay is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with openreplay.  If not, see <http://www.gnu.org/licenses/>.

bits 64

section text align=16
global CbYCrY8422_BGRAn8_vector:function

CbYCrY8422_BGRAn8_vector:
    ; argument summary...
    ; rdi = CbYCrY data size
    ; rsi = CbYCrY8422 surface
    ; rdx = destination BGRAn8 surface
    ; U = Cb, V = Cr
    
                                     ;        LSB ---------- MSB
    movdqa      xmm0, [rsi]          ; xmm0 = [uyvyuyvyuyvyuyvy]
    pxor        xmm7, xmm7

    ; data unpack
    pshuflw     xmm1, xmm0, 0xa0
    pshufhw     xmm1, xmm1, 0xa0
    pand        xmm1, [lsb_mask wrt rip]        ; xmm1 = [u u u u u u u u ]

    pshuflw     xmm2, xmm0, 0xf5
    pshufhw     xmm2, xmm2, 0xf5
    pand        xmm2, [lsb_mask wrt rip]        ; xmm2 = [v v v v v v v v ]

    psrlw       xmm0, 8                         ; xmm0 = [y y y y y y y y ]
    psubusw     xmm0, [Y_shift wrt rip]

    ; compute R and B components
    psllw       xmm1, 1
    psllw       xmm2, 1
    pmulhuw     xmm1, [Cb_B_mult wrt rip]
    pmulhuw     xmm2, [Cr_R_mult wrt rip]

    paddusw     xmm1, xmm0
    paddusw     xmm2, xmm0
    psubusw     xmm1, [B_offset wrt rip]
    psubusw     xmm2, [R_offset wrt rip]


    ; compute G component
    movdqa      xmm4, xmm1
    pmulhuw     xmm4, [BG_mult wrt rip]
    psubusw     xmm0, xmm4
    movdqa      xmm4, xmm2
    pmulhuw     xmm4, [RG_mult wrt rip]
    psubusw     xmm0, xmm4
    psllw       xmm0, 1
    pmulhuw     xmm0, [G_scale wrt rip]

    psllw       xmm0, 1
    psllw       xmm1, 1
    psllw       xmm2, 1

    pmulhuw     xmm0, [RGB_scale wrt rip]
    pmulhuw     xmm1, [RGB_scale wrt rip]
    pmulhuw     xmm2, [RGB_scale wrt rip]

    ; RGB saturation logic
    packuswb    xmm0, xmm7
    packuswb    xmm1, xmm7
    packuswb    xmm2, xmm7

    punpcklbw   xmm0, xmm7
    punpcklbw   xmm1, xmm7
    punpcklbw   xmm2, xmm7

    ; pack down xmm0/xmm1/xmm2 to something resembling RGBA
    movdqa      xmm3, xmm0
    punpcklwd   xmm0, xmm7              ; xmm0 = [g   g   g   g   ]
    punpckhwd   xmm3, xmm7              ; xmm3 = [g   g   g   g   ]
    pslld       xmm0, 8                 ; xmm0 = [ g   g   g   g  ]
    pslld       xmm3, 8                 ; xmm3 = [ g   g   g   g  ]

    movdqa      xmm4, xmm1              
    punpcklwd   xmm1, xmm7              ; xmm1 = [b   b   b   b   ]
    punpckhwd   xmm4, xmm7              ; xmm4 = [b   b   b   b   ]
    por         xmm0, xmm1
    por         xmm3, xmm4

    movdqa      xmm5, xmm2              
    punpcklwd   xmm2, xmm7              ; xmm2 = [r   r   r   r   ]
    punpckhwd   xmm5, xmm7              ; xmm5 = [r   r   r   r   ]
    pslld       xmm2, 16
    pslld       xmm5, 16
    por         xmm0, xmm2
    por         xmm3, xmm5
    
    por         xmm0, [alpha_fixed wrt rip]
    por         xmm3, [alpha_fixed wrt rip]

    movdqa      [rdx], xmm0
    movdqa      [rdx+16], xmm3
    
    ; book keeping
    add         rdx, 32
    add         rsi, 16
    sub         rdi, 16
    jg CbYCrY8422_BGRAn8_vector

    ret

align 16
lsb_mask        times 8 dw 0xff
Y_shift         times 8 dw 16
Cb_B_mult       times 8 dw 59447
Cr_R_mult       times 8 dw 50451
B_offset        times 8 dw 232
R_offset        times 8 dw 197
BG_mult         times 8 dw 4731
RG_mult         times 8 dw 13933
G_scale         times 8 dw 45817
alpha_fixed     times 4 dd 0xff000000
RGB_scale       times 8 dw 38154
; vim:syntax=nasm64
