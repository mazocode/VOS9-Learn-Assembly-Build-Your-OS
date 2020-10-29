;	Project		VOS/9 
;  	File name	STRG.INC		21.11.1995
;	File type	Include
;	
; 	(c)(r) 1995 by MZ Computer Systems
;  
; 	Version		Gamma		21.11.1995
; 	Release		0		21.11.1995
;	
; 	Autor		Marcus Zoller
;  	
;	Description	String Funktionen
;	
;	Includes	-
;	Link Objects	-
;	
;	CPU Type	x86
;	CPU Mode	Real/V86
;	
;	Functions Used	-
;	
;	Bugfix List 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;	
;	Release Comments 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;	
;	Function Ref 컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;
;	COMPARE		: Vergleicht zwei Null-Terminierte Strings
;			  CF = 1 wenn gleich, String = cs:si, cs:di
;	GET_SIZE	: Liefert die gr붳e eines Strings ds:si in cx zur갷k
;
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; COMPARE: Vergleicht zwei Strings
	; Input : cs:si = String A, cs:di = String B
	; Output: CF=1 wenn gleich
	;
	COMPARE PROC NEAR
		push	ax si di
	@@TestGleich:
		mov	al, byte ptr cs:[si]
		cmp	byte ptr cs:[di], al
		jne	@@NixGleich
		inc	si
		inc	di
		cmp	al, '$'
		jne	@@TestGleich
		pop	di si ax
		stc				; Gleich!
		ret
	@@NixGleich:
		pop	di si ax
		clc				; Nicht gleich!
		ret
	COMPARE ENDP
	
	;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
	; GET_SIZE: Liefert die Gr붳e eines Strings in Bytes zur갷k
	; Input : ds:si = String
	; Output: cx = Anzahl Bytes
	;
	GET_SIZE PROC NEAR
		push	ax si
		xor	cx, cx
	@@checkloop:
		mov	al, byte ptr ds:[si]
		cmp	al, '$'
		je	@@SizeOK
		cmp	cx, 0FFh
		je	@@Fault
		inc	cx
		inc	si
		jmp	short @@checkloop
	@@SizeOK:
		pop	si ax
		ret
	@@Fault:
		pop	si ax
		xor	cx, cx		; String ist endlos (keine Term!)
		ret
	GET_SIZE ENDP
	