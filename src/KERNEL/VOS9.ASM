;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; VOS9 - The Virtual Operating System
; (c)(r) 1995 by MZ Computer Systems
;
; 	File		VOS9.ASM
; 	Version 	Alpha 1
; 	Release		1
; 	Funktion	System Kernel
; 	Erstellt	13.07.1995
; 	Update		26.09.1995
; 	Autor		Marcus Zoller
;
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; 23-24.09.95: Wir haben den Boot-Record hier gleich EINgebaut! 
; 28.11.1995 : Wir haben den Boot-Record hier gleich AUSgebaut! 
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
.486P
.SEQ		;!!!
LOCALS
		include		..\ports\ports.def
		include		..\ports\vga.def
		include		..\def\system.def		
		include		..\def\loads.def
								
		ifdef	DEBUG
			DEBUG_PORT = SERIAL_2
		endif
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;		S E T U P - K E R N E L   I N I T
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	org 	0h
	
SETUP SEGMENT PARA USE16 'CODE'
	ASSUME CS:SETUP, DS:SETUP
	ORG    0h
		 
STARTUP_IP:
		cli
		mov	ax, KERNEL_START_ADDR
		shr	ax, 4
		mov	ds, ax
		mov	fs, ax
		mov	gs, ax
		mov	ss, ax
		mov	sp, offset stack_start
		sti

		; Die Endadresse des Kernel steht in es:bx
		xor	ecx, ecx
		mov	cx, es
		shl	ecx, 4
		add	ecx, ebx
		sub	ecx, KERNEL_START_ADDR
		mov	dword ptr [kernel_load_size], ecx
		mov	es, ax
						
		; Vor dem Wechsel in den Protmode ist folgendes zu Erledigen:
		; 1. Einrichten einer Minimal GDT zum Starten
		; 2. Einrichten der IDT

		; Wir Bestimmen nun alle Segmente fr den wechsel in den 
		; Protected Mode.
		; 1. Gesamter 4GB RAM-Bereich 
		; 2. Primary Video Segment
		; 3. Kernel Code Segment (32 Bit)
		; 4. Kernel Daten Segment (32 Bit)

	; VIDEO 
		mov	ah, 0fh			; Get Current Video State
		int	10h
		xor	edx, edx
		; AL = Video Mode, AH=Nr. of columns, BH=Active Page
		shl	al, 1
		shr	al, 1	
		mov	byte ptr [display_mode], al
		cmp	al, 7
		jne	IsColor
		mov	edx, 0B000h
		jmp	SetVideo	
	     IsColor:
		mov	edx, 0B800h
	     SetVideo:
		shl	edx, 4		

	; 4GB
		xor	eax, eax		

	; KERNEL_CODE
		mov	ebx, KERNEL_START_ADDR
		add	bx, offset KERNEL_STARTUP

	; KERNEL_DATA
		mov	ecx, KERNEL_START_ADDR

	; Das ganze in die PRE-GDT Eintragen!
		mov	word ptr [ram_des+2], ax
	        mov     word ptr [kernel_cs+2], bx
          	mov     word ptr [kernel_ds+2], cx
		mov	word ptr [vram_ds+2], dx
						
          	shr     eax, 16
		shr	ebx, 16          	
		shr	ecx, 16
		shr	edx, 16
		
	        mov     byte ptr [ram_des+4], al
          	mov     byte ptr [kernel_cs+4], bl
          	mov     byte ptr [kernel_ds+4], cl
          	mov	byte ptr [vram_ds+4], dl

	; Nun brauchen wir ein Tempor„res TSS - Grund:
	; Bei dem n„chsten TaskSwitch wrde die CPU versuchen
	; im aktuellen TSS die Daten zu sichern. Es existiert jedoch
	; keins (Nein wirklich)... Folge w„re eine Exception (OCHJOH)
	
	; TSS-Deskriptoren setzen...

		mov	eax, KERNEL_START_ADDR
		add	ax, offset tmp_tss
		
		mov	word ptr [tmp_tss_des+2], ax
		shr	eax, 16
		mov	byte ptr [tmp_tss_des+4], al

	; Nun brauchen wir noch Zeiger auf das Tabellen gesocks...
	; GDT/IDT Pointer berechnen
		
		mov	eax, KERNEL_START_ADDR
		mov	ebx, eax
		add	ax, offset GDT			; => Basis GDT
		add	bx, offset IDT			; => Basis IDT
		
		mov     dword ptr [GDT_ptr+2], eax
		mov     dword ptr [IDT_ptr+2], ebx	
          	mov     word ptr [GDT_ptr], GDT_SIZE
          	mov     word ptr [IDT_ptr], IDT_SIZE

	;Ne neue IDT... Wie wnschen:
	
		mov	edi, offset IDT
		mov	cx, 100h		; 100h Int Eintr„ge WOW!

	; Erst mal alle Ints als unbenutzt deklarieren...
			
	@@idt_loop:
		mov	dword ptr [edi], offset uu_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov	word ptr [edi+4], 08e00h
		add	edi, 8
		loop	@@idt_loop

	; Nun werden wir mal alle "B™SEN" Ints schnappen...
		
		mov	edi, offset IDT
		add	edi, 30h
		mov	dword ptr [edi], offset op_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov 	word ptr [edi+4], 08e00h
		add	edi, 10h
		mov	dword ptr [edi], offset df_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov	word ptr [edi+4], 08e00h
		add	edi, 10h
		mov	dword ptr [edi], offset tss_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov	word ptr [edi+4], 08e00h
		add	edi, 10h
		mov	dword ptr [edi], offset s_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov	word ptr [edi+4], 08e00h
		add	edi, 8
		mov	dword ptr [edi], offset gp_int
		mov	word ptr [edi+2], KERNEL_CS_SEL
		mov	word ptr [edi+4], 08e00h

		; Mal noch die Crash-Adressen setzen...
		mov	eax, offset init_crash
		mov	dword ptr [tss_crash], eax
		mov	dword ptr [stack_crash], eax		
		mov	dword ptr [df_crash], eax
		mov	dword ptr [op_crash], eax
		mov	dword ptr [shutdown_addr], eax

	; Nun mal Protmode action..

		; Absolute Ruhe bitte - Keine Ints und keine NMIs!
		cli		
		mov	dx, NMI_CONTROL
		mov	al, 80h			; NMI control shutup
		out	dx, al

		; Zun„chst ein mal mssen wir IBMs Interrupt-Chaos nach Intel
		; konventionen zurechtbiegen...

		include	..\ints\setirq.inc	
			
		cli		
		mov	dx, NMI_CONTROL
		mov	al, 80h			; NMI control shutup
		out	dx, al

		lgdt	fword ptr gdt_ptr	; GDT Laden
		lidt	fword ptr idt_ptr	; IDT Laden

		mov	cx, NULL_SEL
		mov	bx, TMP_TSS_SEL
							
		mov	eax, cr0
		or	eax, 1
		mov	cr0, eax		; Click!
		
		; Pentium kann die Prefetch Queue nicht L”schen!
		; => Schnellstm”glich ein JMP um Seg-Reg Caches zu flushen
		
		jmp	short $+2		; Flush! Platsch! Clibber!
		jmp	short $+2
		
		; Damit bei dem JMP der aktuelle Zustand gesichert werden
		; kann wird ein TMP TSS gesezt (nur fr Intel 80386 Mask B)!
		
		ltr	bx			; TemTask setzen
		lldt	cx			; LDT "ungltig" laden

		; Die CPU erlauben nach dem JUMP in den Protmode
		; wieder Ints => Weiterhin Ruhe bitte!
		
		cli				
		mov	dx, NMI_CONTROL
		mov	al, 80h
		out	dx, al			; NMIs auch Ruhe...

		; Nun alle Segmentregister mit Selektoren neu laden...
		; Dabei werden die Descriptor-Caches ebenfalls gefllt!

		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	es, ax
		mov	fs, ax
		mov	gs, ax			
		mov	ss, ax
		mov	esp, offset tos32b

		; Nun zeig was du kannst bayb...

		jmp	fword ptr [INIT_STARTUP_ADDR]

		INIT_STARTUP_ADDR:
		    dd  0
		    dw  kernel_cs_sel		  


	; Gr”áe des Kernel in Byte
	kernel_load_size	dd	0
	
	;
	; Descriptor Info: Bit 4 in Byte 6 = Fixed Segment -Mnemonik: (F)ixed
	;
	GDT		dq	0		; Null Eintrag
	ram_des		dw      0FFFFh        	; 4GB Daten Segment
        	  	dw      0		; Ab 0:0
        	  	db      0
        	  	db      92h		; P=1, DPL=0, E=0, W=1, A=0
         	  	db      9Fh		; G=1, B=0, F=1
        	  	db      00h
     	kernel_cs	dw      0FFFFh        	; 32Bit Code Segment
        	  	dw      ?
        	  	db      ?
          	  	db      9Ah		; P=1, DPL=0, C=0, W=1, A=0
          	  	db	0dFh		; G=1, D=1, F=1
        	  	db      00h
     	kernel_ds	dw      0FFFFh        	; Daten Segment
        	  	dw      ?
        	  	db      ?
        	  	db      92h		; P=1, DPL=0, E=0, W=1, A=0
         	  	db      9Fh		; G=1, B=0, F=1
        	  	db      00h
	vram_ds		dw	0FFFFh		; Video Text-Segment
			dw	?		; (wir im EA Bereich
			db	?		; eingeblendet)
			db	92h		; P=1, DPL=0, E=0, W=1, A=0
			db	10h		; G=0, B=0, F=1
	        	db	00h  	
	tmp_tss_des	dw	FULL_TSS_SIZE
			dw	?
			db	?
			db	10001001b	; P=1, DPL=0, BUSY=0
			db	00000000b	; G=0
			db	0
	GDT_ptr		df	?

	tmp_tss		dw	NULL_SEL
			dw	0
			dw	offset stack_start	; Level 0 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dw	offset stack_start	; Level 1 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dw	offset stack_start	; Level 2 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dd	0			; CR3
			dd	offset init_crash	; EIP
			dd	02h			; EFLAGS
			dd	0			; EAX
			dd	0			; ECX
			dd	0			; EDX
			dd	0			; EBX
			dw	offset tos32b		; ESP
			dw	0
			dd	0			; EBP
			dd	0			; ESI
			dd	0			; EDI
			dw	KERNEL_DS_SEL		; ES
			dw	0
			dw	KERNEL_CS_SEL		; CS
			dw	0
			dw	KERNEL_DS_SEL		; SS
			dw	0
			dw	KERNEL_DS_SEL		; DS
			dw	0
			dw	KERNEL_DS_SEL		; FS
			dw	0
			dw	KERNEL_DS_SEL		; GS
			dw	0
			dw	NULL_SEL		; LDT
			dw	0			; Trap
			dw	104			; Offs. IO-BITMAP
			db	IO_BITMAP_SIZE dup (0)  ; rel. z. TSS begin 
			db	0ffh	   

	IDLE_TSS	dw	NULL_SEL
			dw	0
			dw	offset IDLE_stack	; Level 0 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dw	offset IDLE_stack	; Level 1 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dw	offset IDLE_stack	; Level 2 Stack
			dw	0
			dw	KERNEL_DS_SEL
			dw	0
			dd	0			; CR3
			dd	offset init_crash	; EIP
			dd	02h			; EFLAGS
			dd	0			; EAX
			dd	0			; ECX
			dd	0			; EDX
			dd	0			; EBX
			dw	offset IDLE_TOS		; ESP
			dw	0
			dd	0			; EBP
			dd	0			; ESI
			dd	0			; EDI
			dw	VRAM_SEL		; ES
			dw	0
			dw	KERNEL_CS_SEL		; CS
			dw	0
			dw	KERNEL_DS_SEL		; SS
			dw	0
			dw	KERNEL_DS_SEL		; DS
			dw	0
			dw	KERNEL_DS_SEL		; FS
			dw	0
			dw	KERNEL_DS_SEL		; GS
			dw	0
			dw	NULL_SEL		; LDT
			dw	0			; Trap
			dw	104			; Offs. IO-BITMAP
			db	IO_BITMAP_SIZE dup (0)  ; rel. z. TSS begin 
			db	0ffh	   

	IDLE_STACK	db	256 dup (?)
	IDLE_TOS	label 	byte
	
		
	IDT		dq	100h dup (0)
	IDT_ptr		df	?	

	stack_init	db	256 dup (?)
	stack_start	label 	byte
	stack32b	db	256 dup (?)
	tos32b label word
	

ifdef DEBUG	
	equipment_msg0	db	'RAM               : 0x$'
	equipment_msg1  db	' KB$'
endif
	equipment_msg2	db	'(no CPUID)  '
ifdef DEBUG
	equipment_msg3  db 	'CPU: $'
	equipment_msg4	db	' FMS: 0x$'
	equipment_msg5	db	' OPT_A: 0x$'
	equipment_msg6	db	' OPT_B: 0x$'
	equipment_msg7	db	'IO-DELAY: 0x$'
	equipment_msg9	db	', $'
	
	dbg_msg0	db	'GP-FAULT          :   '
	dbg_msg1	db	'OP-FAULT          :   '
	dbg_msg2	db	'TSS-FAULT         :  '
	dbg_msg3	db	'STACK-FAULT       :'
	dbg_msg4	db	'DBL-FAULT         :  '
	dbg_msg5	db	'INT xx            :     '
	dbg_msg6	db	'Checking System-Configuration...$'
	
	dbg_info2	db	'VOS/9 Version 1.0 Release 0 - KERNEL DEBUG INFORMATION - 38400,8O1$'
	dbg_info3	db	'(c)(r) 1995 by MZ Computer Systems$' 
	dbg_info_4	db	'CR0               : 0x$'
	dbg_info_6	db	'CR3               : 0x$'
	dbg_info_7	db	'total_ram_bytes   : 0x$'
	dbg_info_8	db	'total_ram_pages   : 0x$'
	dbg_info_16	db	'page_tabel_pages  : 0x$'
	dbg_info_9	db	'pgdir_address     : 0x$'
	dbg_info_10	db	'memmap_address    : 0x$'
	dbg_info_11	db	'Kernel Size       : 0x$'
	dbg_info_12	db	'Kernel Pages      : 0x$'
	dbg_info_13	db	'Error marking page!$'
			
	dbg_list	dw	dbg_msg0, dbg_msg1, dbg_msg2, dbg_msg3
			dw	dbg_msg4, dbg_msg5

endif

	include		..\msgs\german\panic.msg	; Kernel Panic Messages
	include		..\msgs\german\welcome.msg	; Kernel Welcome Screen

  	GP_CRASH  	dd 	offset init_crash
  			dw	kernel_cs_sel
	last_gp_fault	df	0
  	TSS_CRASH  	dd 	offset init_crash
  			dw	kernel_cs_sel
  	STACK_CRASH  	dd 	offset init_crash
  			dw	kernel_cs_sel
  	DF_CRASH  	dd 	offset init_crash
  			dw	kernel_cs_sel
  	OP_CRASH  	dd 	offset init_crash
  			dw	kernel_cs_sel
	SHUTDOWN_ADDR   dd  	offset init_crash
			dw	kernel_cs_sel		  

	;====================================================================
	; Hier sammeln wir alle Daten, welche wir im Laufe von Init finden
	; werden...
	
	cpu_str		db	12 dup (20h), '$'	

	; Bit	Beschreibung (Liefert CPUID Level 0)
	; 96..1 CPU Hersteller
	; 0	Terminator
	
	fms		dd	?			

	; Bit 	Beschreibung (Liefert CPUID Level 1)
	; 31-12 reserviert
	; 11-8  Family (4=486, 5=586, ...)	
	; 7-4	Model (1=DX, 2=SX, 8=DX4)
	; 3-0	Stepping (1=A-Maske, 2=B-Maske, ...)

	optA		dd	?			

	; Bit	Beschreibung (Liefert CPUID Level 1)
	; 31-9	reserviert
	; 8	CMPXCHG8B implementiert
	; 7	Machine Check Exception untersttzt
	; 6	reserviert
	; 5	Pentium komp. MSR vorhanden
	; 4	Time Stamp Counter vorhanden
	; 3	4MB Seitengr”áe m”glich
	; 2	I/O Breakpoints m”glich
	; 1	V86-Mode Erweiterungen vorhanden
	; 0	Coprozessor integriert ('DX')

	optB		dd	?			

	; Bit	Beschreibung (Getestet/CPUID Level 0)
	; 31..7 reserviert
	; 6	RDMSR mit ECX=1000h m”glich (bisher nur IBM CPUs)
	; 5	RDMSR implementiert
	; 4	UMOV implementiert		
	; 3..0	max. CPUID Level (0=kein CPUID)

	io_delay	dd	?

	; Bit 	Beschreibung (Getestet)
	; 15..0 Wartezeit zwischen IO Zugriffen

	display_mode	db	?

	; Der mit der Bios-Funk. ermittelte VideoModus (BootUpMode)
	
	dsp_cursor_x	db	?
	dsp_cursor_y	db	?
	
	; Cursorposition fr die interne Kernel Shell

	inf_cpu		db	'CPU VENDOR STRING: $'
	inf_fms		db	'CPU F,M,S        : 0x$'
	inf_opta	db	'CPU OPTIONS A    : 0x$'
	inf_optb	db	'CPU OPTIONS B    : 0x$'
	inf_speed	db	'IO SPEED-MARK    : 0x$'
	inf_mem		db	'TOTAL_RAM (BYTE) : 0x$'
	
	; Infos bei Shell-Start
			
	; Verfgbarer RAM...
	total_ram_bytes		dd	0	; gr”áe des RAMs in Bytes

	total_ram_pages		dd	0	; gr”áe des RAMs in Pages

	pagetable_pages		dd	0	; durch Page-Tabellen belegte
						; Seiten		
	memmap_addr		dd	0	; Memmap Adresse
	;====================================================================

	TICK_TACK	dd	0

	;====================================================================
	; Scan/ASC Tabel - Der Lowlevel Keyboard-Handler durchsucht diese
	; Tabelle nach einem passenden ASC-II zu einem Scancode. 
	; Aufbau: POS=SCAN->ASC-II=1 Byte; Scancodes 1h-58h
	;

	; NO-SHIFT
	;	     0 	 1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
SCAN_TAB	db   00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,09h,60h,00h ; 0  
		db   00h,00h,00h,00h,00h,71h,31h,00h,00h,00h,7Ah,73h,61h,77h,32h,00h ; 1				
		db   00h,63h,78h,64h,65h,34h,33h,00h,00h,20h,76h,66h,74h,72h,35h,00h ; 2
		db   00h,6Eh,62h,68h,67h,79h,36h,00h,00h,00h,6Dh,6Ah,75h,37h,38h,00h ; 3
		db   00h,2Ch,6Bh,69h,6Fh,30h,39h,00h,00h,2Eh,2Fh,6Ch,3Bh,70h,2Dh,00h ; 4
		db   00h,00h,27h,00h,5Bh,3Dh,00h,00h,00h,00h,0Dh,5Dh,00h,5Ch,00h,00h ; 5
		db   00h,00h,00h,00h,00h,00h,08h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; 6
		db   00h,00h,00h,00h,00h,00h,1Bh,00h,00h,2Bh,00h,2Dh,2Ah,00h,00h,00h ; 7
		db   00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; 8
	; SHIFTED (+90h)
	;	     0 	 1   2   3   4   5   6   7   8   9   A   B   C   D   E   F		
		db   00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,7Eh,00h ; 0  
		db   00h,00h,00h,00h,00h,51h,21h,00h,00h,00h,5Ah,53h,41h,57h,40h,00h ; 1  
		db   00h,43h,58h,44h,45h,24h,23h,00h,00h,20h,56h,46h,54h,52h,25h,00h ; 2  
		db   00h,4Eh,42h,48h,47h,59h,5Eh,00h,00h,00h,4Dh,4Ah,55h,26h,2Ah,00h ; 3  
		db   00h,3Ch,4Bh,49h,4Fh,29h,28h,00h,00h,2Eh,3Fh,4Ch,3Ah,50h,5Fh,00h ; 4  
		db   00h,00h,22h,00h,7Bh,2Bh,00h,00h,00h,00h,0Dh,7Dh,00h,7Ch,00h,00h ; 5  
		db   00h,00h,00h,00h,00h,00h,08h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; 6
		db   00h,00h,00h,00h,00h,00h,1Bh,00h,00h,2Bh,00h,2Dh,2Ah,00h,00h,00h ; 7  
		db   00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h,00h ; 8

	kbrd_state	dd	0
	
	;Bit	Beschreibung
	; ..	Zur Zeit unbenutzt
	; 2	CAPS LOCK Led
	; 1	NUM LOCK Led
	; 0	SCROLL LOCK Led
		
				
	ALIGN 16
	KERNEL_STARTUP LABEL WORD
SETUP ENDS

KERNEL_CODE SEGMENT PARA USE32 'CODE'
	ASSUME CS:KERNEL_CODE, DS:SETUP

	KERNEL_SIP:
	  ifdef DEBUG
	  	; Mal den Port fr die DEBUG-Daten einrichten...
	  	mov	dx, DEBUG_PORT
	  	add	dx, 4
	  	mov	al, 3		; RTS und DTR setzen
	  	out	dx, al
	  	jmp	short $+2
	  	jmp	short $+2
	  	mov	dx, DEBUG_PORT
	  	add	dx, 3
	  	mov	al, 10001011b	; 8-bit, 1 stop, odd parity
	  	out	dx, al
	  	jmp	short $+2
	  	jmp	short $+2
	  	mov	dx, DEBUG_PORT
	  	mov	al, 3		; 38400 Baud
	  	out	dx, ax
	  	jmp	short $+2
	  	jmp	short $+2
	  	inc	dx
	  	mov	al, 0		; MSB = 0
	  	out	dx, ax
	  	jmp	short $+2
	  	jmp	short $+2
	  	add	dx, 2
	  	mov	al, 00001011b	; DLAB off
	  	out	dx, al
	  	jmp	short $+2
	  	jmp	short $+2  	
	  	mov	bh, 0Ch
	  	call	print_ser
	  	mov	bh, 0dh
	  	call	print_ser
		mov	si, offset ds:dbg_info2
		call	dbg_ln
		mov	si, offset ds:dbg_info3
		call	dbg_ln
		mov	bh, 0ah
		call	print_ser
	  endif


	; Zun„chst mal sehen was der Kasten kann...

	call	equipment_check

  EQUIPMENT_OK:
		
	mov	dword ptr ds:[gp_crash], offset ds:init_crash
	mov	word ptr ds:[gp_crash+4], KERNEL_CS_SEL
	jnc	KERNEL_SETUP

	; Fehler! You can shove it up your ass...
	jmp	fword ptr ds:[SHUTDOWN_ADDR]
	
	include ..\setup\detectio.inc

;===========================================================================
 
  KERNEL_SETUP:	  
	mov	ax, RAM_SEL
	mov	es, ax

	mov	edi, 100000h		; Start bei 1MB

	; GDT mit 64K 
	xor	eax, eax
	mov	ecx, 10000h/4
	rep	stosd
	
	; Kopieren der bisherigen GDT (6x8 Byte)
	mov	edi, 100000h
	lea	esi, ds:GDT
	mov	ecx, GDT_SIZE / 4
	rep	movsd
	
	mov	eax, 100000h
	mov	bx, 0FFFFh
	mov     dword ptr [GDT_ptr+2], eax
      	mov     word ptr [GDT_ptr], bx
	
	; GDT neu laden
	lgdt	fword ptr gdt_ptr	
	
	; Ein paar Berechnungen zum RAM...
	mov	eax, dword ptr ds:[total_ram_bytes] 
	mov	ebx, PAGE_SIZE			    
	xor	edx, edx
	div	ebx		
	
	mov	dword ptr ds:[total_ram_pages], eax

	xor	edx, edx
	mov	ebx, PAGES_PER_TABEL
	div	ebx
	cmp	edx, 0
	je	@@ENTRY_OK
	inc	eax
	@@ENTRY_OK:
	
	mov	dword ptr ds:[pagetable_pages], eax
	
	; Das Page-Directory in Gr”áe des phys. RAMs
	; (Kernel ben”tigt 1:1 Belegung der Seiten!)

	mov	edi, KERNEL_PGDIR_START
	mov	esi, KERNEL_PGTAB_START
	
	mov	ecx, eax			; Anzahl der Tabellen
	
	; Alle Tabellen sind anwesende Seiten und nicht auslagerbar!!!

	add	esi, PG_PRESENT+PG_FIXED+PG_RW
	
@@CREATE_TABS:

	mov	dword ptr es:[edi], esi
	add	esi, PAGE_SIZE			; N„chste Tab + 4K
	add	edi, PGDIR_ENTRY_SIZE		; N„chster Eintrag

	loop	@@CREATE_TABS


	; Nun die Eintr„ge der Tabellen...

	mov	edi, KERNEL_PGTAB_START
	xor	esi, esi			; Start bei Adresse 0

	mov	ecx, dword ptr ds:[total_ram_pages]	
	
	; WICHTIG! Der E/A Adressbereich (A0000-0FFFFF) darf nicht ber
	; den Cache gefhrt werden!!!!! Hier gilt PCD=1!!!! 
	
	; Die phys. Seiten sind "anwesend, fixed, beutzt und rw"!

	add	esi, PG_RW+PG_PRESENT+PG_FIXED+PG_USED

@@CREATE_ENTRYS:

	mov	edx, esi
	cmp	esi, IO_AREA_START+PG_RW+PG_PRESENT+PG_FIXED+PG_USED
	jb	@@IOCHECK_OK
	
	cmp	esi, IO_AREA_END+PG_RW+PG_PRESENT+PG_FIXED+PG_USED
	jg	@@IOCHECK_OK

	add	edx, PG_NON_CACHEABLE


	@@IOCHECK_OK:

	mov	dword ptr es:[edi], edx
	add	edi, PGTAB_ENTRY_SIZE
	add	esi, PAGE_SIZE
	
	loop	@@CREATE_ENTRYS


	; PAGING action!
	
	cli					; Auf jeden Fall RUHE!	
	mov	dx, NMI_CONTROL
	mov	al, 80h				; NMI control shutup
	out	dx, al

	mov	eax, KERNEL_PGDIR_START
	mov	cr3, eax			 
	
	jmp	short $+2
	jmp	short $+2
	
	cli					; Auf jeden Fall RUHE!	
	mov	dx, NMI_CONTROL
	mov	al, 80h				; NMI control shutup
	out	dx, al

	mov	eax, cr0
	add	eax, 80000000h
	mov	cr0, eax			; OHOH Again!
	
	jmp	short $+2
	jmp	short $+2

	ifdef DEBUG
		lea	si, ds:dbg_info_4
		call	dbg_prn
		mov	edx, cr0
		call	dbg_32hex
		call	dbg_lf
		lea	si, ds:dbg_info_6
		call	dbg_prn
		mov	edx, cr3
		call	dbg_32hex
		call	dbg_lf
;	endif

	; MEMMORY MAP (Seite=1Bit)
	mov	eax, dword ptr ds:[pagetable_pages]
	mov	ebx, PAGE_SIZE
	xor	edx, edx
	mul	ebx
	mov	edi, KERNEL_PGTAB_START
	add	edi, eax

	mov	dword ptr ds:[memmap_addr], edi
	
	mov	eax, dword ptr ds:[total_ram_pages]
	; /8 = Anzahl der ben”tigten Bytes!
	xor	edx, edx
	mov	ebx, 8
	div	ebx
	; Das /4096 sind wiederum die ben”tigten Seiten
	xor	edx, edx
	mov	ebx, PAGE_SIZE
	div	ebx
	cmp	edx, 0
	je	@@MapPagesRoger
	inc	eax
	@@MapPagesRoger:

	; EAX=Anzahl Map Seiten!
	; Das ganze *1024 sind die anzahl der Dwords
	xor	edx, edx
	mov	ebx, 1024
	mul	ebx
	mov	ecx, eax
	xor	eax, eax
	cld
	rep	stosd

	; Markieren der vom Kernel belegten Seiten...
	
	mov	eax, dword ptr ds:[kernel_load_size]
	xor	edx, edx
	mov	ebx, PAGE_SIZE
	div	ebx
	cmp	edx, 0
	je	@@KSIZE_OK
	inc	eax
	@@KSIZE_OK:
	mov	ecx, eax
	mov	eax, 2			; Kernel startet auf Seite 2
	
	ifdef DEBUG
	 push 	ecx
	endif
	
	@@mark_kernel:
	call	memmap_mark
	ifdef DEBUG
	 jnc	@@MARK_OK
	 push	ecx
	 push	eax
 	 lea	si, ds:dbg_info_13
  	 call	dbg_prn
	 call	dbg_lf
	 pop	eax
	 pop	ecx
	 @@MARK_OK:
	endif
	inc	eax
	loop	@@mark_kernel
	

 	ifdef DEBUG
		lea	si, ds:dbg_info_11
		call	dbg_prn
		mov	edx, dword ptr ds:[kernel_load_size]
		call	dbg_32hex
		call	dbg_lf
		lea	si, ds:dbg_info_12
		call	dbg_prn
		pop	edx
		call	dbg_32hex
		call	dbg_lf
	endif
	
		
	; Wir tragen zun„chst mal das Timer Int in die Int-Tabell ein!
	lea	edi, ds:IDT
	add	edi, 100h			; INT VEC 20h
	mov	dword ptr ds:[edi], offset timer_int
	mov	word ptr ds:[edi+2], KERNEL_CS_SEL
	mov 	word ptr ds:[edi+4], 08e00h
		
	; Und Timer aktion...

		xor	al, al
		out	NMI_CONTROL, al
		sti
		jmp	short $+2
		jmp	short $+2

		mov	ax, VRAM_SEL
		mov	es, ax
		mov	ax, KERNEL_DS_SEL
		mov	fs, ax
		mov	ds, ax
		
		call	init_kbrd
		
		jmp	KERNEL_SHELL		
		
		@@LOOPTHIS:
			jmp @@LOOPTHIS
				
		include		..\VIDEO\VIDEO.INC
		include		..\KEYBOARD\KEYBOARD.INC
		include		..\SHELL\KRNLSHL.INC

	

	timer_int	proc far
		; Die ist das Kernstck des Multitaskings und l„uft daher
		; in einer Taskumgebung um die Stabilit„t zu gew„hrleisten,
		; wobei die Performance ein wenig darunter leidet.
		
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	edi
		push	ebp
		mov	edx, dword ptr ds:[TICK_TACK]
		inc	edx
		cmp	edx, 0ffffffffh
		jne	@@ShowTick
		xor	edx, edx
	@@ShowTick:
		mov	dword ptr ds:[TICK_TACK], edx
		mov	ch, 12
		mov	cl, 35
		mov	ah, 0eh
		call	print32hex
		pop	ebp		
		pop	edi
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		cli
		push	ax
		mov	al, 20h		; EOF Int
		out	20h, al
		pop	ax
		iretd
	timer_int	endp


	
	;--------------------------------------------------------------------
	; SET_BASE_LENGTH: Setzt die BASIS und LNGEN-Angabe in das 
	; Decriptor-Fromat um.
	;
	; Input : EAX=BASIS Adresse
	;	  EBX=LNGENWERT
	; Output: ECX=Descriptor DWORD 1
	;         EDX=Descriptor DWORD 2
	;
	; Status: Non API Func!
	;
	SET_BASE_LENGTH	proc near
		mov	ecx, eax
		shl	ecx, 16
		movzx	edx, bx
		add	ecx, edx
		push	eax
		shr	eax, 16
		movzx	edx, ah
		shl	edx, 24
		mov	dl, al
		push	ebx
		shr	ebx, 16
		shl	ebx, 16
		add	edx, ebx
		pop	ebx
		pop	eax
		ret
	set_base_length endp
	
	;====================================================================
	; Dir folgenden Funktionen sind nur fr den KERNEL bestimmt!
	; Alle Address-Angaben beziehen sich auf ES, welches mit einem
	; 4GB Segment-Beschreiber geladen sein muá! ES wird daher nicht
	; neu geladen. Es muá im TSS des Kernels den Selektor enthalten!!

	;--------------------------------------------------------------------
	; GET_TAB_ADDR: Liefert die Offset des PG-Tab Eintrages fr eine
	; logische Seite. (Bildet die Addressumsetzung der CPU nach)
	;
	; Input : EAX=log. Adresse fr die der Eintarg gesucht werden soll
	;	  ECX=Addr. (phys.) des Page Directory
	; Output: EDI=offset des Eintrages
	; Error : CF / BL
	;
	; Status: Non API Func!
	; Bezug : ES=Voller 4GB Zugriff!!
	; Access: Protected PL=0
	;
	get_tab_addr	proc near
		mov	edi, eax
		shr	edi, 22			; => Ordnialzahl Tabelle
		shl	edi, 2			; (*4) = Offset Tabelle
		add	edi, ecx		; =>Addr. Tabelleneintrag
		push	ebx
		mov	ebx, dword ptr es:[edi] ; Eintrag des PG-Dirs
		shr	ebx, 12
		shl	ebx, 12
		mov	edi, eax
		shl	edi, 10
		shr	edi, 22
	        shl	edi, 2			; (*4) = Offset in Tabelle
	        add	edi, ebx
	        pop	ebx
		clc
		ret
	get_tab_addr	endp
	
	;--------------------------------------------------------------------
	; MEM_GET_PHYS: Liefert fr eine logische die physikalische Adresse
	;
	; Input : EAX=Umzusetzende log. Adresse
	;	  ECX=Addr. (phys.) des Page Directory
	; Output: EDX=physikalische Adresse
	; Error : CF / BL
	;	        1 log. Seite ist abwesend (nicht im RAM)
	;
	; Status: Non API Func!
	; Bezug : ES=Voller 4GB Zugriff!!
	; Access: Protected PL=0
	;
	; Uses  : GET_TAB_ADDR
	;
	mem_get_phys	proc near
		push	edi
		call	get_tab_addr
		push	ebx
	        mov	ebx, dword ptr es:[edi] ; Eintrag der PG-Tab
	        test	ebx, 1
	        jz	@@PAGE_NOT_PRESENT
	        shr	ebx, 12
	        shl	ebx, 12
	        mov	edx, eax
	        shl	edx, 20
	        shr	edx, 20
	        add	edx, ebx
		pop	ebx
		pop	edi
		clc
		ret	        
	@@PAGE_NOT_PRESENT:
		pop	ebx
		pop	edi
		mov	bl, 1
	 	stc
	 	ret
	mem_get_phys	endp
	
	;--------------------------------------------------------------------
	; MEMMAP_CHECK: Prft ob eine Seite in der MEM-MAP belegt ist
	; 
	; Input : EAX=Zu prfende Seite
	; Output: CL=MEMMAP_BIT, EDI=MEMMAP_BYTE+MEMMAP_START
	; Error : CF / BL
	;		1 Seite ist belegt
	;		  CL=MEMMAP_BIT, EDI=MEMMAP_BYTE+MEMMAP_START
	;		2 Seite nicht im phys. RAM-Bereich
	;
	; Status: Non API Func!
	; Bezug : ES=Voller 4GB Zugriff!!
	; Access: Protected PL=0
	;
	memmap_check	proc near
		; Zun„chst sehen ob die Seite berhaupt existiert!
		cmp	eax, dword ptr ds:[total_ram_pages]
		ja	@@OUT_OF_RANGE
		; EAX/8 gibt das byte an - modulo = das bit im byte!
		push	eax ebx edx 
		mov	edi, dword ptr ds:[memmap_addr]
		mov	ebx, 8h
		xor	edx, edx
		div	ebx
		add	edi, eax
		mov	cl, dl
		mov	al, byte ptr es:[edi]
		shr	al, cl
		test	al, 1
		jnz	@@IN_USE
		pop	edx ebx eax 
		clc
		ret
	@@IN_USE:
		pop	edx ebx eax
		mov	bl, 1			; Seite in Benutzung
		stc
		ret
	@@OUT_OF_RANGE:
		mov	bl, 2			; Seite nicht im phys. RAM
		stc
		ret
	memmap_check	endp
	
	;--------------------------------------------------------------------
	; MEMMAP_MARK: Markiert eine Seite in der MEM-MAP
	;
	; Input : EAX=Zu markierende Seite
	; Output: Seite markiert
	; Error : CF / BL
	;		1 Seite ist bereits belegt
	;		2 Seite nicht im phys. RAM-Bereich
	;
	; Status: Non API Func!
	; Bezug : ES=Voller 4GB Zugriff!!
	; Access: Protected PL=0
	;
	; Uses  : MEMMAP_CHECK
	;
	memmap_mark	proc near
		push	ecx edi
		call	memmap_check
		jc	@@FAILURE
		push	eax
		mov	ah, 1
		mov	al, byte ptr es:[edi]
		shl	ah, cl
		add	al, ah
		mov	byte ptr es:[edi], al
		pop	eax edi ecx
		clc
		ret		
	@@FAILURE:
		pop	edi ecx
		stc
		ret
	memmap_mark	endp
	
	;--------------------------------------------------------------------
	; MEMMAP_DEMARK: Gibt eine Seite in der MEM-MAP frei
	;
	; Input : EAX=freizugebende Seite
	; Output: Seite freigegeben
	; Error : CF / BL
	;		1 Seite war bereits frei
	;		2 Seite nicht im phys. RAM-Bereich
	;
	; Status: Non API Func!
	; Bezug : ES=Voller 4GB Zugriff!!
	; Access: Protected PL=0
	;
	; Uses  : MEMMAP_CHECK
	;
	memmap_demark	proc near
		push	ebx ecx edi
		call	memmap_check
		jnc	@@IS_FREE
		cmp	bl, 2
		je	@@NIX_GIBTS
		push	eax
		mov	ah, 1
		mov	al, byte ptr es:[edi]
		shl	ah, cl
		sub	al, ah
		mov	byte ptr es:[edi], al
		pop	eax edi ecx ebx
		clc
		ret
	@@NIX_GIBTS:
		pop	edi ecx ebx
		mov	bl, 2			; Seite existiert nicht
		stc
		ret		
	@@IS_FREE:
		pop	edi ecx ebx
		mov	bl, 1			; Seite garnicht belegt
		stc
		ret
	memmap_demark	endp

	
	uu_int		proc far
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	edi
		push	ebp
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	bp, sp
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
	  ifdef DEBUG
		mov	edi, 10
		call	print_debug
	  endif
		pop	ebp		
		pop	edi
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		push	ax
		mov	al, 20h		; EOF Int
		out	20h, al
		pop	ax
		iretd
	uu_int		endp

	gp_int		proc far
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		xor	bp, bp
		mov	bp, sp
		mov	edi, offset ds:last_gp_fault
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
		cmp	ebx, dword ptr ds:[edi]
		jne	@@go_on
		cmp	cx, word ptr ds:[edi+4]
		jne	@@go_on
		jmp	df_int
	  @@go_on:
	  	mov	dword ptr ds:[edi], ebx
	  	mov	word ptr ds:[edi+4], cx

	  ifdef DEBUG
	  	push	eax
	  	push	ecx
	  	push	ebx
		xor	edi, edi
		call	print_debug
		pop	edx
		pop	ebx
		pop	ecx
	  endif
		mov	bp, sp
		mov	eax, dword ptr ds:[GP_CRASH]
		mov	dword ptr ss:[bp], eax		; neuer EIP
		xor	eax, eax
		mov	ax, word ptr ds:[GP_CRASH+4]
		mov	dword ptr ss:[bp+4], eax	; neues CS
		xor	eax, eax
		mov	eax, 4
		iretd
	gp_int		endp

	tss_int		proc far
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	bp, sp
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
	  ifdef DEBUG
	  	push	eax
	  	push	ecx
	  	push	ebx
		mov	edi, 4
		call	print_debug
		pop	edx
		pop	ebx
		pop	ecx
	  endif
		mov	bp, sp
		mov	eax, dword ptr ds:[TSS_CRASH]
		mov	dword ptr ss:[bp], eax		; neuer EIP
		xor	eax, eax
		mov	ax, word ptr ds:[TSS_CRASH+4]
		mov	dword ptr ss:[bp+4], eax	; neues CS
		mov	eax, 5
		iretd
	tss_int		endp

	s_int		proc far
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	bp, sp
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
	  ifdef DEBUG
	  	push	eax
	  	push	ecx
	  	push	ebx
		mov	edi, 6
		call	print_debug
		pop	edx
		pop	ebx
		pop	ecx
	  endif
		mov	bp, sp
		mov	eax, dword ptr ds:[STACK_CRASH]
		mov	dword ptr ss:[bp], eax		; neuer EIP
		xor	eax, eax
		mov	ax, word ptr ds:[STACK_CRASH+4]
		mov	dword ptr ss:[bp+4], eax	; neues CS
		mov	eax, 6
		iretd
	s_int		endp

	df_int		proc far
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	bp, sp
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
	  ifdef DEBUG
	  	push	eax
	  	push	ecx
	  	push	ebx
		mov	edi, 8
		call	print_debug
		pop	edx
		pop	ebx
		pop	ecx
	  endif
		mov	bp, sp
		mov	eax, dword ptr ds:[DF_CRASH]
		mov	dword ptr ss:[bp], eax		; neuer EIP
		xor	eax, eax
		mov	ax, word ptr ds:[DF_CRASH+4]
		mov	dword ptr ss:[bp+4], eax	; neues CS
		mov	eax, 7
		iretd
	df_int		endp

	op_int		proc far
		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	bp, sp
		mov 	eax, dword ptr ss:[bp]		; ERR-Code
		mov	ecx, dword ptr ss:[bp+8]	; CS
		mov	ebx, dword ptr ss:[bp+4]	; EIP
		mov	edx, dword ptr ss:[bp+12]	; EFLAGS
	  ifdef DEBUG
	  	push	eax
	  	push	ecx
	  	push	ebx
		mov	edi, 2
		call	print_debug
		pop	edx
		pop	ebx
		pop	ecx
	  endif
		mov	bp, sp
		mov	eax, dword ptr ds:[OP_CRASH]
		mov	dword ptr ss:[bp], eax		; neuer EIP
		xor	eax, eax
		mov	ax, word ptr ds:[OP_CRASH+4]
		mov	dword ptr ss:[bp+4], eax	; neues CS
		mov	eax, 8
		iretd
	op_int	endp		

	init_crash	proc near
		; Wir kommen hier nur an, wenn im Laufe von INIT ein Fehler
		; Fatalo im !ProtMode! aufgetreten ist. 
		
		push	ebx
		push	ecx
		push	edx
		mov	dx, ax
		push	eax

		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		mov	fs, ax
		mov	gs, ax		
		mov	ax, VRAM_SEL	; Clear Screen!
		mov	es, ax
		mov	cx, 2000
		xor	edi, edi
		mov	ax, 0720h
		cld
		rep	stosw	

		cmp	dx, 0
		je	@@dos_restss
		
		xor	cx, cx		; Zeile=0, Spalte=0
		mov	ah, 79		; WEIá auf ROT	
		mov	si, offset ds:kernel_panic
		call	print

		mov	ch, 4
		mov	cl, 0
		mov	ah, 07h
		mov	si, offset ds:panic_help
		call	print
		mov	ch, 11
		mov	cl, 3
		mov	ah, 0Eh
		mov	si, offset ds:panic_err
		call	print
		mov	ch, 13
		mov	cl, 3
		mov	ah, 07h
		mov	si, offset ds:panic_exp
		call	print
		mov	ch, 15
		mov	cl, 3
		mov	ah, 07h
		mov	si, offset ds:panic_ref
		call	print		
		mov	ch, 17
		mov	cl, 3
		mov	ah, 07h	
		mov	si, offset ds:panic_locate
		call	print
		mov	ch, 19
		mov	cl, 3
		mov	ah, 07h	
		mov	si, offset ds:panic_howto
		call	print
		xor	eax, eax
		xor	edx, edx
		pop	eax
		mov	edx, eax
		push	eax
		mov	ch, 15
		mov	cl, 19
		mov	ah, 0fh
		call	print32hex
		pop	eax
		mov	bx, 6
		mul	bx
		xor	edi, edi
		mov	di, offset ds:panic_list
		add	di, ax
		mov	si, word ptr ds:[di]
		push	edi
		mov	ch, 13
		mov	cl, 19
		mov	ah, 0fh
		call	print
		pop	edi
		add	di, 2
		mov	si, word ptr ds:[di]
		push	edi
		mov	ch, 17
		mov	cl, 19
		mov	ah, 0fh
		call	print
		pop	edi
		add	di, 2
		mov	si, word ptr ds:[di]
		mov	ch, 19
		mov	cl, 19
		mov	ah, 0fh
		call	print
		pop	edx		
		cmp	edx, 0
		je	short @@err_001
		mov	ch, 18
		mov	cl, 19
		mov	ah, 0fh
		call	print32hex
	@@err_001:
		pop	ecx
		cmp	ecx, 0
		je	short @@err_002
		mov	edx, ecx
		mov	ch, 18
		mov	cl, 28
		mov	ah, 0fh
		call	print32hex
	@@err_002:
		pop	ebx
		cmp	ebx, 0
		je	short @@dos_bye
		mov	edx, ebx
		mov	ch, 18
		mov	cl, 37
		mov	ah, 0fh
		call	print32hex	
		jmp	short @@dos_bye
	@@dos_restss:
		pop	eax
		pop	eax
		pop	eax
		pop	eax
	@@dos_bye:
		xor	esi, esi
		mov	ch, 22
		mov	cl, 7
		mov	ah, 0fh
		mov	si, offset ds:panic_adios
		call	print
		cli				; Ints mal Klappe halten!
		mov	dx, NMI_CONTROL
		mov	al, 80h
		out	dx, al			; NMIs auch mal ruhe...
		hlt
	init_crash	endp

;============================================================================

  ifdef DEBUG
	dbg_8hex	proc near
		; dl = 8 Bit Wert zum Anzeigen
		mov	al, dl
		shr	al, 4
		add	al, 48
		cmp	al, 57
		jg	@@addasccode
		jmp	@@hianteil
	 @@addasccode:
	 	add	al, 7
	 @@hianteil:
	 	mov	bl, dl
		and	bl, 15
		add	bl, 48
		cmp	bl, 57
		jg	@@addasccode2
		jmp	@@lasssehen
	 @@addasccode2:
	 	add	bl, 7
	 @@lasssehen:
		mov	bh, al
		call	print_ser
		mov	bh, bl
		call	print_ser
 		ret
	dbg_8hex	endp

	dbg_16hex	proc near
		; dx = 16 Bit Wert
		push	dx
		mov	ax, dx
	        xor	dx, dx
	        mov	dl, ah
	        call	dbg_8hex
	        pop	dx
	        call	dbg_8hex
		ret        	
	dbg_16hex	endp

	dbg_32hex	proc near
	; edx = 32 Bit Wert
		push	edx
		push	eax
		mov	eax, edx
		shr	edx, 16
		pop	eax
		call	dbg_16hex
		pop	edx
		call	dbg_16hex
		ret
	dbg_32hex	endp

	print_ser	proc near
		; Ausgabe eines Zeichens in BH an DEBUG_PORT
		;
		push	dx
		push	ax
		mov	dx, DEBUG_PORT
		cld
	  	add	dx, 5
	  @@wait_loop1:
	  	inc	dx
	  	in	al, dx			; Modem Status holen
	  	jmp	short $+2
	  	jmp	short $+2
	  	test	al, 80h			; Any Problems?
	  	jz	short @@send_ends
	  	dec	dx  
	  	in	al, dx
	  	jmp	short $+2
	  	jmp	short $+2
	  	test	al, 20h			; Ready to send?
	  	jz	short @@wait_loop1
	  	mov	dx, DEBUG_PORT
		mov	al, bh
		out	dx, al
		jmp	short $+2
		jmp	short $+2
  	  @@send_ends:
		pop	ax
		pop	dx
		ret
	print_ser	endp

	dbg_prn		proc near
	  @@prn_dbg:
		mov	bh, byte ptr ds:[si]
		cmp	bh, '$'
		je	@@dbgln_ends
		call	print_ser
		inc	si
		jmp	short @@prn_dbg
	  @@dbgln_ends:
	  	ret
	dbg_prn		endp	

	dbg_lf		proc near
	  	mov	bh, 0ah
	  	call	print_ser
	  	mov	bh, 0dh
	  	call	print_ser
	  	ret
	dbg_lf		endp
	
	dbg_ln		proc near
		call	dbg_prn
		call	dbg_lf
	  	ret
	dbg_ln		endp

	print_debug	proc near
		; eax=ERR-CODE, ebx=EIP, ecx=CS, edx=EFLAGS, di=FAULT-Type
		push	si
		push	edx
		push	ecx
		push	ebx
		push	eax
		mov	si, offset ds:dbg_list
		add	si, di
		mov	di, word ptr ds:[si]
		mov	ecx, 12
	  @@prn_loop1:
		mov	bh, byte ptr ds:[di]
	  	call	print_ser
	  	inc	di
		loop	@@prn_loop1
	  @@prn_ok:
	  	mov	bh, 20h			; gonna send it out of space..
	  	call	print_ser		; Haha! (by Prodigy)
	  	pop	edx			;EAX->EDX
	  	call	dbg_32hex
	  	mov	bh, 20h
	  	call	print_ser
	  	pop	edx			;EBX->EDX
	  	call	dbg_32hex
	  	mov	bh, 20h
	  	call	print_ser
	  	pop	edx			;ECX->EDX
	  	call	dbg_32hex
	  	mov	bh, 20h
	  	call	print_ser
	  	pop	edx			;EDX
	  	call	dbg_32hex
	   	mov	bh, 0Ah
	   	call	print_ser
	   	mov	bh, 0Dh
	   	call	print_ser
	   	pop	si
		ret
	print_debug	endp	
  endif

	print8hex	proc near
		; dl = 8 Bit Wert zum Anzeigen
		; cl = Cursor X-Position (0..79)
		; ch = Cursor Y-Position (0..24)
		; ah = Farb-Attribut
		mov	al, dl
		shr	al, 4
		add	al, 48
		cmp	al, 57
		jg	@@addasccode
		jmp	@@hianteil
	 @@addasccode:
	 	add	al, 7
	 @@hianteil:
	 	mov	bl, dl
		and	bl, 15
		add	bl, 48
		cmp	bl, 57
		jg	@@addasccode2
		jmp	@@lasssehen
	 @@addasccode2:
	 	add	bl, 7
	 @@lasssehen:
	 	mov	dx, VRAM_SEL
	 	mov	es, dx
		push	bx
		xor	bx, bx
		movzx	bx, cl
		add	bx, bx		; X-Offset (Spalte * 2)
		push	ax
		xor	ax, ax
		movzx	ax, ch
		push	cx
		mov	cx, 160		; Y-Offset (Zeile * 160)
		mul	cx
		add	ax, bx
		xor	edi, edi
		mov	di, ax
		pop	cx
		pop	ax
		pop	bx
	 	cld
	 	stosw
	 	mov	al, bl
		cld
	 	stosw
	 	add	cl, 2
	 	ret
	print8hex	endp

	print16hex	proc near
		; dx = 16 Bit Wert
		; cl = Cursor X-Position (0..79)
		; ch = Cursor Y-Position (0..24)
		; ah = Farb-Attribut
		push	dx
		push	ax
		mov	ax, dx
	        xor	dx, dx
	        mov	dl, ah
	        pop	ax
	        call	print8hex
	        pop	dx
	        call	print8hex
		ret        	
	print16hex	endp

	print32hex	proc near
		; edx = 32 Bit Wert
		; cl = Cursor X-Position (0..79)
		; ch = Cursor Y-Position (0..24)
		; ah = Farb-Attribut
		push	edx
		push	eax
		mov	eax, edx
		shr	edx, 16
		pop	eax
		call	print16hex
		pop	edx
		call	print16hex
		ret
	print32hex	endp

	print	proc near
		; Ausgabe eines Null-Terminierten Strings
		; cl = Cursor X-Position (0..79)
		; ch = Cursor Y-Position (0..24)
		; ah = Farb-Attribut
		; ds = Segment-Adr des String
		; si = Offset des String
		mov	bx, VRAM_SEL
		mov	es, bx
		movzx	bx, cl
		add	bx, bx		; X-Offset (Spalte * 2)
		push	ax
		movzx	ax, ch
		mov	cx, 160		; Y-Offset (Zeile * 160)
		mul	cx
		add	ax, bx
		xor	edi, edi
		mov	di, ax
		pop	ax
	    @@ploop:
	    	mov	al, byte ptr ds:[si]
	    	cmp	al, '$'
	    	jz	@@checkend	
	    @@printit:
		cld
	    	stosw
	    	inc	si
	    	jmp	@@ploop
	    @@checkend:
	        mov	al, byte ptr ds:[si+1]
	        cmp	al, '$'
	        jz	@@printit
	        ret
	print	endp

	ALIGN 16
KERNEL_CODE ENDS
;ÄENDE!ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
end		startup_ip

