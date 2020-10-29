;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; VOS9 - The Virtual Operating System
; (c)(r) 1995 by MZ Computer Systems
;
; 	File		SETIRQ.ASM
; 	Version 	Alpha 1
; 	Release		1
; 	Funktion	Umprogrammieren des IRQ-Contr. auf VOS9
; 	Erstellt	09.08.1995
; 	Update		26.09.1995
; 	Autor		Marcus Zoller
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
;
; Bevor wir nun irgendwelche Ints zulassen, m걌sen wir IBMs
; Int-Chaos beseitigen. Intel m봠hte die Ints 0-1F reserviert
; haben... Wir programmieren nun den PIC 8259A um, was 
; recht nervt봳end ist (Das Ding ist langsam!!)...
;
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
        
		; PIC 8259-1
		mov	al, 00010001b	; AT Mode, Cascade, Init Bytes follow
		out	ISR_8259_A, al		; Send Init Command
		jmp	short $+2
		jmp	short $+2
		mov	al, 20h		; Benutze Vektoren 20h-27h
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
		mov	al, 28h		; Use Vectors 28h-2Fh
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 00000010	; Slave an IRQ 2
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		mov	al, 1		; 80x86 Mode, normal EOI, nonbuffered
		out	MSK_8259_B, al
		jmp	short $+2
		jmp	short $+2
		xor	al, al		; Ints 8-F erlaubt
		out	MSK_8259_B, al	
		jmp	short $+2
		jmp	short $+2
