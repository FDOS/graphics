; GRAPHICS tool for FreeDOS - GPL by Eric Auer eric@coli.uni-sb.de 2003
; Please go to www.gnu.org if you have no copy of the GPL license yet.

; use prtchar to print char AL. May or busyflag with 4 (abort) or
; 8 (error). User may and busyflag with not-1 (stop) to request
; clean abort of printing process (impossible with PS!?)...

; EPSON driver now with new command line option /R for "RANDOM"
; (otherwise, use "half-ordered" dither)...

; Google search for "matrix printer 180 graphics 24-pin" or similar
; to learn about the ESC codes for other printers. If you want to do
; "9 pin" printing, use 8 pin graphics modes (normally 72 dpi).

; For 24 pin printing, 180 dpi is common (horizontal resolution may
; be configurable from 90..360 dpi) If you need 360 dpi vertical
; resolution, you have to heavily modify this to do 2-pass printing
; By the way, 24 pin printers in 8 pin mode normally have 60 dpi.

	mov al,[cs:compatmode]
	test al,al
	jz epsonFullMode
epsonOldMode:		; 120x72 dpi (9 pin), or 8-of-24 pin 120x60 dpi
	mov word [cs:epsonXdpi], 120
	mov word [cs:epsonYdpi],  72
	mov word [cs:epsonXsz],  744	; smaller, as Y is smaller:
					; only 6.2 inch. 31*24
	mov word [cs:epsonYsz],  592	; smaller, for 60 dpi case
					; in 72 dpi: only 8.2 inch
	mov word [cs:epsonPins],   8	; not 9, of course

	; rest of changes is handled in-line
	
	mov si,epsonINITold
	call prtstr
	jmp short epsonInitDone

epsonFullMode:		; 180x180 dpi

	mov si,epsonINIT
	call prtstr			; set up printer
epsonInitDone:
	test byte [cs:busyflag],12	; any errors?
	jz initEPSONworked
	jmp abortEPSONprinter		; skip all rest, init failed

initEPSONworked:	; (1)
	xor cx,cx			; X (printer)
	xor dx,dx			; Y (printer)
	jmp short nextEPSONblock

nextEPSONline:		; (2)
	mov si,epsonCRLF		; advance paper
	call prtstr
	xor cx,cx			; X (printer)
	add dx,[cs:epsonPins]		; Y (printer)

nextEPSONblock:		; (3)
	test byte [cs:busyflag],1	; user wants to abort?
	jnz noEPSONabort
doEPSONabort:
	mov si,epsonAbort
	call prtstr			; confirm abort
	jmp leaveEPSONprinter
noEPSONabort:

	mov al,[cs:compatmode]
	or al,al
	jz epsonFullGFX
epsonOldGFX:
	mov si,epsonGFXold		; start graphics bitmap block
	call prtstr
	mov al,0			; second byte of columns!
	call prtchar			; (\0 not printed in prtstr)
	mov bx,[cs:epsonGCold]		; graphics columns / block
	jmp short epsonBothGFX
epsonFullGFX:
	mov si,epsonGFX			; start graphics bitmap block
	call prtstr
	mov al,0			; second byte of columns!
	call prtchar			; (\0 not printed in prtstr)
	mov bx,[cs:epsonGC]		; graphics columns / block

epsonBothGFX:
	mov si,[cs:epsonPins]		; graphics rows / block
					; BX SI only valid in (3)..(4)
	mov di,0x8000			; no pixels set, MSB on top

nextEPSONpixel:		; (4)		; CX/DX: printer X/Y
	push cx				; BX/SI: remaining cols/pins
	push dx

	; *** figure out screen CX DX based on printer CX DX ***

	xchg cx,dx	; landscape mode
	mov ax,[cs:epsonXsz]
	sub ax,dx
	mov dx,ax	; landscape mode

	; now coordinate origin is at upper right of paper,
	; where screen coordinate origin (upper left) will be.

	mov ax,dx		; screen Y, inv. printer X based
	mul word [cs:yres]	; scale up
	; (32 bit intermediate value DX AX)
	div word [cs:epsonXsz]	; scale down
	mov dx,ax		; resulting screen Y
	push dx
	mov ax,cx		; screen X, printer Y based
	mul word [cs:xres]	; scale up
	; (32 bit intermediate value DX AX)
	div word [cs:epsonYsz]	; scale down
	mov cx,ax		; resulting screen X
	pop dx

	; *** optional ->
	mov ax,255		; white border
	cmp cx,[cs:xres]
	jae gotEPSONpixel
	cmp dx,[cs:yres]
	jae gotEPSONpixel
	; <- optional ***

	; use xres, yres and call [getpixel] for screen reading.

	cmp cx,[cs:epsonLastX]		; gain speed, remember pixels
	jnz freshEPSONpixel
	cmp dx,[cs:epsonLastY]
	jnz freshEPSONpixel
	mov ax,[cs:epsonLastPix]	; fetch already known pixel
	jmp gotEPSONpixel
freshEPSONpixel:
	mov [cs:epsonLastX],cx
	mov [cs:epsonLastY],dx
	call [cs:getpixel]	; this call is dynamically selected!
	mov [cs:epsonLastPix],ax
gotEPSONpixel:
	; returns AX in 0..255 range, 255 being white

	pop dx
	pop cx

	inc dx				; count up rows
	dec si				; count down pins

	cmp byte [cs:random],1	; random or ordered dither?
	jz epsonRdither
epsonOdither:
	call ditherBWordered	; set CY with probability (AL/255)
	jc epsonWHITE
	jmp short epsonBLACK
epsonRdither:
	call ditherBWrandom
	jc epsonWHITE
	; jmp short epsonBLACK

epsonBLACK:
	mov ax,di
	or al,ah		; OR in that black pixel
	mov di,ax
epsonWHITE:

	test si,7			; done with byte?
	jnz stillInByte
	mov ax,di
	call prtchar			; SEND that byte
	mov di,0x8000			; flush bit bucket
	jmp short freshByte

stillInByte:
	mov ax,di
	shr ah,1			; go to next pixel
	mov di,ax

freshByte:
	test si,255			; pins left?
	jz nextEPSONcolumn
	jmp nextEPSONpixel	; (/4)	; still in pixel column

nextEPSONcolumn:
	sub dx,[cs:epsonPins]		; go back to upper pin
	mov si,[cs:epsonPins]		; COUNT pins AGAIN...

	;
	push bx
	mov bx,cx			; column
	and bx,7
	add [cs:ditherTemp],bl		; yet another try for weaving
; ---	add bx,bx
; ---	mov bl,[cs:weaveTab+bx]		; weaving table
; ---	mov [cs:ditherWeave],bl		; reduce artifacts by weaving
; ---	add [cs:ditherTemp],bl		; reduce artifacts by weaving
	; (most visible patterns are every 2/4/8 values of ditherTemp)
	pop bx
	;

	inc cx				; next pixel column
	dec bx				; count down columns
	jz doneEPSONblock
	jmp nextEPSONpixel	; (/4)	; still in bitmap block

doneEPSONblock:
	cmp cx,[cs:epsonXsz]		; done with row?
	jae doneEPSONline
	jmp nextEPSONblock	; (/3)	; otherwise, send next bitmap

doneEPSONline:
	mov al,7
	call tty			; beep each row
	;
	mov byte [cs:ditherTemp],0	; reset dithering pattern
	;
	cmp dx,[cs:epsonYsz]		; done with printing?
	jae leaveEPSONprinter
	jmp nextEPSONline	; (/2)	; otherwise, do next line
	
leaveEPSONprinter:		; (/1)
	mov si,epsonDONE		; send closing sequence
	call prtstr

abortEPSONprinter:
	jmp i5eof			; *** DONE ***

; ------------

; prtstr          - print 0 terminated string starting at CS:SI
; ditherBWordered - set CY with probability proportional to AL
;   (using "mirrored counter" as "randomness" source)
;   (to set seed, set ditherTemp, e.g. from weaveTab)
; ditherBWrandom  - set CY with probability proportional to AL
;   (using a linear congruential pseudo random number generator)
;   (to set seed, set ditherSeed, not really needed)

%include "dither.asm"	; random/ordered dithering, string output

; ------------

	; Epson escape sequences that we may want to use:
	; > ESC * mode lowcolumns highcolumns data -> graphics mode
	;              (mode 39 is for example 24pin 180x180dpi)
	;   ESC J n -> advance n/180 inch
	;   ESC A n -> line spacing n/60 inch
	; > ESC 3 n -> line spacing n/180 inch
	;   ESC + n -> line spacing n/360 inch
	; > ESC 0   -> 8 lines per inch
	;   ESC 2   -> 6 lines per inch

epsonXdpi	dw 180	; printer X resolution
epsonYdpi	dw 180	; printer Y resolution
epsonXsz	dw 1330	; width of printout in pixels, e.g. 7.43 inch
epsonYsz	dw 1776	; length of printout in pixels, e.g. 9.9 inch
epsonPins	dw 24	; use 24 or 8 pins? (word!)
			; (epsYsz/epsPins should be an integer)

epsonAbort	db 13,10,"(aborted)",13,10,0

epsonINITold	db 27,"A",8	; init sequence (8 pixels per line)
		db 13,10,0	; (60 or 72 Y dpi)
epsonINIT	db 27,"3",24	; init sequence (24 pixels per line)
		db 13,10,0	; (180 Y dpi)

epsonDONE	db 27,"0"	; closing sequence (8 lines per inch)
		db 12		; do form feed as well
		db 13,10,0
epsonCRLF	db 13,10,0	; how to adv. paper by epsPins pixels

epsonGFXold	db 27,"L"	; init sequence for graphics mode
epsonGCold	dw 31		; pixel columns of each epsGFX
epsonGFX	db 27,"*",39	; init sequence for graphics mode
epsonGC		dw 70		; pixel columns of each epsGFX
				; (epsXsz/epsGC should be an integer)

		; *** nextEPSONblock needs epsonGC < 256 !!! ***
		; (related to printing \0 bytes - I always add one!)
		db 0		; if you need this, epsonGC is wrong!
		; data: top, middle, low, top, middle, low, ... bytes
		; (3 bytes per column, top bit is 0x80...!)

		; for non-Epson printers, you may have to send for
		; example the data size in bytes rather than using
		; the epsonGC value directly. In that case, you still
		; need to have the epsonGC dw around, just move it
		; out of the scope of the epsonGFX string then.

epsonLastX	dw -1		; last seen pixel
epsonLastY	dw -1		; last seen pixel
epsonLastPix	dw 0		; last seen pixel


; ------------

	; If you would do pure ordered dither with integer print
	; size for each screen pixel, I recommend those values:

	; Print box is printer pixels per screen pixel if 180 dpi.
	; Aspect ratio on screen and x/y factor and print box:
	; 320x200: 1:1.25 1.60 4x5
	; 640x200: 1:2.50 3.20 2x5
	; 640x350: 1:1.39 1.83 2x3
	; 640x480: 1:1.00 1.33 2x2
	; Hercules would be 720x348: 1:1.56 2.07 2x3 (or 720x360 ...) 
	; Print box of 320x200 is reduced to fit aspect ratio better.
	; 2x3 print box is 1:1.50 but you cannot easily improve that.

	; Note that the CURRENT implementation allows "arbitrary"
	; zoom factors between screen size and used paper area.

