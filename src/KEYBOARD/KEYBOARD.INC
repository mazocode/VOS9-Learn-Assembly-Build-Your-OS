;	Project		VOS/9 
;  	File name	KEYBOARD.INC	23.02.1996
;	File type	Assembly
;	
;  	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		23.02.1996
; 	Release		0		23.02.1996
;	
;  	Autor		Marcus Zoller
;  	
;	Description	Kernel Standard Tastatur Funktionen
;
;	Includes	-
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Protected 32 Bit
;	
;	Functions Used	..\PORTS\PORTS.DEF
;	
;	Bugfix List 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;	
;	Release Comments 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;	
;	Function Ref 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; kbrd_cmd: 쉇ertr꼏t ein Command-Byte an Port 64h
	; -
	; Input : bl=command
	; Output: cf=Fehler
	;
	kbrd_cmd	proc near
		push	ecx
		push	eax
		mov	ecx, 0FFFFh
	 @@cmd_wait:
	 	in	al, CMD_8042
	 	jmp	short $+2
	 	jmp	short $+2
	 	test	al, 2		; Input Buffer voll?
	 	jz	@@send_cmd
	 	loop	@@cmd_wait
		jmp	@@cmd_error
	 @@send_cmd:
	 	mov	al, bl
	 	out	CMD_8042, al	; Send Command
	 	jmp	short $+2
	 	jmp	short $+2
	 	mov	ecx, 0FFFFh
	 @@cmd_accept:
	 	in	al, CMD_8042
	 	jmp	short $+2
	 	jmp	short $+2
	 	test	al, 2
	 	jz	@@send_ok
	 	loop	@@cmd_accept
	 @@cmd_error:
	 	pop	eax
	 	pop	ecx
	 	stc
	 	ret
	 @@send_ok:
	 	pop	eax
	 	pop	ecx
	 	clc
	 	ret	 
	kbrd_cmd	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; kbrd_write: Sendet byte an DATA_8042 Port
	; -
	; Input : bl=byte
	; Output: cf=Fehler
	;
	kbrd_write	proc near
		push	ecx
		push	eax
		mov	ecx, 0FFFFh
	  @@write_lp1:
	  	in	al, CMD_8042
	  	jmp	short $+2
	  	jmp	short $+2
	  	jz	@@write_ok
	  	loop	@@write_lp1
	  	pop	eax
	  	pop	ecx
	  	stc
	  	ret
	  @@write_ok:
	  	mov	al, bl
	  	out	DATA_8042, al
	  	jmp	short $+2
	  	jmp	short $+2
	  	pop	eax
	  	pop	ecx
	  	clc
	  	ret
	kbrd_write	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; kbrd_chk_read: Pr갽t ob im Keyboard-Buffer ein Zeichen zum lesen
	; vorhanden ist.
	; Input : -
	; Output: ZF=kein Zeichen vorhanden
	;
	kbrd_chk_read	proc near
		push	eax
		push	ecx
		mov	ecx, 0FFFFh
	 @@chk_lp1:
		in	al, CMD_8042
		jmp	short $+2
		jmp	short $+2
		test	al, 1	
		jnz	@@ready
		loop	@@chk_lp1
		stc
		pop	ecx
		pop	eax
		ret
	 @@ready:
	 	clc
	 	pop	ecx
		pop	eax
		ret
	kbrd_chk_read	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
 	; kbrd_read_scan: Lesen eines Byte aus dem Buffer des Keyboard
 	; Controllers =>Scancode.
 	; Input : -
 	; Output: AH=Scancode
 	; Error : CF=Kein Zeichen verf갾bar
 	;
 	kbrd_read_scan	proc near
 	 	call	kbrd_chk_read
 	 	jc	@@ExitRead
 	 	jmp	short $+2
 	 	jmp	short $+2
 	 	in	al, DATA_8042
 	 	jmp	short $+2
 	 	jmp	short $+2
 	 	mov	ah, al
 	 	xor	al, al
		clc
		ret
	  @@ExitRead:
		stc
	 	ret 	
	kbrd_read_scan	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
 	; kbrd_read: Liefert den ASC-II Code zu einem Scan-Code
 	; 
 	; Input : -
 	; Output: AL=ASC-II Zeichen, AH=Scancode
 	; Add   : DS=Kernel Datensegment-Selektor
 	; Subs  : kbrd_read_scan
 	;
	kbrd_read	proc near
		push	ebx
	  @@kbrd_wait:
	  	call	kbrd_read_scan
	  	jc	@@kbrd_wait
	  	push	edx
	  	push	eax
	  	mov	dl, ah
	  	call	dbg_8hex
	  	pop	eax
	  	pop	edx
		cmp	ah, 0E0h
		je	@@kbrd_wait
		cmp	ah, 0F0h		; Release Code unerw걆scht!
		je	@@kbrd_release
		cmp	ah, 58h			; Caps Lock
		je	@@Caps
		cmp	ah, 77h			; Num Lock
		je	@@Num
		cmp	ah, 7Eh			; Scroll Lock
		je	@@Scroll
		mov	al, 1h
		cmp	ah, 12h			; Left Shift
		je	@@ShiftTrue
		mov	al, 2h
		cmp	ah, 59h			; Right Shift
		je	@@ShiftTrue
		xor	ebx, ebx
		mov	bl, ah
		push	esi
		lea	esi, ds:scan_tab
		add	ebx, esi
		pop	esi
		test	byte ptr ds:[kbrd_state+2], 1h
		jnz 	@@ShiftOn
		test	byte ptr ds:[kbrd_state+2], 2h
		jnz	@@ShiftOn
		test	byte ptr ds:[kbrd_state+3], 4h
		jnz	@@ShiftOn
	  @@GetASC:
		mov	al, byte ptr ds:[ebx]
		pop	ebx
		ret
	  @@ShiftOn:
	  	add	ebx, 90h
	  	jmp	short @@GetASC
	  @@ShiftTrue:
	  	test	byte ptr ds:[kbrd_state+2], al
	  	jnz	@@kbrd_wait
	  	add	byte ptr ds:[kbrd_state+2], al
	  	jmp	@@kbrd_wait
	  @@kbrd_release:
	  	call	kbrd_read_scan
	  	push	edx
	  	push	eax
	  	mov	dl, ah
	  	call	dbg_8hex
	  	pop	eax
	  	pop	edx
	  	mov	al, 1h		; Linke Shift
	  	cmp	ah, 12h
	  	je	@@ShiftRel
	  	mov	al, 2h		; Rechte Shift
	  	cmp	ah, 59h
	  	je	@@ShiftRel
	  	jmp	@@kbrd_wait
	   @@ShiftRel:
		test	byte ptr ds:[kbrd_state+2], al
		jz	@@kbrd_wait
	   	sub	byte ptr ds:[kbrd_state+2], al
	   	jmp	@@kbrd_wait
	  @@Caps:
	  	mov	bl, 4h			; Bit 2
	  	jmp	short @@SetLEDs
	  @@Num:
	  	mov	bl, 2h			; Bit 1
	  	jmp	short @@SetLEDs
	  @@Scroll:
	  	mov	bl, 1h
	  @@SetLEDs:
		mov	al, byte ptr ds:[kbrd_state+3]
		test	al, bl
		jz	@@LedAn
	  	sub	al, bl
		jmp	short @@ProgLED	  	
	    @@LedAn:
		add	al, bl
	  @@ProgLED:  	
		mov	byte ptr ds:[kbrd_state+3], al
		push	eax
		
		; Zun꼊hst warten bis der Release-Code kommt!
	    @@LoopRel:
;	  	call	kbrd_read_scan
;	  	jc	@@LoopRel
;		cmp	ah, 0F0h		; Release Code?
;		jne	@@LoopRel
		; RelCode angekommen - nun sonstiges Zeug aus dem
		; Buffer entfernen!
	    @@FlushBuf:
	  	call	kbrd_read_scan
	  	jnc	@@FlushBuf
		; LED Write Command
		mov	al, 0EDh
		mov	dx, 60h
		out	dx, al
		jmp	short $+2
		jmp	short $+2
		; Noch ein Zeichen da?
	    @@FlushNoch:
	    	call	kbrd_read_scan
	    	jnc	@@FlushNoch
		pop	eax
		mov	dx, 60h
		out 	dx, al
		jmp	short $+2
		jmp	short $+2
		; Noch ein Zeichen da?
	    @@FlushWeiter:
	    	call	kbrd_read_scan
	    	jnc	@@FlushWeiter
		jmp	@@kbrd_wait
	kbrd_read	endp

	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
 	; kbrd_flush: Entleert den Keyboard-Buffer!
	;
	kbrd_flush	proc near
	  @@flush:
	 	call	kbrd_read_scan
	 	jnc	@@flush
	 	ret			
	kbrd_flush	endp
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
 	; init_kbrd: Setzt Command-Byte, Typematic,...
 	; 
 	; Input : -
 	; Output: -
 	; Add   : DS=Kernel Datensegment-Selektor
 	; Subs  : kbrd_cmd, kbrd_write
 	;
	init_kbrd	proc near
		mov	al, 0EDh
		out	DATA_8042, al
		jmp	short $+2
		jmp	short $+2
		xor	edx, edx
	  	mov	dword ptr ds:[kbrd_state], edx
		xor	al, al			; Alle LEDs aus!
		out	DATA_8042, al
		jmp	short $+2
		jmp	short $+2
		mov	bl, 60h
		call	kbrd_cmd
		jc	@@init_fail
		mov	bl, 24h			; 25h=inkl. IRQ1
		call	kbrd_write
		jc	@@init_fail
		ret
	  @@init_fail:
	  	ret
	init_kbrd	endp
	