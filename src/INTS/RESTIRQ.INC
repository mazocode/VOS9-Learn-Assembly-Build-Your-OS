;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; VOS9 - The Virtual Operating System
; (c)(r) 1995 by MZ Computer Systems
;
; 	File		RESTIRQ.ASM
; 	Version 	Alpha 1
; 	Release		1
; 	Funktion	Umprogrammieren des IRQ-Contr. auf DOSenchaos
; 	Erstellt	09.08.1995
; 	Update		09.08.1995
; 	Autor		Marcus Zoller
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

		; PIC 8259-1
		mov	al, 00010001b	; AT Mode, Cascade, Init Bytes follow
		out	ISR_8259_A, al	; Send Init Command
		jmp	short $+2
		jmp	short $+2
		mov	al, 8h		; Benutze Vektoren 8-F
		out	MSK_8259_A, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 4		; Slave ist an IRQ2
		out	MSK_8259_A, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 1		; normal EOI, nonbuffered, 80x86 mode
		out	MSK_8259_A, al
		jmp	short $+2
		jmp	short $+2
		xor	al, al		; IRQ 0-8 erlaubt
		out	MSK_8259_A, al			
		jmp	short $+2
		jmp	short $+2

		; PIC 8259-2
		mov	al, 00010001b	; Init, Edge Mode, Cascade Mode
		out	ISR_8259_B, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 70h		; Use Vectors 70h-77h
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 00000010	; Slave an IRQ 2
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 1		; 80x86 Mode, normal EOI
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		xor	al, al		; Ints 8-F erlaubt
		out	MSK_8259_B, al	
		jmp	short $+2
		jmp	short $+2
		
