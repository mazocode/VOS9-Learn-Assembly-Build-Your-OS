;ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ
; VOS9 - The Virtual Operating System
; (c)(r) 1995 by MZ Computer Systems
;
; 	File		DETECTION.INC
; 	Version 	Alpha 1
; 	Release		1
; 	Funktion	Hardware Erkennungs-Routinen
; 	Erstellt	09.08.1995
; 	Update		30.11.1995
; 	Autor		Marcus Zoller
;ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ
; Erkennung aller wesentlichen Hardware merkmale.
; Wir werden nun sehen welche standardisierten Hardware-Bestandteile
; in der Kiste stecken. Wir werden hier nach keinerlei Exotischen
; Teilen suchen. 
;
; Festplatten       : IDE-Laufwerke (max. 4 StÅck)
;		    : Hersteller/Daten/Ser.-Nr.
; Diskettenlaufwerke: 5.25"- 1.2MB, 3.5"- 2.88 MB
; Grafikkarten      : Hercules, VGA, EGA, XGA, CGA (max. 2 StÅck prim/sek)
;		    ; VESA Standard Check, Vendor ID/Str.
; Schnittstellen    : Par. (max. 3 StÅck), Ser. (max. 4 StÅck), Game (1 St.)
; System-Bus        : ISA, VLB, EISA, MCA, PCI
; Cpu		    : CPU Typ/Hersteller (event. CPUID), FPU Type/Hersteller
;                   : ab Pentium anz. CPUs (max. 4 StÅck), Speed in MHz
; CPU Index	    : Performance Index/MIPS Bench
; Board ID	    : Computer Hersteller
; Plug & Play	    : UnterstÅtzt ? Was alles gefunden?
; CMOS		    : Zeit/Datum/Modus/Status
;
; Die Daten werden spÑter, Ñhnlich dem BIOS Datensegment, fÅr DPL3RO-Zugriffe
; aller Software zur verfÅgung gestellt. 
;
;ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ 

equipment_check proc near
	;
	; Allgemeines: Wir richten hier weder Treiber noch sonstiges ein.
	; Wir sehen lediglich noch was vorhanden ist und ob das Zeuch auch
	; funktioniert. Was der Benutzer davon Benutzen will ist seine Sache!
	;
	; 1. Nun wollen wir mal sehen was die CPU so alles bringt...
	;
	; CPUID unterstÅtzt?
	; Wir der Befehl nicht unterstÅtzt, so wird ein OP-Fault ausgel.
	; Daher Catchen wir diesen.


		mov	al, 80h
		out	NMI_CONTROL, al
		cli

		mov	ax, KERNEL_DS_SEL
		mov	ds, ax
		
	ifdef DEBUG
		mov	esi, offset ds:dbg_msg6
		call	dbg_ln
		call	dbg_lf
	endif
	 	
		; Im Falle eines Falles gehts hier weiter...
		
		mov	dword ptr ds:[OP_CRASH], offset no_cpuid
		mov	word ptr ds:[OP_CRASH+4], KERNEL_CS_SEL

		xor	eax, eax		; Level 0 ID
		mov	dword ptr ds:[optb], eax
		
		db	0fh, 0a2h		; CPUID Befehl
		; Wir haben nun in EBX-EDX-ECX 12 Zeichen (Hersteller)

		mov	dword ptr ds:[optb], eax
		mov	dword ptr ds:[cpu_str], ebx
		mov	dword ptr ds:[cpu_str+4], edx
		mov	dword ptr ds:[cpu_str+8], ecx
		
		xor	eax, eax
		xor	edx, edx
		mov	eax, 1		
		db	0fh, 0a2h		; CPUID Level 1

		; FMS in EAX, OPT in EDX
		mov	dword ptr ds:[fms], eax
		mov	dword ptr ds:[optA], edx
		
		jmp	CPUID_001
		
	NO_CPUID:				; Nix wars!	

	  	mov	eax, dword ptr ds:[EQUIPMENT_MSG2]
	  	mov	ebx, dword ptr ds:[EQUIPMENT_MSG2+4]
	  	mov	ecx, dword ptr ds:[EQUIPMENT_MSG2+8]
	  	mov	dword ptr ds:[CPU_STR], eax
	  	mov	dword ptr ds:[CPU_STR+4], ebx
	  	mov	dword ptr ds:[CPU_STR+8], ecx

		; Wir wissen das es mindestens ein 386 sein mu·!
		; Nun die Preisfrage... 386 od. 486?
        	pushfd                     
        	pop     eax        		; Flags nach EAX
        	mov     ebx, eax           	
        	xor     eax, 40000h        	; Bit 18 umdrehen
        	push    eax                     ; (erst ab 486!)               
        	popfd                      	; Laden
        	pushfd                     	
        	pop     eax                	; Flags holen
        	push    ebx                	; Orginal auf den Stack
        	popfd                      	; Orginal wiederherstellen
        	xor     eax, ebx           	; Bit geÑndert worden?
        	jnz     short @@up486          	; Ist 80486 CPU
		; Ist 80386 CPU
		xor	eax, eax
		mov	eax, 3h			; Ist 386 CPU
		jmp	short @@cpu_ok
	@@up486:	
		xor	eax, eax
		mov	eax, 4h			; Ist 486 CPU
	@@cpu_ok:
		; eax=40h =>486, eax=30h =>386
		xor	ebx, ebx
		shl	eax, 8
	  	mov	dword ptr ds:[fms], eax
	  	mov	dword ptr ds:[opta], ebx
	  		  	
	CPUID_001:
		; Soweit so gut, Nun werden wir jedoch noch nach ein paar
		; brauchbaren Befehlen suchen, welche nicht in jeder CPU
		; implementiert sind und auch nicht Åber CPUID in Erfahrung
		; zu bringen sind.

		; Mal sehen ob UMOV funktioniert...
		
		mov	dword ptr ds:[OP_CRASH], offset UMOV_BAD
		mov	word ptr ds:[OP_CRASH+4], KERNEL_CS_SEL
		mov	dword ptr ds:[GP_CRASH], offset UMOV_BAD
		mov	word ptr ds:[GP_CRASH+4], KERNEL_CS_SEL
						
        	mov     al, 05Ah
        	mov     bh, 0A5h
        	clc                        
        	db      0Fh, 10h, 0F8h     	; umov al, bh
	       	db      90h, 90h
        	jc      UMOV_BAD
        	cmp     al, bh	
        	jne     UMOV_BAD

		; UMOV war OK
		mov	edx, dword ptr ds:[optb]
		add	edx, 10h
		mov	dword ptr ds:[optb], edx

	UMOV_BAD:
		; UMOVE war nix. So neben bei: DÅrfte ne Cyrix CPU sein.
		; Mal sehen ob ein RDMSR mit ECX=1000h mîglich ist...

		mov	dword ptr ds:[OP_CRASH], offset RDMSR_BAD
		mov	word ptr ds:[OP_CRASH+4], KERNEL_CS_SEL
		mov	dword ptr ds:[GP_CRASH], offset RDMSR_BAD
		mov	word ptr ds:[GP_CRASH+4], KERNEL_CS_SEL
				 					
		xor	ecx, ecx
        	db	0fh, 32h		; RDMSR
	       	db      90h, 90h           	; 2 NOPs
		
		mov	edx, dword ptr ds:[optb]
		add	edx, 20h
		mov	dword ptr ds:[optb], edx
			
	RDMSR_BAD:
		mov	dword ptr ds:[OP_CRASH], offset RDMSR2_BAD
		mov	word ptr ds:[OP_CRASH+4], KERNEL_CS_SEL
		mov	dword ptr ds:[GP_CRASH], offset RDMSR2_BAD
		mov	word ptr ds:[GP_CRASH+4], KERNEL_CS_SEL
		
		mov	ecx, 1000h		; Nur IBM CPUs
        	db	0fh, 32h		; RDMSR
	       	db      90h, 90h           	; 2 NOPs
		
		mov	edx, dword ptr ds:[optb]
		add	edx, 30h
		mov	dword ptr ds:[optb], edx

	RDMSR2_BAD:
		; Alte Crash-Adresse wiederherstellen!	
		mov	dword ptr ds:[OP_CRASH], offset init_crash
		mov	word ptr ds:[OP_CRASH+4], KERNEL_CS_SEL
		mov	dword ptr ds:[GP_CRASH], offset init_crash
		mov	word ptr ds:[GP_CRASH+4], KERNEL_CS_SEL
				
	  ifdef DEBUG
		mov	esi, offset ds:equipment_msg3
		call	dbg_prn
		mov	esi, offset ds:cpu_str
  		call	dbg_prn				; CPU_VENDOR
		mov	esi, offset ds:equipment_msg4
		call	dbg_prn
	  	mov	edx, dword ptr ds:[fms]
	  	call	dbg_16hex			; FMS  	
		mov	esi, offset ds:equipment_msg5
		call	dbg_prn
	  	mov	edx, dword ptr ds:[opta]
	  	call	dbg_32hex			; OPTA
	  	mov	esi, offset ds:equipment_msg6
	  	call	dbg_prn
	  	mov	edx, dword ptr ds:[optb]
	  	call	dbg_32hex			; OPTB
		call	dbg_lf
		mov	esi, offset ds:equipment_msg7
		call	dbg_prn
	  endif

		mov	al, 80h
		out	NMI_CONTROL, al
		cli

		; Greifen wir auf den gleichen Chip mehrmals zu, brauchen
		; wir einen IO-Delay, welche je nach CPU Geschw. untersch.
		; ist. Wir werfen den Timer an und Loopen eine Routine
		; 1000 mal. Wir lesen dann den Timer und rechnen zurÅck
		; auf 5ms.

	        mov     al, 0B0h           ; Timer 2 command, mode 0
        	out     43h, al            ; send command
        	jmp	short $+2
        	jmp	short $+2
        	mov     al, 0FFh           ; counter value FFFF
        	out     42h, al            ; send lsb to counter
        	jmp	short $+2
        	jmp	short $+2
        	out     42h, al            ; send msb to counter
        	jmp	short $+2
        	jmp	short $+2
	        in      al, 61h            ; read the current contents
        	jmp	short $+2
        	jmp	short $+2
        	or      al, 1              
        	out     61h, al            ; Timer anschmei·en... (Tick...)

		mov	ecx, 1000	   ; Und abraven...
	@@delay_loop:
		jmp	short $+2
		jmp	short $+2
		loop	@@delay_loop

	        in      al, 61h            ; read the current contents
        	jmp	short $+2
        	jmp	short $+2
        	and     al, 0FEh           ; Halte mal Waldemar Haha!
        	out     61h, al
	        mov     al, 80h            ; latch output command
	        out     43h, al            ; send command 
        	jmp	short $+2
        	jmp	short $+2
	        in      al, 42h            ; get lsb of counter
        	jmp	short $+2
        	jmp	short $+2
                mov     dl, al          
        	in      al, 42h            ; get msb of counter
		jmp	short $+2
		jmp	short $+2
        	mov     dh, al             ; dx = Counter-Wert
        	
		xor	eax, eax
        	mov     ax, 0FFFFh         ; starting value
        	sub     ax, dx             ; ax = Zeit-Wert

		; 1194 Timer Ticks ~ ca. 1 ms
		; 5970 Timer Ticks ~ ca. 5 ms
		
		cmp	ax, 5970
		jb	@@delay_tosmall
		mov	eax, 1000
		jmp	short @@delay_ok		

	@@delay_tosmall:
		; Der Wert ist kleiner als 5 ms.
		xor	ebx, ebx
		xor	edx, edx
		mov	bx, ax
		mov	eax, 5970
		div	bx
		; AX=Multiplikator fÅr 1000 Loops
		xor	edx, edx
		movzx	edx, ax
		mov	eax, 1000
		mul	edx
		jc	@@delay_max
		jmp	@@delay_ok
	@@delay_max:
		mov	eax, 0FFFFFFFFh
		
	@@delay_ok:
		mov	edx, eax
		mov	dword ptr ds:[IO_DELAY], edx


	ifdef DEBUG
		call	dbg_32hex
		call	dbg_lf
	endif
	
	; 
	; 2. Wieviel RAM hat der Apparillo...
	;    Der Siliciumkasten mu· ja mindestens ein MB habe um den KERNEL
	;    zu laden. Wir testen also ab 1MB indem wir 32 Bits in den
	;    RAM schreiben und diese dann zurÅcklesen. Sollte der Inhalt
	;    nicht Åbereinstimmen gibt es 2 Mîglichkeiten:
	;
	;     1. Die RAMs sind defekt!
	;     2. Wir haben das Ende erreicht!
	;
	;    Um dies zu unterscheiden gehen wir von folgendem aus:
	;
	;    Adresse <> MB => RAM defekt
	;    Adresse =  MB => RAM OK, Ende ereicht
	;   
	; RAM defekt: Wir verweigern die Arbeit und teilen die Adresse,
	; sprich auch das defekte MB mit! => Wir schicken die CPU in den
	; Shutdown.
	;
		mov	ax, RAM_SEL
		mov	gs, ax

		mov	edi, 100000h		; Start bei 1MB
	@@test_mem:
		mov	eax, 0aaaah
		mov	edx, dword ptr gs:[edi]
		mov	dword ptr gs:[edi], eax		
		mov	eax, dword ptr gs:[edi]
		mov	dword ptr gs:[edi], edx
		cmp	eax, 0aaaah		; Inhalt OK?
		jne	short @@memtest_ends
		add	edi, 4
		jmp	short @@test_mem
	@@memtest_ends:
		; edi enthÑlt nun die Adresse (grî·e in Bytes).

		mov	dword ptr ds:[total_ram_bytes], edi
		mov	eax, edi
		mov	ebx, 000400h		; Teilen durch 1024
		xor	edx, edx
		div	ebx
		cmp	edx, 0			; Rest vorhanden?
		je	short @@memtest_ok
		mov	edx, edi		; Fuck off
		xor	edi, edi
		xor	ecx, ecx
		xor	ebx, ebx
		xor	eax, eax
		mov	ax, 1
		stc
		ret

	@@memtest_ok:	
		
	ifdef DEBUG
		mov	edx, eax
		mov	esi, offset ds:equipment_msg0
		call	dbg_prn
		call	dbg_32hex
		mov	esi, offset ds:equipment_msg1
		call	dbg_ln
	endif

		; Ich wei· nicht warum, aber der Pentium lî·t nach
		; dem RET-Befehl einen GP-Fault aus...
		mov	dword ptr ds:[gp_crash], offset equipment_ok
		mov	word ptr ds:[gp_crash+4], KERNEL_CS_SEL
		xor	eax, eax
		clc
		ret
equipment_check endp

;ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ 

