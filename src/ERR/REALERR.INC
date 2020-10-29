;	Project		VOS/9 
;  	File name	REALERR.INC	02.11.1995
;	File type	Include
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		02.11.1995
; 	Release		1		26.11.1995
;	
;  	Autor		Marcus Zoller
;  	
;	Description	Realmode Error Message Handling
;
;	Includes	..\BIOS\VIO.INC
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	Video BIOS
;	
;	Bugfix List ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Release Comments ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	
;	Function Ref ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;
;	ERR_HALT	: Anzeigen der Err-Screen und System anhalten!
;			  ax=Err-Code
;

	ERR_HALT PROC NEAR
		push	ax

		call	CLEAR		; Bildschrim l”schen (VIO.INC)

		xor	dx, dx
		call	SET_CURPOS
		mov	ah, 4fh		; weiá auf rot
		lea	si, kernel_panic
		call	print
			
		mov	dh, 4
		mov	dl, 0
		call	set_curpos
		mov	ah, 07h
		lea	si, panic_help
		call	print
		
		mov	dh, 11
		mov	dl, 3
		call	set_curpos
		mov	ah, 0Eh
		lea	si, panic_err
		call	print
		
		mov	dh, 13
		mov	dl, 3
		call	set_curpos
		mov	ah, 07h
		lea	si, panic_exp
		call	print
		
		mov	dh, 15
		mov	dl, 3
		call	set_curpos
		mov	ah, 07h
		lea	si, panic_ref
		call	print
				
		mov	dh, 17
		mov	dl, 3
		call	set_curpos
		mov	ah, 07h	
		lea	si, panic_locate
		call	print
		
		mov	dh, 19
		mov	dl, 3
		call	set_curpos
		mov	ah, 07h	
		lea	si, panic_howto
		call	print
		
		pop	ax
		xor	dx, dx
		mov	bx, 6
		mul	bx
		lea	di, panic_list
		add	di, ax
		mov	si, word ptr [di]

		push	di

		mov	dh, 13
		mov	dl, 19
		call	set_curpos
		mov	ah, 0fh
		call	print
		
		pop	di

		add	di, 2
		mov	si, word ptr [di]

		push	di

		mov	dh, 17
		mov	dl, 19
		call	set_curpos
		mov	ah, 0fh
		call	print
		
		pop	di

		add	di, 2
		mov	si, word ptr [di]

		mov	dh, 19
		mov	dl, 19
		call	set_curpos
		mov	ah, 0fh
		call	print
		
		mov	dh, 22
		mov	dl, 7
		call	set_curpos
		mov	ah, 0fh
		lea	si, panic_adios
		call	print
		
		jmp	short $			; Loop endless
	ERR_HALT ENDP
	