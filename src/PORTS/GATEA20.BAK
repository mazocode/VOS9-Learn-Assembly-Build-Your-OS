	; Output Wert in AH
	; ôffnet/Schlie·t das Tor zum korrekten RAM Universum...
	
	gate_a20 proc near
		cli						
		call 	is_8042_empty				
		jnz	short @@gate_a20_bye			
		mov	al, 0d1h			; "Write Output Port"
		out	cmd_8042, al											
		call	test_ps2			; N PS/2 Compu ?
		jc	short @@no_mask				
		and	ah, 4fh				; Ist PS/2
	  @@NO_Mask:						
	  	call	is_8042_empty				
	  	jnz	short @@gate_a20_bye			
	  	mov	al, ah					
		out	data_8042, al				
		call	is_8042_empty				
	  @@GATE_A20_BYE:					
	  	ret						
	gate_a20 endp						

	; Der gute 8042 is fÅr die CPU n bisserl langsam un so mÅssen wir
	; warten bis er ausgekaut hat...
	
	is_8042_empty proc near	
		push	cx
		xor	cx, cx					
	  EMPTY_LOOP:						
	  	in	al, cmd_8042			; Schluck, Mampf...
	  	and	al, 02h					
	  	loopnz	empty_loop				
		pop	cx
	  	ret						
	is_8042_empty endp					

	test_ps2 proc near				; PS/2 verschnitt?
		push	ax					
		push	bx					
		push	es					
		mov	ah, 0c0h				
		int	15h				; System Info
		jc	short @@ps2_bye			; Nix is
		cmp	byte ptr es:[bx+2],0f8h 	; Model 70/80 ?
		stc					; Carry wenn nicht
		jnz	short @@ps2_bye				
		clc						
	  @@ps2_bye:						
	  	pop	es					
	  	pop	bx					
		pop	ax					
		ret						
	test_ps2 endp						
