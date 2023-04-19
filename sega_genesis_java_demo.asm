.68000
ram_start equ 0xff0000
  TMSS_REG equ 0xa14000
  HW_VERSION equ 0xa10001
  VDP_DATA equ 0xc00000
  VDP_CTRL equ 0xc00004
  Z80_RAM equ 0xa00000
  Z80_BUSREQ equ 0xa11100
  Z80_RESET equ 0xa11200

  ;-------------------------------:
  ; exception vectors
  ;-------------------------------:

  dc32 0x00000000   ; startup SP
  dc32 start        ; startup PC
  dc32 interrupt    ; bus
  dc32 interrupt    ; addr
  dc32 interrupt    ; illegal
  dc32 interrupt    ; divzero
  dc32 interrupt    ; CHK
  dc32 interrupt    ; TRAPV
  dc32 interrupt    ; priv
  dc32 interrupt    ; trace
  dc32 interrupt    ; line 1010 emulator
  dc32 interrupt    ; line 1111 emulator
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt
  dc32 interrupt    ; spurious interrupt
  dc32 interrupt    ; interrupt level 1 (lowest priority)
  dc32 extint       ; interrupt level 2 = external interrupt
  dc32 interrupt    ; interrupt level 3
  dc32 hsync        ; interrupt level 4 = H-sync interrupt
  dc32 interrupt    ; interrupt level 5
  dc32 vsync        ; interrupt level 6 = V-sync interrupt
  dc32 interrupt    ; interrupt level 7 (highest priority)
  dc32 interrupt    ; TRAP #00 exception
  dc32 interrupt    ; TRAP #01 exception
  dc32 interrupt    ; TRAP #02 exception
  dc32 interrupt    ; TRAP #03 exception
  dc32 interrupt    ; TRAP #04 exception
  dc32 interrupt    ; TRAP #05 exception
  dc32 interrupt    ; TRAP #06 exception
  dc32 interrupt    ; TRAP #07 exception
  dc32 interrupt    ; TRAP #08 exception
  dc32 interrupt    ; TRAP #09 exception
  dc32 interrupt    ; TRAP #10 exception
  dc32 interrupt    ; TRAP #11 exception
  dc32 interrupt    ; TRAP #12 exception
  dc32 interrupt    ; TRAP #13 exception
  dc32 interrupt    ; TRAP #14 exception
  dc32 interrupt    ; TRAP #15 exception
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)
  dc32 interrupt    ; Unused (reserved)

  ;-------------------------------:
  ; cartridge info header
  ;-------------------------------:

  dc.b "SEGA GENESIS    "  ; must start with "SEGA"
  dc.b "(C)---- "          ; copyright
  dc.b "2015.MAY"          ; date
  dc.b "JAVA GRINDER                                    " ; cart name
  dc.b "JAVA GRINDER                                    " ; cart name (alt. language)
  dc.b "GM MK-0000 -00"    ; program type / catalog number
  dc.w 0x0000                ; ROM checksum
  dc.b "J               "  ; hardware used
  dc32 0x00000000            ; start of ROM
  dc32 0x003fffff            ; end of ROM
  dc32 0x00ff0000,0x00ffffff ; RAM start/end
  dc.b "            "      ; backup RAM info
  dc.b "            "      ; modem info
  dc.b "                                        " ; comment
  dc.b "JUE             "  ; regions allowed

  ;-------------------------------:
  ; exception handlers
  ;-------------------------------:

extint:
hsync:
vsync:
interrupt:
  rte

ImageJavaGrinder_image equ ram_start+0
ImageJavaGrinder_palette equ ram_start+4
ImageJavaGrinder_pattern equ ram_start+8
start:
  movea.l #0x0, SP

  ; Setup registers used to talk to VDP
  movea.l #VDP_DATA, a0
  movea.l #VDP_CTRL, a1

  ; During initialization:
  ; d0 = 0
  ; d1 = data movement
  ; d2 = counter
  eor.l d0, d0

  ; Initialize TMSS
  movea.l #HW_VERSION, a2
  movea.l #TMSS_REG, a3
  move.b (a2), d1           ; A10001 test the hardware version
  andi.b #0x0f, d1
  beq.b start_init_tmss     ; branch if no TMSS
  move.l #0x53454741, (a3)  ; A14000 disable TMSS
start_init_tmss:
  move.w (a1), d1    ; C00004 read VDP status (interrupt acknowledge?)

  ; Initialize video
  movea.l #vdp_reg_init_table, a2
  move.w #0x8000, d1
  moveq #24-1, d2   ; length of video initialization block
start_video_init:
  move.b (a2)+, d1  ; get next video control byte
  move.w d1, (a1)   ; C00004 send write register command to VDP
  add.w #0x100, d1  ; point to next VDP register
  dbra d2, start_video_init  ; loop for rest of block

  ; DMA is now set up for 65535-byte fill of VRAM
  move.l #0x40000080, (a1)  ; C00004 = VRAM write to 0x0000
  move.w d0, (a0)      ; C00000 = write zero to VRAM (starts DMA fill)
  ; Wait on busy VDP
start_wait_dma:
  move.w (a1), d1      ; C00004 read VDP status
  btst #1, d1        ; test DMA busy flag
  bne.s start_wait_dma ; loop while DMA busy

  ; initialize CRAM
  move.l #0x81048f02, (a1) ; C00004 reg 1 = 0x04, reg 15 = 0x02: blank, auto-increment=2
  move.l #0xc0000000, (a1) ; C00004 write CRAM address 0x0000
  moveq #32-1, d2          ; loop for 32 CRAM registers
start_init_cram:
  move.l d0, (a0)          ; C00000 clear CRAM register
  dbra d2, start_init_cram

  ; Initialize VSRAM
  move.l #0x40000010, (a1) ; C00004 VSRAM write address 0x0000
  moveq #20-1, d2          ; loop for 20 VSRAM registers
start_init_vsram:
  move.l d0, (a0)          ; C00000 clear VSRAM register
  dbra d2, start_init_vsram

  ; Initialize PSG
  moveq #4-1, d2             ; loop for 4 PSG registers
  movea.l #psg_reg_init_table, a2
start_init_psg:
  move.b (a2)+, (0x0011, a0) ; C00011 copy PSG initialization commands
  dbra d2, start_init_psg

  ; Unblank display
  move.w #0x8144, (a1)   ; C00004 reg 1 = 0x44 unblank display

  ;; Setup heap and static initializers
  movea.l #ram_start+12, a5
  move.l #_ImageJavaGrinder_pattern, (ImageJavaGrinder_pattern)
  move.l #_ImageJavaGrinder_image, (ImageJavaGrinder_image)
  move.l #_ImageJavaGrinder_palette, (ImageJavaGrinder_palette)

main:
  link a6, #-0x4
  // setPalettePointer(49)
  move.l #0xc0620000, (a1) ; Set CRAM write address
  move.w #0xeee, (a0)      ; setPaletteColor()
  jsr (_load_fonts).l
  jsr (_clear_text).l
  ;; invoke_static_method() name=ImageJavaGrinder_run params=0 is_void=1
  jsr ImageJavaGrinder_run
  unlk a6
  rts

ImageJavaGrinder_run:
  movea.l #ImageJavaGrinder_palette, a2
  move.l (a2), d0
  movea.l d0, a3
  jsr (_set_palette_colors).l
  movea.l #ImageJavaGrinder_pattern, a2
  move.l (a2), d0
  movea.l d0, a3
  moveq.l #0, d7
  jsr (_set_pattern_table).l
  movea.l #ImageJavaGrinder_image, a2
  move.l (a2), d0
  movea.l d0, a3
  jsr (_set_image_data).l
  rts

.align 32
  dc32 808   ; ImageJavaGrinder_pattern.length
_ImageJavaGrinder_pattern:
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x11111111, 0x11111111, 0x11110000, 0x11110000, 0x11111100, 0x11111100, 0x11111122, 0x11111122
  dc32 0x11111111, 0x11111111, 0x0000, 0x0000, 0x0000, 0x0000, 0x22000000, 0x22000000
  dc32 0x11111111, 0x11111111, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x0011, 0x0011, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x11110000, 0x11110000, 0x11110000, 0x11110000, 0x33112200, 0x33112200
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x33111111, 0x33111111
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111100, 0x11111100, 0x11111100, 0x11111100
  dc32 0x11111111, 0x11111111, 0x1111, 0x1111, 0x111111, 0x111111, 0x111111, 0x111111
  dc32 0x11111111, 0x11111111, 0x11111100, 0x11111100, 0x11111100, 0x11111100, 0x11113300, 0x11113300
  dc32 0x11112211, 0x11112211, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x111111, 0x111111, 0x331111, 0x331111
  dc32 0x11111111, 0x11111111, 0x11110000, 0x11110000, 0x11110000, 0x11110000, 0x11112200, 0x11112200
  dc32 0x11111111, 0x11111111, 0x1111, 0x1111, 0x111100, 0x111100, 0x111122, 0x111122
  dc32 0x11112211, 0x11112211, 0x0000, 0x0000, 0x0000, 0x0000, 0x22222222, 0x22222222
  dc32 0x11111111, 0x11111111, 0x0000, 0x0000, 0x0000, 0x0000, 0x22222222, 0x22222222
  dc32 0x11111111, 0x11111111, 0x0000, 0x0000, 0x0022, 0x0022, 0x22222211, 0x22222211
  dc32 0x11111111, 0x11111111, 0x11110000, 0x11110000, 0x11000000, 0x11000000, 0x11000000, 0x11000000
  dc32 0x11440000, 0x11440000, 0x11115555, 0x11115555, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x0000, 0x0000, 0x55555555, 0x55555555, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x111144, 0x111144, 0x111111, 0x111111, 0x111111, 0x111111, 0x111111, 0x111111
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x66000000, 0x66000000, 0x11330000, 0x11330000
  dc32 0x331111, 0x331111, 0x1111, 0x1111, 0x5555, 0x5555, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x55555555, 0x55555555, 0x0000, 0x0000
  dc32 0x11113300, 0x11113300, 0x11660000, 0x11660000, 0x55000000, 0x55000000, 0x0000, 0x0000
  dc32 0x0000, 0x0000, 0x0055, 0x0055, 0x0011, 0x0011, 0x3311, 0x3311
  dc32 0x44111111, 0x44111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x11330000, 0x11330000, 0x11000000, 0x11000000, 0x55000000, 0x55000000, 0x0000, 0x0000
  dc32 0x1111, 0x1111, 0x6611, 0x6611, 0x0011, 0x0011, 0x0044, 0x0044
  dc32 0x11111144, 0x11111144, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x33000000, 0x33000000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x0044, 0x0044, 0x555511, 0x555511, 0x111111, 0x111111, 0x33111111, 0x33111111
  dc32 0x44444444, 0x44444444, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x111111, 0x111111, 0x111111, 0x111111, 0x111111, 0x111111, 0x111111, 0x111111
  dc32 0x11110000, 0x11110000, 0x11113300, 0x11113300, 0x11111100, 0x11111100, 0x11111100, 0x11111100
  dc32 0x0000, 0x0000, 0x330000, 0x330000, 0x11111100, 0x11111100, 0x110000, 0x110000
  dc32 0x331111, 0x331111, 0x111111, 0x111111, 0x111111, 0x111111, 0x11111111, 0x11111111
  dc32 0x11111122, 0x11111122, 0x11112200, 0x11112200, 0x11110000, 0x11110000, 0x11110000, 0x11110000
  dc32 0x333300, 0x333300, 0x111100, 0x111100, 0x11111100, 0x11111100, 0x11111111, 0x11111111
  dc32 0x22111111, 0x22111111, 0x111111, 0x111111, 0x111111, 0x111111, 0x1111, 0x1111
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x111111, 0x111111
  dc32 0x11111122, 0x11111122, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x0000, 0x0000, 0x44000000, 0x44000000, 0x11000000, 0x11000000, 0x11660000, 0x11660000
  dc32 0x330000, 0x330000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x0022, 0x0022, 0x0011, 0x0011, 0x5511, 0x5511, 0x661111, 0x661111
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111155, 0x11111155
  dc32 0x11330000, 0x11330000, 0x33000000, 0x33000000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x0022, 0x0022, 0x4411, 0x4411, 0x1111, 0x1111, 0x551111, 0x551111
  dc32 0x22000000, 0x22000000, 0x11000000, 0x11000000, 0x11550000, 0x11550000, 0x11110000, 0x11110000
  dc32 0x3311, 0x3311, 0x0011, 0x0011, 0x0066, 0x0066, 0x0000, 0x0000
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x66000000, 0x66000000
  dc32 0x111111, 0x111111, 0x333311, 0x333311, 0x0033, 0x0033, 0x0000, 0x0000
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x33333333, 0x33333333, 0x0000, 0x0000
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x33333333, 0x33333333, 0x11111111, 0x11111111
  dc32 0x111111, 0x111111, 0x111111, 0x111111, 0x33111111, 0x33111111, 0x11111111, 0x11111111
  dc32 0x11116600, 0x11116600, 0x11111133, 0x11111133, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x111111, 0x111111, 0x33111111, 0x33111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x11114400, 0x11114400, 0x11110000, 0x11110000, 0x11113333, 0x11113333, 0x11111111, 0x11111111
  dc32 0x11113300, 0x11113300, 0x11111133, 0x11111133, 0x11111111, 0x11111111, 0x11111111, 0x11111111
  dc32 0x55111111, 0x55111111, 0x221111, 0x221111, 0x33331111, 0x33331111, 0x11111111, 0x11111111
  dc32 0x11330000, 0x11330000, 0x11113300, 0x11113300, 0x11111133, 0x11111133, 0x11111111, 0x11111111
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x11111111, 0x11111111
  dc32 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x11111111, 0x22222222, 0x22222222
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x77777777, 0x77777777
  dc32 0x888888, 0x888888, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x88888888, 0x88888888, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xaaaa, 0xaaaa
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xaaaaaaaa, 0xaaaaaaaa
  dc32 0x0000, 0x0000, 0xbbbbbbbb, 0xbbbbbbbb, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x9999, 0x9999, 0x9999, 0x9999
  dc32 0x9999, 0x9999, 0x9999, 0x9999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x99999999, 0x99999999, 0x99999977, 0x99999977, 0x99990000, 0x99990000, 0x99990000, 0x99990000
  dc32 0x99999999, 0x99999999, 0x77777777, 0x77777777, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x8888, 0x8888, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0xaaaaaaaa, 0xaaaaaaaa, 0x0000, 0x0000
  dc32 0x99998888, 0x99998888, 0x99990000, 0x99990000, 0x9999bbbb, 0x9999bbbb, 0x99999999, 0x99999999
  dc32 0x88880000, 0x88880000, 0x0000, 0x0000, 0xbbbb0000, 0xbbbb0000, 0x99990000, 0x99990000
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0xbbbb, 0xbbbb, 0x9999, 0x9999
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0xbbbbbbbb, 0xbbbbbbbb, 0x99999999, 0x99999999
  dc32 0xbbbbbbbb, 0xbbbbbbbb, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0xbbbb0000, 0xbbbb0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x8888, 0x8888, 0x9999, 0x9999
  dc32 0xaaaaaaaa, 0xaaaaaaaa, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0xaaaa9999, 0xaaaa9999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x9999, 0x9999, 0x8888, 0x8888, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x99999999, 0x99999999, 0x88888888, 0x88888888, 0x0000, 0x0000, 0x0000, 0x0000
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x88888888, 0x88888888
  dc32 0x0000, 0x0000, 0xaaaa, 0xaaaa, 0x9999, 0x9999, 0x88889999, 0x88889999
  dc32 0x0000, 0x0000, 0xaaaaaaaa, 0xaaaaaaaa, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0x7799, 0x7799, 0x9999, 0x9999
  dc32 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99998888, 0x99998888, 0x99990000, 0x99990000
  dc32 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x88888888, 0x88888888, 0x0000, 0x0000
  dc32 0xaaaa, 0xaaaa, 0x0000, 0x0000, 0xaaaa, 0xaaaa, 0x9999, 0x9999
  dc32 0xaaaaaaaa, 0xaaaaaaaa, 0x0000, 0x0000, 0xaaaaaaaa, 0xaaaaaaaa, 0x99999999, 0x99999999
  dc32 0xaaaa0000, 0xaaaa0000, 0x0000, 0x0000, 0xaaaaaaaa, 0xaaaaaaaa, 0x99999999, 0x99999999
  dc32 0x0000, 0x0000, 0x0000, 0x0000, 0xaaaaaaaa, 0xaaaaaaaa, 0x99999999, 0x99999999
  dc32 0x8888, 0x8888, 0x9999, 0x9999, 0x9999, 0x9999, 0x99999999, 0x99999999
  dc32 0x88889999, 0x88889999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999
  dc32 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x99999999, 0x0000, 0x0000


.align 32
  dc32 1120   ; ImageJavaGrinder_image.length
_ImageJavaGrinder_image:
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0002, 0x0003, 0x0004, 0x0004, 0x0005, 0x0006
  dw 0x0004, 0x0007, 0x0001, 0x0008, 0x0004, 0x0009, 0x0001, 0x000a
  dw 0x000b, 0x000c, 0x0001, 0x000d, 0x0004, 0x0007, 0x0001, 0x0008
  dw 0x0004, 0x000e, 0x000f, 0x0010, 0x0011, 0x0012, 0x0004, 0x0004
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0013, 0x0014, 0x0014, 0x0000, 0x0015
  dw 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x0001, 0x001c
  dw 0x0000, 0x001d, 0x0001, 0x001e, 0x0016, 0x0017, 0x0018, 0x0019
  dw 0x001a, 0x001b, 0x0001, 0x0001, 0x0001, 0x001f, 0x0020, 0x0021
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0000, 0x0022
  dw 0x0023, 0x0000, 0x0024, 0x0000, 0x0025, 0x0001, 0x0026, 0x0000
  dw 0x0027, 0x0000, 0x0028, 0x0001, 0x0023, 0x0000, 0x0024, 0x0000
  dw 0x0025, 0x0001, 0x0001, 0x0001, 0x0001, 0x0000, 0x0029, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0000, 0x0022
  dw 0x002a, 0x002b, 0x002c, 0x002d, 0x0001, 0x002e, 0x002f, 0x0030
  dw 0x0001, 0x0031, 0x0032, 0x0001, 0x002a, 0x002b, 0x002c, 0x002d
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0033, 0x0034, 0x0035
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0036, 0x0037
  dw 0x0001, 0x0038, 0x0036, 0x0039, 0x0001, 0x003a, 0x0036, 0x0039
  dw 0x0001, 0x003b, 0x0036, 0x003c, 0x0001, 0x0038, 0x0036, 0x0039
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x003d, 0x003e, 0x003e
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001
  dw 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f
  dw 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f
  dw 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f
  dw 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f
  dw 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f, 0x003f
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0040, 0x0041, 0x0042, 0x0042, 0x0042, 0x0042
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0043, 0x0044, 0x0044
  dw 0x0045, 0x0045, 0x0046, 0x0046, 0x0046, 0x0046, 0x0046, 0x0046
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0047, 0x0048, 0x0046, 0x0046
  dw 0x0049, 0x004a, 0x004a, 0x004a, 0x004a, 0x004a, 0x004a, 0x004a
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x004b, 0x004c, 0x0046, 0x004d
  dw 0x004e, 0x0000, 0x0000, 0x0000, 0x0000, 0x004f, 0x0050, 0x0050
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0051, 0x0051
  dw 0x0052, 0x0000, 0x0053, 0x0054, 0x0054, 0x0055, 0x0046, 0x0046
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0056, 0x0057, 0x0057, 0x0057, 0x0057, 0x0057
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0058, 0x0059, 0x005a, 0x005a, 0x005a, 0x005a
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x005b, 0x0046, 0x0046, 0x0046, 0x005c, 0x005d, 0x005d
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x005e, 0x005f, 0x005f, 0x005f, 0x0060, 0x0061, 0x0061
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
  dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0062
  dw 0x0042, 0x0063, 0x0064, 0x0064, 0x0064, 0x0064, 0x0064, 0x0064


.align 32
  dc32 16   ; ImageJavaGrinder_palette.length
_ImageJavaGrinder_palette:
  dw 0x0eee, 0x000e, 0x022e, 0x0aae, 0x044e, 0x066e, 0x088e, 0x0e22
  dw 0x0ecc, 0x0e00, 0x0eaa, 0x0e66, 0x0000, 0x0000, 0x0000, 0x0000


  ; VDP register initialization (24 bytes)
.align 32
vdp_reg_init_table:
  dc.b  0x04  ; reg  0 = mode reg 1: no H interrupt
  dc.b  0x14  ; reg  1 = mode reg 2: blanked, no V interrupt, DMA enable
  dc.b  0x38  ; reg  2 = name table base for scroll A: 0xe000
  dc.b  0x3c  ; reg  3 = name table base for window:   0xf000
  dc.b  0x06  ; reg  4 = name table base for scroll B: 0xc000
  dc.b  0x6c  ; reg  5 = sprite attribute table base: 0xd800
  dc.b  0x00  ; reg  6 = unused register: 0x00
  dc.b  0x00  ; reg  7 = background color: 0x00
  dc.b  0x00  ; reg  8 = unused register: 0x00
  dc.b  0x00  ; reg  9 = unused register: 0x00
  dc.b  0xff  ; reg 10 = H interrupt register: 0xFF (esentially off)
  dc.b  0x03  ; reg 11 = mode reg 3: disable ext int, full H/V scroll
  dc.b  0x81  ; reg 12 = mode reg 4: 40 cell horiz mode, no interlace
  dc.b  0x3f  ; reg 13 = H scroll table base: 0xfc00
  dc.b  0x00  ; reg 14 = unused register: 0x00
  dc.b  0x02  ; reg 15 = auto increment: 0x02
  dc.b  0x01  ; reg 16 = scroll size: V=32 cell, H=64 cell
  dc.b  0x00  ; reg 17 = window H position: 0x00
  dc.b  0x00  ; reg 18 = window V position: 0x00
  dc.b  0xff  ; reg 19 = DMA length count low:   0x00ff
  dc.b  0xff  ; reg 20 = DMA length count high:  0xffxx
  dc.b  0x00  ; reg 21 = DMA source address low: 0xxxxx00
  dc.b  0x00  ; reg 22 = DMA source address mid: 0xxx00xx
  dc.b  0x80  ; reg 23 = DMA source address high: VRAM fill, addr = 0x00xxxx

  ; PSG initialization: set all channels to minimum volume
psg_reg_init_table:
  dc.b  0x9f,0xbf,0xdf,0xff

_load_fonts:
  move.w #((fontend - font) / 4) - 1, d6
  move.l #0x4c000002, (a1)  ; C00004 VRAM write to 0x8c00
  movea.l #font, a2         ; Point to font set
_load_fonts_loop:
  move.l (a2)+, (a0)        ; C00000 write next longword of charset to VDP
  dbra d6, _load_fonts_loop ; loop until done
  rts

.align 32
font:
  dc32 0x01111100, 0x11000110, 0x11000110, 0x11000110 ; A
  dc32 0x11111110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x11111100, 0x11000110, 0x11000110, 0x11111100 ; B
  dc32 0x11000110, 0x11000110, 0x11111100, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000110, 0x11000000 ; C
  dc32 0x11000110, 0x11000110, 0x11111110, 0x00000000
  dc32 0x11111100, 0x11000110, 0x11000110, 0x11000110 ; D
  dc32 0x11000110, 0x11000110, 0x11111100, 0x00000000
  dc32 0x11111110, 0x11000000, 0x11000000, 0x11111100 ; E
  dc32 0x11000000, 0x11000000, 0x11111110, 0x00000000
  dc32 0x11111110, 0x11000000, 0x11000000, 0x11111100 ; F
  dc32 0x11000000, 0x11000000, 0x11000000, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000000, 0x11001110 ; G
  dc32 0x11000110, 0x11000110, 0x11111110, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11000110, 0x11111110 ; H
  dc32 0x11000110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x00111000, 0x00111000, 0x00111000, 0x00111000 ; I
  dc32 0x00111000, 0x00111000, 0x00111000, 0x00000000
  dc32 0x00000110, 0x00000110, 0x00000110, 0x00000110 ; J
  dc32 0x00000110, 0x01100110, 0x01111110, 0x00000000
  dc32 0x11000110, 0x11001100, 0x11111000, 0x11111000 ; K
  dc32 0x11001100, 0x11000110, 0x11000110, 0x00000000
  dc32 0x01100000, 0x01100000, 0x01100000, 0x01100000 ; L
  dc32 0x01100000, 0x01100000, 0x01111110, 0x00000000
  dc32 0x11000110, 0x11101110, 0x11111110, 0x11010110 ; M
  dc32 0x11000110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x11000110, 0x11100110, 0x11110110, 0x11011110 ; N
  dc32 0x11001110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000110, 0x11000110 ; O
  dc32 0x11000110, 0x11000110, 0x11111110, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000110, 0x11111110 ; P
  dc32 0x11000000, 0x11000000, 0x11000000, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000110, 0x11000110 ; Q
  dc32 0x11001110, 0x11001110, 0x11111110, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000110, 0x11111100 ; R
  dc32 0x11000110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x11111110, 0x11000110, 0x11000000, 0x11111110 ; S
  dc32 0x00000110, 0x11000110, 0x11111110, 0x00000000
  dc32 0x11111110, 0x00111000, 0x00111000, 0x00111000 ; T
  dc32 0x00111000, 0x00111000, 0x00111000, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11000110, 0x11000110 ; U
  dc32 0x11000110, 0x11000110, 0x11111110, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11000110, 0x11000110 ; V
  dc32 0x01101100, 0x00111000, 0x00010000, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11000110, 0x11010110 ; W
  dc32 0x11111110, 0x11101110, 0x11000110, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11101110, 0x01111100 ; X
  dc32 0x11101110, 0x11000110, 0x11000110, 0x00000000
  dc32 0x11000110, 0x11000110, 0x11000110, 0x01101100 ; Y
  dc32 0x00111000, 0x00111000, 0x00111000, 0x00000000
  dc32 0x11111110, 0x00001110, 0x00011100, 0x00111000 ; Z
  dc32 0x01110000, 0x11100000, 0x11111110, 0x00000000
  dc32 0x00000000, 0x00000000, 0x00000000, 0x00000000 ; ' '
  dc32 0x00000000, 0x00000000, 0x00000000, 0x00000000
fontend:

_clear_text:
  move.w #(64 * 32 / 2) - 1, d6
  move.l #0x60000003, (a1)  ; C00004 VRAM write to 0xe000
  move.l #((1120 + (']' - 'A')) << 16) | (1120 + (']' - 'A')), d7
_clear_text_loop:
  move.l d7, (a0)           ; C00000 write next longword of ' ' to VDP
  dbra d6, _clear_text_loop ; loop until done
  rts

_set_pattern_table:
  lsl.l #5, d7               ; pattern_index * 32
  move.l d7, d5
  rol.w #2, d5
  and.w #3, d5               ; d5 = upper 2 bits moved to lower 2 bits
  and.w #0x3ffe, d7          ; d7 = lower 13 bits
  or.w #0x4000, d7
  swap d7
  or.w d5, d7
  move.l d7, (a1)
  move.l (-4,a3), d5         ; Code len
  subq.l #1, d5
_set_pattern_table_loop:
  move.l (a3)+, (a0)
  dbf d5, _set_pattern_table_loop
  rts

_set_image_data:
  move.l #0x40000003, d7     ; Set cursor position in VDP
  move.l d7, (a1)
  move.l (-4,a3), d5         ; Code len
  eor.w d6, d6
_set_image_data_loop:
  move.w (a3)+, (a0)
  add.w #1, d6
  cmp.w #40, d6
  bne.s _set_image_data_not_40
  eor.w d6, d6
  add.l #0x00800000, d7
  move.l d7, (a1)
_set_image_data_not_40:
  dbf d5, _set_image_data_loop
  rts

_set_palette_colors:
  move.l #0xc0000000, (a1)   ; C00004 write CRAM address 0x0000
  move.l (-4,a3), d5         ; Code len
_set_palette_colors_loop:
  move.w (a3)+, (a0)
  dbf d5, _set_palette_colors_loop
  rts


