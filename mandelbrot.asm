        org     0x7c00
        bits    16

_start:
                cli
                mov     sp, 7C00h                       ; stack grows downwards from 0x7C00
                mov     bp, sp

                finit

                mov     ax, 13h                         ; set video mode 
                int     10h
                mov     ax, 0A000h                      ; address of video RAM
                mov     es, ax

generate_palette:
                xor     ax, ax                          ; store color index
        .ploop:
                mov     dx, 3c8h                        ; set VGA palette port
                out     dx, ax                          ; put color index

                inc     dx                              ; set color data port

                out     dx, ax                          ; set red
                out     dx, ax                          ; set green
                out     dx, ax                          ; set blue

                inc     ax                              ; next color
                cmp     ax, 64
                jnz     .ploop


main:
        %push ctx
        %stacksize small
        %assign %$localsize 0
        %local x:word, y:word
                enter   %$localsize, 0

                mov     cx, 63999                       ; pixel index, 320*200
                mov     bx, 320                         ; screen width
        .mainLoop:
                ; Calculate the point of the current pixel
                ; x = cx % 320, y = cx / 320
                mov     ax, cx   
                xor     dx, dx
                div     bx

                mov     [x], dx
                mov     [y], ax

                ; Calculate the current point on the complex plane
                fld     qword [ystep]                   ; st0 := ystep
                fimul   word  [y]                       ; st0 := ystep*y
                fadd    qword [y_start]                 ; st0 := ystep*y - y_start
                fstp    qword [my]

                fld     qword [xstep]                   ; st0 := xstep
                fimul   word  [x]                       ; st0 := xstep*x
                fadd    qword [x_start]                 ; st0 := xstep*x - x_start
                fstp    qword [mx]

                ; Check if the point diverges
                call    iteration                       ; eax := color index
                call    putpixel                        ; put correspoding color to (x, y)

                dec     cx                              ; next pixel
                jnz     .mainLoop
        %pop
halt:           hlt 


iteration:
        %push ctx
        %stacksize small
        %assign %$localsize 0
        %local zr:qword, zi:qword, tmp_r:qword, tmp_i:qword, tmp:word
                enter   %$localsize,  0

                mov     dword [zr],   0
                mov     dword [zi],   0
                mov     dword [zr+4], 0
                mov     dword [zi+4], 0

                ; Iterate function f(z) = z^2 + c as long that |z| > 4

                mov     dx, 99                          ; iteration counter
        .iterateloop:
                fld     qword [zr]                      ; st0 := Rm
                fmul    qword [zr]                      ; st0 := Rm^2

                fld     qword [zi]                      ; st0 := Im, st1 := Rm^2
                fmul    qword [zi]                      ; st0 := Im^2

                fsubp   st1, st0                        ; st0 := Rm^2 - Im^2

                fld     qword [zr]                      ; st0 := Rm, st1: Rm^2 - Im^2
                fmul    qword [zi]                      ; st0 := Rm*Im
                fmul    qword [two]                     ; st0 := 2*Rm*Im

                ; st0 := 2*Rm*Im
                ; st1 := Rm^2-Im^2

                fld     qword [my] 
                faddp   st1, st0                        ; st0: 2*Rm*Im + y
                fst     qword [zi]

                fld     qword [mx]
                faddp   st2, st0                        ; st1: Rm^2-Im^2 + x
                fxch                                    ; st0: new Rm, st1: new Im
                fst     qword [zr]

                fmul    st0, st0                        ; st0: new Rm^2
                fxch    st1
                fmul    st0, st0                        ; st0: new Im^2
                faddp   st1, st0                        ; st0: Rm^2 + Im^2

                fsqrt 

                fld     qword [two] 
                fcompp                                  ; cmp: sqrt(Rm^2 + Im^2), 2

                fstsw   ax                              ; Load status word to ax
                fwait
                sahf                                    ; Move al to CPU status flags

                jb      .break                          ; > 2.0

                dec     dx
                jnz     .iterateloop
                mov     dx, 100                         ; It took max iterations
        .break:
                ; Calculate the color value
                ; color = 64*sqrt(iteration count/100)

                mov     word[tmp], 100
                sub     word[tmp], dx                   ; tmp := iteration count

                fild    word[tmp]                       ; st0 := iteration count
                mov     word[tmp], 100
                fidiv   word[tmp]                       ; st0 := iteration count/100
                fsqrt                                   ; st0 := sqrt(iteration count/100)
                mov     word[tmp], 64
                fimul   word[tmp]                       ; st0 := 64 * sqrt(iteration count/100)
                fistp   word[tmp]

                mov     ax, word[tmp]

                leave
                ret
        %pop

putpixel:
                mov     di, cx                          ; pixel inded
                mov     dl, al                          ; color
                mov     [es:di], dl
                ret


x_start         dq      -2.5
y_start         dq      -1.5
xstep:          dq      0.0125 ;4/320
ystep           dq      0.0150 ;3/200
two             dq      2.0
mx              dq      0.0
my              dq       0.0

n32             dq       32.0


        times 510 - ($-$$) db 0
        dw        0xaa55                                ; bootloader magic