
helloworld	db "Driver to make 'shift PrtScr' key work",13,10
		db "even in CGA, EGA, VGA, MCGA graphics",13,10
		db "modes loaded, in "
%ifdef EPSON
		db                  "Epson"
%endif
%ifdef POSTSCRIPT
		db                  "PostScript"
%endif
%ifdef HPPCL
		db                  "HP PCL"
%endif
		db                            " mode.",13,10,"$"

helptext:	; help text is only 40 columns wide ;-)     *<- 40th!
%ifdef POSTSCRIPT
		db "Usage: GRAPHICS [/B] [/I] [/C] [/E] [/n]",13,10
%else
		db "Usage:",13,10
		db "GRAPHICS [/B] [/I] [/C] [/R] [/E] [/n]",13,10
%endif
		db " /B recognize non-black CGA color 0",13,10
		db " /I inverse printing (for dark images)",13,10
		db " /C compatibility mode"
%ifdef EPSON
		db                        " (120x72 dpi)",13,10
%endif
%ifdef POSTSCRIPT
		db                        " (HP Laserjet)"
%endif
%ifdef HPPCL
		db                        " (300 dpi)",13,10
%endif
%ifndef POSTSCRIPT
		db " /R use random dither, not ordered one"
%endif
		db 13,10
		db " /E economy mode (only 50% density)",13,10
		db " /n Use LPTn (value: 1..3, default 1)",13,10
		db " /? show this help text, do not load",13,10
		db 13,10
		db "After loading the driver you can print",13,10
		db "screenshots using 'shift PrintScreen'",13,10
		db "even in graphics modes. This GRAPHICS",13,10
		db "is for "
%ifdef EPSON
		db         "Epson 180x180 dpi"
%endif
%ifdef POSTSCRIPT
		db         "PostScript grayscale"
%endif
%ifdef HPPCL
		db         "HP PCL 600 dpi"
%endif
		db                             " printers.",13,10
		db "This is free software (GPL2 license).$",13,10
