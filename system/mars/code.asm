; ====================================================================		
; ----------------------------------------------------------------
; MARS SH2 Section
;
; CODE for both CPUs
; RAM and some DATA go here
; ----------------------------------------------------------------

		phase CS3		; now we are at SDRAM
		cpu SH7600		; should be SH7095 but this works.

; ====================================================================
; ----------------------------------------------------------------
; User settings
; ----------------------------------------------------------------

; Third scrolling layer settings, For gfx mode 1
;
; The scrolling system only draws the new sections when the camera
; when it moves to new locations
; Do note that drawing the new sections takes TWO frames, because
; of how the framebuffer shows pixels on screen.
; (one buffer for drawing, one for show)
; The maximum moving speed is divided by 2 depending of
; the BLKSIZE setting. (BLKSIZE/2)
;
; Map data can be either ROM data or a RAM section,
; Background's WIDTH and HEIGHT are defined by gbr variables (BgWidth and BgHeight)
; but the sizes must be aligned by the same value as BLKSIZE
;
; SVDP FILL breaks because this scroll system manipulates the linetable.
; (unless I come up with a workaround)

MSCRL_BLKSIZE		equ $10		; Block size for both directions, aligned by 4
MSCRL_WIDTH		equ 320+$10	; Internal width for scrolldata
MSCRL_HEIGHT		equ 240+$10	; Internal height for scrolldata

; ----------------------------------------
; Polygon settings
; (can manipulate 3 or 4 points)
; ----------------------------------------

MAX_MPLGN	equ	128		; Maximum polygon faces to store on buffer(s)
MAX_SVDP_PZ	equ	128+64		; Polygon pieces r/w list, loops
; MAX_MODELS	equ	24		; Note: First 9 models are reserved for layout map
; MAX_ZDIST	equ	-$2400		; Max drawing distance (-Z max)
; LAY_WIDTH	equ	$20*2		; Layout data width * 2

; ----------------------------------------
; Normal sprite settings
; ----------------------------------------

MAX_MSPR	equ	128		; Maximum sprites

; ====================================================================
; ----------------------------------------------------------------
; MARS GBR variables for both SH2
; ----------------------------------------------------------------

			struct 0
marsGbl_BgData		ds.l 1		; Background pixel data location (ROM or RAM)
marsGbl_BgData_R	ds.l 1		; Background data pointer (Mode 2 only)
marsGbl_PlyPzList_R	ds.l 1		; Current graphic piece to draw
marsGbl_PlyPzList_W	ds.l 1		; Current graphic piece to write
marsGbl_Plgn_Read	ds.l 1
marsGbl_Plgn_Write	ds.l 1
marsGbl_Bg_FbBase	ds.l 1		; X base position for Up/Down draw
marsGbl_Bg_FbCurrR	ds.l 1
marsGbl_Bg_Xpos		ds.w 1
marsGbl_Bg_Ypos		ds.w 1
marsGbl_Bg_XShift	ds.w 1
marsGbl_Bg_Xpos_old	ds.w 1
marsGbl_Bg_Ypos_old	ds.w 1
marsGbl_BgArea_Width	ds.w 1
marsGbl_BgArea_Height	ds.w 1
marsGbl_GraphMode	ds.w 1
marsGbl_BgWidth		ds.w 1
marsGbl_BgHeight	ds.w 1
marsGbl_Bg_Xscale	ds.w 1
marsGbl_Bg_Yscale	ds.w 1
marsGbl_Bg_Xset		ds.w 1		; Redraw timers
marsGbl_Bg_Yset		ds.w 1		;
marsGbl_Bg_YFbPos_U	ds.w 1		; Y position for Up/Down drawing section
marsGbl_Bg_YFbPos_D	ds.w 1
marsGbl_Bg_YFbPos_LR	ds.w 1		; Y position only for L/R draw
marsGbl_Bg_XbgInc_L	ds.w 1		; Address X increment
marsGbl_Bg_XbgInc_R	ds.w 1		;
marsGbl_Bg_YbgInc_D	ds.w 1		; Address Y increment (Multiply with BGWIDTH externally)
marsGbl_Bg_YbgInc_U	ds.w 1		;
marsGbl_Bg_DrwReqU	ds.w 1		; Draw UP request, write 2
marsGbl_Bg_DrwReqD	ds.w 1		; Draw DOWN request, write 2
marsGbl_Bg_DrwReqL	ds.w 1		; Draw LEFT request, write 2
marsGbl_Bg_DrwReqR	ds.w 1		; Draw RIGHT request, write 2
marsGbl_Bg_DrwReqFull	ds.w 1		; FULL Draw, write 2
; marsGbl_BgMd2_InitLtbl	ds.w 1		; Reset linetable, write 2
marsGbl_MdlFacesCntr	ds.w 1		; And the number of faces stored on that list
marsGbl_PlgnBuffNum	ds.w 1		; PolygonBuffer switch: READ/WRITE or WRITE/READ
marsGbl_MstrReqDraw	ds.w 1
marsGbl_CurrGfxMode	ds.w 1
marsGbl_PzListCntr	ds.w 1		; Number of graphic pieces to draw
marsGbl_DrwTask		ds.w 1		; Current Drawing task for Watchdog
marsGbl_DrwPause	ds.w 1		; Pause background drawing
marsGbl_VIntFlag_M	ds.w 1		; Sets to 0 if VBlank finished on Master CPU
marsGbl_VIntFlag_S	ds.w 1		; Same thing but for the Slave CPU
marsGbl_DivStop_M	ds.w 1		; Flag to tell Watchdog we are in the middle of hardware division
marsGbl_ZSortReq	ds.w 1		; Flag to request Zsort in Slave's watchdog
marsGbl_CurrFb		ds.w 1		; Current framebuffer number (byte)
marsGbl_PalDmaMidWr	ds.w 1		; Flag to tell we are in middle of transfering palette
marsGbl_FbMaxLines	ds.w 1		; Max lines to output to screen (MAX: 240 lines)
sizeof_MarsGbl		ds.l 0
			finish

; ====================================================================
; ----------------------------------------------------------------
; MASTER CPU HEADER (vbr)
; ----------------------------------------------------------------

		align 4
SH2_Master:
		dc.l SH2_M_Entry,CS3|$40000	; Cold PC,SP
		dc.l SH2_M_Entry,CS3|$40000	; Manual PC,SP

		dc.l SH2_Error_M		; Illegal instruction
		dc.l 0				; reserved
		dc.l SH2_Error_M		; Invalid slot instruction
		dc.l $20100400			; reserved
		dc.l $20100420			; reserved
		dc.l SH2_Error_M		; CPU address error
		dc.l SH2_Error_M		; DMA address error
		dc.l SH2_Error_M		; NMI vector
		dc.l SH2_Error_M		; User break vector

		dc.l 0,0,0,0,0,0,0,0,0,0	; reserved
		dc.l 0,0,0,0,0,0,0,0,0

		dc.l SH2_Error_M,SH2_Error_M	; Trap vectors
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M
		dc.l SH2_Error_M,SH2_Error_M

 		dc.l master_irq			; Level 1 IRQ
		dc.l master_irq			; Level 2 & 3 IRQ's
		dc.l master_irq			; Level 4 & 5 IRQ's
		dc.l master_irq			; PWM interupt
		dc.l master_irq			; Command interupt
		dc.l master_irq			; H Blank interupt
		dc.l master_irq			; V Blank interupt
		dc.l master_irq			; Reset Button
		dc.l master_irq			; (custom) Watchdog

; ====================================================================
; ----------------------------------------------------------------
; SLAVE CPU HEADER (vbr)
; ----------------------------------------------------------------

		align 4
SH2_Slave:
		dc.l SH2_S_Entry,CS3|$3F000	; Cold PC,SP
		dc.l SH2_S_Entry,CS3|$3F000	; Manual PC,SP

		dc.l SH2_Error_S		; Illegal instruction
		dc.l 0				; reserved
		dc.l SH2_Error_S		; Invalid slot instruction
		dc.l $20100400			; reserved
		dc.l $20100420			; reserved
		dc.l SH2_Error_S		; CPU address error
		dc.l SH2_Error_S		; DMA address error
		dc.l SH2_Error_S		; NMI vector
		dc.l SH2_Error_S		; User break vector

		dc.l 0,0,0,0,0,0,0,0,0,0	; reserved
		dc.l 0,0,0,0,0,0,0,0,0

		dc.l SH2_Error_S,SH2_Error_S	; Trap vectors
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S
		dc.l SH2_Error_S,SH2_Error_S

 		dc.l slave_irq			; Level 1 IRQ
		dc.l slave_irq			; Level 2 & 3 IRQ's
		dc.l slave_irq			; Level 4 & 5 IRQ's
		dc.l slave_irq			; PWM interupt
		dc.l slave_irq			; Command interupt
		dc.l slave_irq			; H Blank interupt
		dc.l slave_irq			; V Blank interupt
		dc.l slave_irq			; Reset Button
		dc.l slave_irq			; Watchdog

; ====================================================================
; ----------------------------------------------------------------
; irq
;
; r0-r1 are safe
; ----------------------------------------------------------------

		align 4
master_irq:
		mov.l	r0,@-r15
		mov.l	r1,@-r15
		sts.l	pr,@-r15

; 		mov	#_sysreg+comm12,r1
; 		stc	sr,r0
; 		and	#$0F,r0
; 		mov.b	r0,@r1

		stc	sr,r0
		shlr2	r0
		and	#$3C,r0
		mov	#int_m_list,r1
		add	r1,r0
		mov	@r0,r1
		jsr	@r1
		nop

		lds.l	@r15+,pr
		mov.l	@r15+,r1
		mov.l	@r15+,r0
		rte
		nop
		align 4
		ltorg

; ------------------------------------------------
; irq list
; ------------------------------------------------

		align 4
int_m_list:
		dc.l m_irq_bad,m_irq_bad
		dc.l m_irq_bad,m_irq_bad
		dc.l m_irq_bad,m_irq_custom	; Watchdog jump (Master)
		dc.l m_irq_pwm,m_irq_pwm
		dc.l m_irq_cmd,m_irq_cmd
		dc.l m_irq_h,m_irq_h
		dc.l m_irq_v,m_irq_v
		dc.l m_irq_vres,m_irq_vres

; ====================================================================
; ----------------------------------------------------------------
; irq
;
; r0-r1 are safe
; ----------------------------------------------------------------

slave_irq:
		mov.l	r0,@-r15
		mov.l	r1,@-r15
		sts.l	pr,@-r15

; 		mov	#_sysreg+comm12+1,r1
; 		stc	sr,r0
; 		and	#$0F,r0
; 		mov.b	r0,@r1

		stc	sr,r0
		shlr2	r0
		and	#$3C,r0
		mov	#int_s_list,r1
		add	r1,r0
		mov	@r0,r1
		jsr	@r1
		nop

		lds.l	@r15+,pr
		mov.l	@r15+,r1
		mov.l	@r15+,r0
		rte
		nop
		align 4

; ------------------------------------------------
; irq list
; ------------------------------------------------

int_s_list:
		dc.l s_irq_bad,s_irq_bad
		dc.l s_irq_bad,s_irq_bad
		dc.l s_irq_bad,s_irq_custom	; Watchdog jump (Slave)
		dc.l s_irq_pwm,s_irq_pwm
		dc.l s_irq_cmd,s_irq_cmd
		dc.l s_irq_h,s_irq_h
		dc.l s_irq_v,s_irq_v
		dc.l s_irq_vres,s_irq_vres
			
; ====================================================================
; ----------------------------------------------------------------
; Noraml error trap
; ----------------------------------------------------------------

SH2_Error_M:
		mov	#_sysreg+comm0,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		bra	SH2_Error_M
		nop
		align 4

SH2_Error_S:
		mov	#_sysreg+comm2,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		bra	SH2_Error_S
		nop
		align 4

; ====================================================================		
; ----------------------------------------------------------------
; MARS Interrupts
; ----------------------------------------------------------------

; =================================================================
; ------------------------------------------------
; Master | Unused interrupt
; ------------------------------------------------

m_irq_bad:
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | PWM Interrupt
; ------------------------------------------------

m_irq_pwm:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+pwmintclr,r1
		mov.w	r0,@r1
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | CMD Interrupt
; ------------------------------------------------

m_irq_cmd:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+cmdintclr,r1
		mov.w	r0,@r1
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4
		ltorg
		
; =================================================================
; ------------------------------------------------
; Master | HBlank
; ------------------------------------------------

m_irq_h:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+hintclr,r1
		mov.w	r0,@r1
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4
		
; =================================================================
; ------------------------------------------------
; Master | VBlank
; ------------------------------------------------

m_irq_v:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+vintclr,r1
		mov.w	r0,@r1

		mov	#_vdpreg,r1		; Wait for palette access
.wait_fb:	mov.w	@(vdpsts,r1),r0		; Read status as WORD
		tst	#2,r0			; Framebuffer busy? (wait for FEN=1)
		bf	.wait_fb
.wait		mov.b	@(vdpsts,r1),r0		; Now read as a BYTE
		tst	#$20,r0			; Palette unlocked? (wait for PEN=0)
		bt	.wait
		stc	sr,@-r15
		mov	r2,@-r15
		mov	r3,@-r15
		mov	r4,@-r15
		mov	r5,@-r15
		sts	macl,@-r15
		mov	#$F0,r0			; Disable interrupts
		ldc	r0,sr

	; Copy palette manually to SuperVDP
		mov	#1,r0
		mov.w	r0,@(marsGbl_PalDmaMidWr,gbr)
		mov	#RAM_Mars_Palette,r1
		mov	#_palette,r2
 		mov	#256/16,r3
.copy_pal:
	rept 16
		mov.w	@r1+,r0
		mov.w	r0,@r2
		add	#2,r2
	endm
		dt	r3
		bf	.copy_pal
		mov	#0,r0
		mov.w	r0,@(marsGbl_PalDmaMidWr,gbr)

        ; OLD method: doesn't work on hardware
; 		mov	r4,@-r15
; 		mov	r5,@-r15
; 		mov	r6,@-r15
; 		mov	#RAM_Mars_Palette,r1		; Send palette stored on RAM
; 		mov	#_palette,r2
;  		mov	#256,r3
; 		mov	#%0101011011110001,r4		; transfer size 2 / burst
; 		mov	#_DMASOURCE0,r5 		; _DMASOURCE = $ffffff80
; 		mov	#_DMAOPERATION,r6 		; _DMAOPERATION = $ffffffb0
; 		mov	r1,@r5				; set source address
; 		mov	r2,@(4,r5)			; set destination address
; 		mov	r3,@(8,r5)			; set length
; 		xor	r0,r0
; 		mov	r0,@r6				; Stop OPERATION
; 		xor	r0,r0
; 		mov	r0,@($C,r5)			; clear TE bit
; 		mov	r4,@($C,r5)			; load mode
; 		add	#1,r0
; 		mov	r0,@r6				; Start OPERATION
; 		mov	@r15+,r6
; 		mov	@r15+,r5
; 		mov	@r15+,r4

		lds	@r15+,macl
		mov	@r15+,r5
		mov	@r15+,r4
		mov	@r15+,r3
		mov	@r15+,r2
		ldc	@r15+,sr
.mid_pwrite:
		mov 	#0,r0				; Clear VintFlag for Master
		mov.w	r0,@(marsGbl_VIntFlag_M,gbr)
		rts
		nop
		align 4
		ltorg

; =================================================================
; ------------------------------------------------
; Master | VRES Interrupt (RESET on Genesis)
; ------------------------------------------------

; TODO: Breaks on many RESETs

m_irq_vres:
		mov.l	#_sysreg,r0
		ldc	r0,gbr
		mov.w	r0,@(vresintclr,gbr)	; V interrupt clear
		nop
		nop
		nop
		nop
		mov	#$F0,r0
		ldc	r0,sr
		mov.b	@(dreqctl,gbr),r0
		tst	#1,r0
		bf	.mars_reset
.md_reset:
		mov.l	#"68UP",r1		; wait for the 68K to show up
		mov.l	@(comm12,gbr),r0
		cmp/eq	r0,r1
		bf	.md_reset
.sh_wait:
		mov.l	#"S_OK",r1		; wait for the Slave CPU to show up
		mov.l	@(comm4,gbr),r0
		cmp/eq	r0,r1
		bf	.sh_wait
		mov.l	#"M_OK",r0		; let the others know master ready
		mov.l	r0,@(comm0,gbr)
		mov.l   #$FFFFFE80,r1		; Stop watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
; 		mov	#_vdpreg,r1		; Framebuffer swap request
; 		mov.b	@(framectl,r1),r0	; watchdog will check for it later
; 		xor	#1,r0
; 		mov.b	r0,@(framectl,r1)
; 		mov	#RAM_Mars_Global+marsGbl_CurrFb,r1
		mov.b	r0,@r1
		mov.l	#CS3|$40000-8,r15	; Set reset values
		mov.l	#SH2_M_HotStart,r0
		mov.l	r0,@r15
		mov.w	#$F0,r0
		mov.l	r0,@(4,r15)
		mov.l	#_DMAOPERATION,r1
		mov.l	#0,r0
		mov.l	r0,@r1			; Turn any DMA tasks OFF
		mov.l	#_DMACHANNEL0,r1
		mov.l	#0,r0
		mov.l	r0,@r1
		mov.l	#%0100010011100000,r1
		mov.l	r0,@r1			; Channel control
		rte
		nop
.mars_reset:
		mov	#_FRT,r1
		mov.b	@(_TOCR,r1),r0
		or	#$01,r0
		mov.b	r0,@(_TOCR,r1)
.vresloop:
		bra	.vresloop
		nop
		align 4
		ltorg				; Save MASTER IRQ literals here

; =================================================================
; ------------------------------------------------
; Unused
; ------------------------------------------------

s_irq_bad:
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | PWM Interrupt
; ------------------------------------------------

s_irq_pwm:
		mov	#_sysreg+monowidth,r1
		mov.b	@r1,r0
 		tst	#$80,r0
 		bf	.exit
		sts	pr,@-r15
		mov	#MarsSound_ReadPwm,r0
		jsr	@r0
		nop
		lds	@r15+,pr
.exit:		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+pwmintclr,r1
		mov.w	r0,@r1
		rts
		nop
		align 4

; 		mov	#_FRT,r1
; 		mov.b	@(7,r1),r0
; 		xor	#2,r0
; 		mov.b	r0,@(7,r1)
; 		mov	#_sysreg+pwmintclr,r1
; 		mov.w	r0,@r1
; 		nop
; 		nop
; 		nop
; 		nop
; 		nop
; 		rts
; 		nop
; 		align 4

; =================================================================
; ------------------------------------------------
; Slave | CMD Interrupt
; 
; Recieve data from Genesis using DREQ
; ------------------------------------------------

s_irq_cmd:
		stc	sr,@-r15
		mov	r2,@-r15
		mov	r3,@-r15
; 		mov	r4,@-r15

		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+cmdintclr,r1
		mov.w	r0,@r1
		mov.w	@r1,r0			; ???

; ----------------------------------

		mov	#$F0,r0			; Disable interrupts
		ldc	r0,sr
; 		mov	#_sysreg+comm15,r1	; comm15 at bit 6
; 		mov.b	@r1,r0			; Clear DMA signal for MD
; 		and	#%10111111,r0
; 		mov.b	r0,@r1
		mov	#RAM_Mars_DREQ,r1	; r1 - Output destination
		mov	#$20004010,r2		; r2 - DREQ length address
		mov	#_DMASOURCE0,r3		; r3 - DMA Channel 0
		mov	#0,r0
		mov	r0,@($30,r3)		; DMA Stop (_DMAOPERATION)
		mov	r0,@($C,r3)		; _DMACHANNEL0
		mov	#%0100010011100000,r0
		mov	r0,@($C,r3)
		mov	#$20004012,r0		; Source data (DREQ FIFO)
		mov	r0,@(0,r3)
		mov	r1,@(4,r3)
		mov.w	@r2,r0
		mov	r0,@(8,r3)
		mov	#%0100010011100001,r0
		mov	r0,@($C,r3)
		mov	#1,r0
		mov	r0,@($30,r3)		; DMA Start (_DMAOPERATION)
; 		mov	#_sysreg+comm15,r1	; comm15 at bit 6
; 		mov.b	@r1,r0			; Tell MD to push FIFO
; 		or	#%01000000,r0
; 		mov.b	r0,@r1

		mov	#_sysreg+comm4,r2	; DEBUG
		mov	#RAM_Mars_DREQ,r1
		mov	@r1,r0
		mov	r0,@r2

; 		mov 	@r15+,r4
		mov 	@r15+,r3
		mov 	@r15+,r2
		ldc 	@r15+,sr
		rts
		nop
		align 4
		ltorg
		
; =================================================================
; ------------------------------------------------
; Slave | HBlank
; ------------------------------------------------

s_irq_h:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+hintclr,r1
		mov.w	r0,@r1
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | VBlank
; ------------------------------------------------

s_irq_v:
		mov 	#0,r0				; Clear VintFlag for Slave
		mov.w	r0,@(marsGbl_VIntFlag_S,gbr)
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+vintclr,r1
		rts
		mov.w	r0,@r1
		align 4

; =================================================================
; ------------------------------------------------
; Slave | VRES Interrupt (Pressed RESET on Genesis)
; ------------------------------------------------

s_irq_vres:
		mov.l	#_sysreg,r0
		ldc	r0,gbr
		mov.w	r0,@(vresintclr,gbr)	; V interrupt clear
		nop
		nop
		nop
		nop
		mov	#$F0,r0
		ldc	r0,sr
		mov.b	@(dreqctl,gbr),r0
		tst	#1,r0
		bf	.mars_reset
.md_reset:
		mov.l	#"68UP",r1		; wait for the 68k to show up
		mov.l	@(comm12,gbr),r0
		cmp/eq	r0,r1
		bf	.md_reset
		mov.l	#"S_OK",r0		; tell the others slave is ready
		mov.l	r0,@(comm4,gbr)
.sh_wait:
		mov.l	#"M_OK",r1		; wait for the slave to show up
		mov.l	@(comm0,gbr),r0
		cmp/eq	r0,r1
		bf	.sh_wait
		mov.l	#CS3|$3F000-8,r15
		mov.l	#SH2_S_HotStart,r0
		mov.l	r0,@r15
		mov.w	#$F0,r0
		mov.l	r0,@(4,r15)
		mov.l	#_DMAOPERATION,r1
		mov.l	#0,r0
		mov.l	r0,@r1			; DMA off
		mov.l	#_DMACHANNEL0,r1
		mov.l	#0,r0
		mov.l	r0,@r1
		mov.l	#%0100010011100000,r1
		mov.l	r0,@r1			; Channel control
		rte
		nop
.mars_reset:
		mov	#_FRT,r1
		mov.b	@(_TOCR,r1),r0
		or	#$01,r0
		mov.b	r0,@(_TOCR,r1)
.vresloop:
		bra	.vresloop
		nop
		align 4
		ltorg			; Save Slave IRQ literals

; ====================================================================
; ----------------------------------------------------------------
; MARS System features
; ----------------------------------------------------------------

		include "system/mars/video.asm"
		include "system/mars/sound.asm"
		align 4

; ====================================================================
; ----------------------------------------------------------------
; Master entry
; ----------------------------------------------------------------

		align 4
SH2_M_Entry:
		mov	#CS3|$40000,r15			; Set default Stack for Master
		mov	#_FRT,r1
		mov     #0,r0
		mov.b   r0,@(0,r1)
		mov     #$FFFFFFE2,r0
		mov.b   r0,@(7,r1)
		mov     #0,r0
		mov.b   r0,@(4,r1)
		mov     #1,r0
		mov.b   r0,@(5,r1)
		mov     #0,r0
		mov.b   r0,@(6,r1)
		mov     #1,r0
		mov.b   r0,@(1,r1)
		mov     #0,r0
		mov.b   r0,@(3,r1)
		mov.b   r0,@(2,r1)
		mov	#$FFFFFEE2,r0			; Watchdog: Set interrupt priority bits (IPRA)
		mov     #%0101<<4,r1
		mov.w   r1,@r0
		mov	#$FFFFFEE4,r0
		mov     #(($120/4)<<8),r1		; Watchdog: Set jump pointer ((VBR + this/4)<<8) (WITV)
		mov.w   r1,@r0

; ------------------------------------------------
; Wait for Genesis and Slave CPU
; ------------------------------------------------

.wait_md:
		mov 	#_sysreg+comm0,r2		; Wait for Genesis
		mov.l	@r2,r0
		cmp/eq	#0,r0
		bf	.wait_md
		mov.l	#"SLAV",r1
.wait_slave:
		mov.l	@(8,r2),r0			; Wait for Slave CPU to finish booting
		cmp/eq	r1,r0
		bf	.wait_slave
		mov	#0,r0				; clear "SLAV"
		mov	r0,@(8,r2)
		mov	r0,@r2

; ====================================================================
; ----------------------------------------------------------------
; Master main code
; 
; This CPU is exclusively used for visual tasks:
; Polygons, Sprites, Backgrounds...
;
; To interact with the models use the Slave CPU and request
; a drawing task there
; ----------------------------------------------------------------

SH2_M_HotStart:
		mov	#CS3|$40000,r15			; Stack again if coming from RESET
		mov	#RAM_Mars_Global,r14		; GBR - Global values/variables go here.
		ldc	r14,gbr
		mov	#$F0,r0				; Interrupts OFF
		ldc	r0,sr
		mov.l	#_CCR,r1
		mov	#%00001000,r0			; Cache OFF
		mov.w	r0,@r1
		mov	#%00011001,r0			; Cache purge / Two-way mode / Cache ON
		mov.w	r0,@r1
		mov	#_sysreg,r1
		mov	#0,r0			; Enable usage of these interrupts
    		mov.b	r0,@(intmask,r1)		; (Watchdog is external)
; 		mov 	#CACHE_MASTER,r1		; Transfer Master's fast-code to CACHE
; 		mov 	#$C0000000,r2
; 		mov 	#(CACHE_MASTER_E-CACHE_MASTER)/4,r3
; .copy:
; 		mov 	@r1+,r0
; 		mov 	r0,@r2
; 		add 	#4,r2
; 		dt	r3
; 		bf	.copy
		mov	#MarsVideo_Init,r0		; Init Video
		jsr	@r0
		nop

		mov	#"GO",r2
		mov	#_sysreg+comm12,r1
.lel:		mov.w	@r1,r0
		cmp/eq	r2,r0
		bf	.lel
		mov.l   #$FFFFFE80,r1		; Disable watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		mov.l	#$20,r0				; HW Interrupts ON
		ldc	r0,sr

; --------------------------------------------------------
; MASTER Loop
; --------------------------------------------------------

master_loop:
		mov	#_sysreg+comm8,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		mov	#_sysreg+comm14,r2
		mov.b	@r2,r0
		and	#$FF,r0
		cmp/eq	#0,r0
		bt	master_loop
		mov	#_sysreg+comm12,r3
		mov.b	r0,@r3
		mov	#.list,r1
		shll2	r0
		mov	@(r1,r0),r1
		mov	#0,r0
		mov.b	r0,@r2
		jmp	@r1
		nop
		align 4
.list:
		dc.l master_loop
		dc.l mtest_1
		dc.l mtest_2
		dc.l mtest_3
		dc.l mtest_4
		dc.l mtest_5
		dc.l master_loop
		dc.l master_loop
		align 4

; ------------------------------------------------
; Master tests
; ------------------------------------------------

mtest_1:
		mov	#$FFFFFE80,r1
		mov.w	#$5A10,r0		; Watchdog pre-start timer
		mov.w	r0,@r1
		mov.w	#$A518|$20,r0		; Enable it
		mov.w	r0,@r1
		bra	master_loop
		nop
		align 4

mtest_2:
		mov.l	#_sysreg+comm4,r1
		xor	r0,r0
		mov.w	r0,@r1
		mov.l   #$FFFFFE80,r1		; Disable watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		bra	master_loop
		nop
		align 4

mtest_3:
		mov	#$55AA55AA,r3
		mov	#_sysreg+comm0,r2
		mov	#1,r0			; $0001 - Testing LONG
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNMSTR+1,r1
		mov	r3,@r1
		mov	#2,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNMSTR+2,r1
		mov	r3,@r1
		mov	#3,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNMSTR+3,r1
		mov	r3,@r1
		mov	#4,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNMSTR+1,r1
		mov.w	r3,@r1
		mov	#0,r0
		mov.w	r0,@r2
		bra	master_loop
		nop
		align 4

TEST_WRITE_ALGNMSTR:
		dc.l 0,0
		align 4

mtest_4:
		mov	#_sysreg+comm0,r1
		mov	#_sysreg+comm8,r2
.wait:		mov.w	@r1,r0
		cmp/pl	r0
		bf	.wait
.next:		mov.w	@r1,r0
		cmp/pl	r0
		bf	.exit
		mov.w	r0,@r2
		bra	.next
		nop
.exit:
		xor	r0,r0
		mov.w	r0,@r2
		bra	master_loop
		nop
		align 4

mtest_5:
		mov	#$55AA55AA,r3
		mov	#_sysreg+comm0,r1
		mov	#TEST_WRITE_ALGNMSTR,r2

		mov	#1,r0
		mov.w	r0,@r1
		bsr	.branch
		mov	r3,@r2
		mov	#2,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r0,@(2,r2)

		mov	#_vdpreg+shift,r2	; direct
		mov	#3,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r3,@r2
		mov	#_vdpreg,r2		; indexed
		mov	#4,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r0,@(shift,r2) 		; r0...

		mov	#0,r0
		mov.w	r0,@r1
		bra	master_loop
		nop
		align 4

.branch:
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		rts
		nop
		align 4

; 		mov	#$12345678,r5		; Test value
; 		mov	#TEST_WRITE_DUAL,r1
; 		mov	#_sysreg+comm0,r2
; 		mov	#$70000,r3
; 		mov	r3,r4
; .test_1:
; 		mov.l	r5,@r1			; .l .w .b
; 		mov.l	@r1,r0
; 		mov.w	r4,@r2
; 		dt	r4
; 		bf	.test_1
; 		mov	r3,r4
; .test_2:
; 		mov.w	r5,@r1
; 		mov.w	@r1,r0
; 		mov.w	r4,@r2
; 		dt	r4
; 		bf	.test_2
; 		mov	r3,r4
; .test_3:
; 		mov.b	r5,@r1
; 		mov.b	@r1,r0
; 		mov.w	r4,@r2
; 		dt	r4
; 		bf	.test_3
; 		mov	#0,r0
; 		mov.w	r0,@r2
		bra	master_loop
		nop
		align 4

; 		mov	#_sysreg+comm0,r1
; 		mov.w	@r1,r0
; 		add	#1,r0
; 		mov.w	r0,@r1
;
; ; 		mov	#_CCR,r3			; <-- Required for Watchdog
; ; 		mov	#%00001000,r0			; Two-way mode
; ; 		mov.w	r0,@r3
; ; 		mov	#%00011001,r0			; Cache purge / Two-way mode / Cache ON
; ; 		mov.w	r0,@r3
; ; 		mov	#MarsVideo_SetWatchdog,r0
; ; 		jsr	@r0
; ; 		nop
; ; .wait_task:	mov.w	@(marsGbl_DrwTask,gbr),r0	; Any drawing task active?
; ; 		cmp/eq	#0,r0
; ; 		bf	.wait_task
; ; 		mov.l   #$FFFFFE80,r1			; Stop watchdog
; ; 		mov.w   #$A518,r0
; ; 		mov.w   r0,@r1
; 		bra	master_loop
; 		nop
		align 4
		ltorg

; =================================================================
; ------------------------------------------------
; Slave | Watchdog interrupt
; ------------------------------------------------

m_irq_custom:
		mov	#_FRT,r1	; FREERUN timer patch
		mov.b   @(7,r1),r0
		xor     #2,r0
		mov.b   r0,@(7,r1)

		mov	#_sysreg+comm4,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1

	; Emus ignore this:
		mov.l   #$FFFFFE80,r1
		mov.w   #$A518,r0		; Turn OFF
		mov.w   r0,@r1
		or      #$20,r0			; And turn ON again...
		mov.w   r0,@r1
		mov.w   #$5A10,r0		; New timer before coming
		mov.w   r0,@r1			; back again
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Slave entry
; ----------------------------------------------------------------

		align 4
SH2_S_Entry:
		mov.l	#CS3|$3F000,r15			; Reset stack
		mov	#_FRT,r1
		mov     #0,r0
		mov.b   r0,@(0,r1)
		mov     #$FFFFFFE2,r0
		mov.b   r0,@(7,r1)
		mov     #0,r0
		mov.b   r0,@(4,r1)
		mov     #1,r0
		mov.b   r0,@(5,r1)
		mov     #0,r0
		mov.b   r0,@(6,r1)
		mov     #1,r0
		mov.b   r0,@(1,r1)
		mov     #0,r0
		mov.b   r0,@(3,r1)
		mov.b   r0,@(2,r1)
		mov	#$FFFFFEE2,r0			; Watchdog: Set interrupt priority bits (IPRA)
		mov     #%0101<<4,r1
		mov.w   r1,@r0
		mov	#$FFFFFEE4,r0
		mov     #(($120/4)<<8),r1		; Watchdog: Set jump pointer ((VBR + this/4)<<8) (WITV)
		mov.w   r1,@r0
		
; ------------------------------------------------
; Wait for Genesis, report to Master SH2
; ------------------------------------------------

.wait_md:
		mov 	#_sysreg+comm0,r2
		mov.l	@r2,r0
		cmp/eq	#0,r0
		bf	.wait_md
		mov.l	#"SLAV",r0
		mov.l	r0,@(8,r2)

; ====================================================================
; ----------------------------------------------------------------
; Slave main code
; ----------------------------------------------------------------

SH2_S_HotStart:
		mov.l	#CS3|$3F000,r15			; Reset stack
		mov.l	#RAM_Mars_Global,r14		; Reset gbr
		ldc	r14,gbr
		mov.l	#$F0,r0				; Interrupts OFF
		ldc	r0,sr
		mov.l	#_CCR,r1
		mov	#%00001000,r0			; Cache OFF
		mov.w	r0,@r1
		mov	#%00011001,r0			; Cache purge / Two-way mode / Cache ON
		mov.w	r0,@r1
		mov	#_sysreg,r1
		mov	#0,r0				; Enable these interrupts
    		mov.b	r0,@(intmask,r1)		; (Watchdog is external)
		mov 	#CACHE_SLAVE,r1			; Transfer Slave's fast-code to CACHE
		mov 	#$C0000000,r2
		mov 	#(CACHE_SLAVE_E-CACHE_SLAVE)/4,r3
.copy:
		mov 	@r1+,r0
		mov 	r0,@r2
		add 	#4,r2
		dt	r3
		bf	.copy
		bsr	MarsSound_Init			; Init Sound
		nop


; --------------------------------------------------------
; Loop
; --------------------------------------------------------

		mov	#"GO",r2
		mov	#_sysreg+comm12,r1
.lel:		mov.w	@r1,r0
		cmp/eq	r2,r0
		bf	.lel
		mov.l   #$FFFFFE80,r1		; Disable watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		mov.l	#$20,r0				; Interrupts ON
		ldc	r0,sr

slave_loop:
		mov	#_sysreg+comm10,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		mov	#_sysreg+comm15,r2
		mov.b	@r2,r0
		and	#$FF,r0
		cmp/eq	#0,r0
		bt	slave_loop
		mov	#_sysreg+comm12+1,r3
		mov.b	r0,@r3
		mov	#.list,r1
		shll2	r0
		mov	@(r1,r0),r1
		mov	#0,r0
		mov.b	r0,@r2
		jmp	@r1
		nop
		align 4
.list:
		dc.l slave_loop
		dc.l stest_1
		dc.l stest_2
		dc.l stest_3
		dc.l stest_4
		dc.l stest_5
		dc.l slave_loop
		dc.l slave_loop
		align 4

; ------------------------------------------------
; Slave tests
; ------------------------------------------------

stest_1:
		mov	#$FFFFFE80,r1
		mov.w	#$5A10,r0		; Watchdog pre-start timer
		mov.w	r0,@r1
		mov.w	#$A518|$20,r0		; Enable it
		mov.w	r0,@r1
		bra	slave_loop
		nop
		align 4
stest_2:
		mov.l	#_sysreg+comm6,r1
		xor	r0,r0
		mov.w	r0,@r1
		mov.l   #$FFFFFE80,r1		; Disable watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		bra	slave_loop
		nop
		align 4

stest_3:
		mov	#$55AA55AA,r3
		mov	#_sysreg+comm2,r2
		mov	#1,r0			; $0001 - Testing LONG
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNSLV+1,r1
		mov	r3,@r1
		mov	#2,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNSLV+2,r1
		mov	r3,@r1
		mov	#3,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNSLV+3,r1
		mov	r3,@r1
		mov	#4,r0
		mov.w	r0,@r2
		mov	#TEST_WRITE_ALGNSLV+1,r1
		mov.w	r3,@r1
		mov	#0,r0
		mov.w	r0,@r2
		bra	slave_loop
		nop
		align 4

stest_4:
		mov	#_sysreg+comm0,r1
		mov	#_sysreg+comm10,r2
.wait:		mov.w	@r1,r0
		cmp/pl	r0
		bf	.wait
.next:		mov.w	@r1,r0
		cmp/pl	r0
		bf	.exit
		mov.w	r0,@r2
		bra	.next
		nop
.exit:
		xor	r0,r0
		mov.w	r0,@r2
		bra	slave_loop
		nop
		align 4

stest_5:
		mov	#$55AA55AA,r3
		mov	#_sysreg+comm2,r1
		mov	#TEST_WRITE_ALGNSLV,r2

		mov	#1,r0
		mov.w	r0,@r1
		bsr	.branch
		mov	r3,@r2
		mov	#2,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r0,@(2,r2)

		mov	#_vdpreg+shift,r2	; direct
		mov	#3,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r3,@r2
		mov	#_vdpreg,r2		; indexed
		mov	#4,r0
		mov.w	r0,@r1
		bsr	.branch
		mov.w	r0,@(shift,r2) 		; r0...

		mov	#0,r0
		mov.w	r0,@r1
		bra	slave_loop
		nop
		align 4

.branch:
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1
		rts
		nop
		align 4


TEST_WRITE_DUAL:
		dc.l 0
TEST_WRITE_ALGNSLV:
		dc.l 0,0
		align 4

		ltorg

; =================================================================
; ------------------------------------------------
; Slave | Watchdog interrupt
; ------------------------------------------------

s_irq_custom:
		mov	#_FRT,r1	; FREERUN timer patch
		mov.b   @(7,r1),r0
		xor     #2,r0
		mov.b   r0,@(7,r1)

		mov	#_sysreg+comm6,r1
		mov.w	@r1,r0
		add	#1,r0
		mov.w	r0,@r1

	; Emus ignore this:
		mov.l   #$FFFFFE80,r1
		mov.w   #$A518,r0		; Turn OFF
		mov.w   r0,@r1
		or      #$20,r0			; And turn ON again...
		mov.w   r0,@r1
		mov.w   #$5A10,r0		; New timer before coming
		mov.w   r0,@r1			; back again
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Cache routines
; ----------------------------------------------------------------

		include "system/mars/cache.asm"
		
; ====================================================================
; ----------------------------------------------------------------
; Data
; ----------------------------------------------------------------

		align 4
sin_table	binclude "system/mars/data/sinedata.bin"
		align 4
		include "data/mars_sdram.asm"

; ====================================================================
; ----------------------------------------------------------------
; MARS SH2 RAM
; ----------------------------------------------------------------

		align $10
SH2_RAM:
		struct SH2_RAM
	if MOMPASS=1
MarsRam_System	ds.l 0
MarsRam_Video	ds.l 0
MarsRam_Sound	ds.l 0
sizeof_marsram	ds.l 0
	else
MarsRam_System	ds.b (sizeof_marssys-MarsRam_System)
MarsRam_Video	ds.b (sizeof_marsvid-MarsRam_Video)
MarsRam_Sound	ds.b (sizeof_marssnd-MarsRam_Sound)
sizeof_marsram	ds.l 0
	endif

.here:
	if MOMPASS=6
		message "MARS RAM from \{((SH2_RAM)&$FFFFFF)} to \{((.here)&$FFFFFF)}"
	endif
		finish

; ====================================================================
; ----------------------------------------------------------------
; MARS Sound RAM
; ----------------------------------------------------------------

			struct MarsRam_Sound
MarsSnd_PwmChnls	ds.b sizeof_sndchn*MAX_PWMCHNL
; MarsSnd_PwmTrkData	ds.b $80*2
MarsSnd_PwmPlyData	ds.l 7
sizeof_marssnd		ds.l 0
			finish

; ====================================================================
; ----------------------------------------------------------------
; MARS Video RAM
; ----------------------------------------------------------------

			struct MarsRam_Video
RAM_Mars_Linescroll	ds.l 240			; Each lines' framebuffer position
RAM_Mars_Palette	ds.w 256			; Indexed palette
RAM_Mars_DREQ		ds.w 256			; 256 WORDS of MD communication
RAM_Mars_ObjCamera	ds.b sizeof_camera		; Camera buffer
RAM_Mars_ObjLayout	ds.b sizeof_layout		; Layout buffer
; RAM_Mars_Objects	ds.b sizeof_mdlobj*MAX_MODELS	; Objects list
RAM_Mars_Polygons_0	ds.b sizeof_polygn*MAX_MPLGN	; Polygon list 0
RAM_Mars_Polygons_1	ds.b sizeof_polygn*MAX_MPLGN	; Polygon list 1
RAM_Mars_VdpDrwList	ds.b sizeof_plypz*MAX_SVDP_PZ	; Pieces list
RAM_Mars_VdpDrwList_e	ds.l 0				; (end-of-list label)
RAM_Mars_Plgn_ZList_0	ds.l MAX_MPLGN*2		; Z value / foward faces
RAM_Mars_Plgn_ZList_1	ds.l MAX_MPLGN*2		; Z value / foward faces
RAM_Mars_PlgnNum_0	ds.w 1				; Number of polygons to read, both buffers
RAM_Mars_PlgnNum_1	ds.w 1				;
sizeof_marsvid		ds.l 0
			finish

; ====================================================================
; ----------------------------------------------------------------
; MARS System RAM
; ----------------------------------------------------------------

			struct MarsRam_System
RAM_Mars_Global		ds.w sizeof_MarsGbl		; keep it as a word
sizeof_marssys		ds.l 0
			finish
