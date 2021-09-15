; ====================================================================
; ----------------------------------------------------------------
; Default gamemode
; ----------------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Variables
; ------------------------------------------------------

var_MoveSpd	equ	$4000

; ====================================================================
; ------------------------------------------------------
; Structs
; ------------------------------------------------------

; 		struct 0
; strc_xpos	ds.w 1
; strc_ypos	ds.w 1
; 		finish

; ====================================================================
; ------------------------------------------------------
; This mode's RAM
; ------------------------------------------------------

		struct RAM_ModeBuff
; RAM_MarsPal	ds.w 256
; RAM_MarsFade	ds.w 256
; RAM_Cam_Xpos	ds.l 1
; RAM_Cam_Ypos	ds.l 1
; RAM_Cam_Zpos	ds.l 1
; RAM_Cam_Xrot	ds.l 1
; RAM_Cam_Yrot	ds.l 1
; RAM_Cam_Zrot	ds.l 1
; RAM_CamData	ds.l 1
; RAM_CamFrame	ds.l 1
; RAM_CamTimer	ds.l 1
; RAM_CamSpeed	ds.l 1
RAM_MdlCurrMd	ds.w 1
RAM_BgCamera	ds.w 1
RAM_BgCamCurr	ds.w 1
; RAM_Layout_X	ds.w 1
; RAM_Layout_Y	ds.w 1
RAM_Cursor	ds.l 1
sizeof_mdglbl	ds.l 0
		finish

; ====================================================================
; ------------------------------------------------------
; Code start
; ------------------------------------------------------

thisCode_Top:
		move.w	#$2700,sr
		bsr	Mode_Init
		bsr	Video_PrintInit
		move.w	#0,(RAM_MdlCurrMd).w
		bset	#bitDispEnbl,(RAM_VdpRegs+1).l		; Enable display
		bsr	Video_Update
		move.w	#"GO",(sysmars_reg+comm12)

; ====================================================================
; ------------------------------------------------------
; Loop
; ------------------------------------------------------

.loop:
		move.w	(vdp_ctrl),d4
		btst	#bitVint,d4
		beq.s	.loop
		bsr	System_Input
		add.l	#1,(RAM_Framecount).l
; 		bsr	MD_FifoMars
.inside:	move.w	(vdp_ctrl),d4
		btst	#bitVint,d4
		bne.s	.inside

		move.l	#$7C000003,(vdp_ctrl).l
		move.w	(RAM_BgCamCurr).l,d0
		neg.w	d0
		asr.w	#2,d0
		move.w	d0,(vdp_data).l
		asr.w	#1,d0
		move.w	d0,(vdp_data).l
		lea	str_Status(pc),a0
		move.l	#locate(0,2,2),d0
		bsr	Video_Print
		move.w	(RAM_MdlCurrMd).w,d0
		and.w	#%11111,d0
		add.w	d0,d0
		add.w	d0,d0
		jsr	.list(pc,d0.w)
		bra	.loop

; ====================================================================
; ------------------------------------------------------
; Mode sections
; ------------------------------------------------------

.list:
		bra.w	.mode0
		bra.w	.mode0
		bra.w	.mode0

; --------------------------------------------------
; Mode 0
; --------------------------------------------------

.mode0:
		tst.w	(RAM_MdlCurrMd).w
		bmi	.mode0_loop
		or.w	#$8000,(RAM_MdlCurrMd).w
		lea	str_Menu(pc),a0
		move.l	#locate(0,2,6),d0
		bsr	Video_Print

; Mode 0 mainloop
.mode0_loop:
		move.w	(Controller_1+on_press),d7
		move.l	(RAM_Cursor).w,d6
		btst	#bitJoyUp,d7
		beq.s	.n_u
		tst.b	d6
		beq.s	.n_u
		sub.b	#1,d6
.n_u:
		btst	#bitJoyDown,d7
		beq.s	.n_d
		cmp.b	#6-1,d6
		beq.s	.n_d
		add.b	#1,d6
.n_d:
		move.l	d6,(RAM_Cursor).w

		btst	#bitJoyC,d7
		beq.s	.n_st
		move.w	d6,d5
		and.w	#$FF,d5
		add	#1,d5
; 		move.b	d5,d4
; 		lsl.w	#8,d4
; 		or.w	d4,d5
		move.b	d5,(sysmars_reg+comm14).l
; .wait:
; 		move.b	(sysmars_reg+comm14).l,d5
; 		tst.b	d5
; 		bne.s	.wait
		move.b	d5,(sysmars_reg+comm15).l
; .wait2:		move.b	(sysmars_reg+comm15).l,d5
; 		tst.b	d5
; 		bne.s	.wait2

.n_st:

		lea	str_Cursor(pc),a0
		move.l	(RAM_Cursor).w,d0
		add.l	#$0207,d0
		bsr	Video_Print

; 		move.w	(sysmars_reg+comm10).l,d4
; 		add.w	#1,d4
; 		move.w	d4,(sysmars_reg+comm10).l
		rts

; ====================================================================
; ------------------------------------------------------
; Subroutines
; ------------------------------------------------------

MD_FifoMars:
		lea	(RAM_FrameCount),a6
		move.w	#$100,d6

		lea	(sysmars_reg),a5
		move.w	sr,d7			; Backup current SR
		move.w	#$2700,sr		; Disable interrupts
		move.w	#$00E,d5
.retry:
		move.l	#$C0000000,(vdp_ctrl).l	; DEBUG ENTER
		move.w	d5,(vdp_data).l
		move.b	#%000,($A15107).l	; 68S bit
		move.w	d6,($A15110).l		; DREQ len
		move.b	#%100,($A15107).l	; 68S bit
		lea	($A15112).l,a4
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		move.w	standby(a5),d0		; Request SLAVE CMD interrupt
		bset	#1,d0
		move.w	d0,standby(a5)
.wait_cmd:	move.w	standby(a5),d0		; interrupt is ready?
		btst    #1,d0
		bne.s   .wait_cmd
; .wait_dma:	move.b	comm15(a5),d0		; Another flag to check
; 		btst	#6,d0
; 		beq.s	.wait_dma
; 		move.b	#1,d0
; 		move.b	d0,comm15(a5)

; 	; blast
; 	rept $200/128
; 		bsr.s	.blast
; 	endm
; 		move.l	#$C0000000,(vdp_ctrl).l	; DEBUG EXIT
; 		move.w	#$000,(vdp_data).l
; 		move.w	d7,sr			; Restore SR
; 		rts
; .blast:
; 	rept 128
; 		move.w	(a6)+,(a4)
; 	endm
; 		rts

; 	safer
.l0:		move.w	(a6)+,(a4)		; Data Transfer
		move.w	(a6)+,(a4)		;
		move.w	(a6)+,(a4)		;
		move.w	(a6)+,(a4)		;
.l1:		btst	#7,dreqctl+1(a5)	; FIFO Full ?
		bne.s	.l1
		subq	#4,d6
		bcc.s	.l0
		move.w	#$E00,d5
		btst	#2,dreqctl(a5)		; DMA All OK ?
		bne.s	.retry
		move.l	#$C0000000,(vdp_ctrl).l	; DEBUG EXIT
		move.w	#$000,(vdp_data).l
		move.w	d7,sr			; Restore SR
		rts

; ====================================================================
; ------------------------------------------------------
; VBlank
; ------------------------------------------------------

; ------------------------------------------------------
; HBlank
; ------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; DATA
;
; Small stuff goes here
; ------------------------------------------------------

str_Status:
		dc.b "\\w \\w \\w \\w",$A
		dc.b "\\w \\w \\w \\w",0
		dc.l sysmars_reg+comm0
		dc.l sysmars_reg+comm2
		dc.l sysmars_reg+comm4
		dc.l sysmars_reg+comm6
		dc.l sysmars_reg+comm8
		dc.l sysmars_reg+comm10
		dc.l sysmars_reg+comm12
		dc.l sysmars_reg+comm14

		align 2

str_Menu:	dc.b "32X Hardware behavior tester",$A,$A
		dc.b "  Enable Watchdog interrupt(s)",$A
		dc.b "  Disable Watchdog interrupt(s)",$A
		dc.b "  SH2 Misaligned WORD/LONG crash",$A
		dc.b "  SH2 Dual-write/read crash (???)",$A
		dc.b "  SH2 Delayed jump/call crash (???)",$A
		dc.b "  PWM $3FF sound limit",$A
; 		dc.b "  ???",$A
; 		dc.b $A
; 		dc.b "  ???",$A
; 		dc.b $A
; 		dc.b "  ???",$A
		dc.b 0
		align 2

str_Cursor:	dc.b " ",$A
		dc.b ">",$A
		dc.b " ",0
		align 2

; ====================================================================

	if MOMPASS=6
.end:
		message "This 68K RAM-CODE uses: \{.end-thisCode_Top}"
	endif
