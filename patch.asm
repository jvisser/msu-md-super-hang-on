; Mega CD MMIO addresses used for communicating with msu-md driver on the mega cd (mode 1)
MSU_COMM_CMD        equ $a12010                 ; Comm command 0 (high byte)
MSU_COMM_ARG        equ $a12011                 ; Comm command 0 (low byte)
MSU_COMM_ARG32      equ $a12012                 ; Comm command 1/2
MSU_COMM_CMD_CK     equ $a1201f                 ; Comm command 7 (low byte)
MSU_COMM_STATUS     equ $a12020                 ; Comm status 0 (0-ready, 1-init, 2-cmd busy)

; msu-md commands
MSU_PLAY            equ $1100                   ; PLAY      decimal no. of track (1-99) playback will be stopped in the end of track
MSU_PLAY_LOOP       equ $1200                   ; PLAY LOOP decimal no. of track (1-99) playback will restart the track when end is reached
MSU_PAUSE           equ $1300                   ; PAUSE     vol fading time. 1/75 of sec. (75 equal to 1 sec) instant stop if 0 pause playback
MSU_RESUME          equ $1400                   ; RESUME    none. resume playback
MSU_VOL             equ $1500                   ; VOL       volume 0-255. set cdda volume
MSU_NOSEEK          equ $1600                   ; NOSEEK    0-on(default state), 1-off(no seek delays)  seek time emulation switch
MSU_PLAYOF          equ $1a00                   ; PLAYOF    #1 = decimal no. of track (1-99) #2 = offset in sectors from the start of the track to apply when looping play cdda track and loop from specified sector offset

; Where to put the code
ROM_END             equ $7f220

; MACROS: ------------------------------------------------------------------------------------------

    macro MSU_WAIT
.\@
        tst.b   MSU_COMM_STATUS
        bne.s   .\@
    endm

    macro MSU_COMMAND cmd, param
        MSU_WAIT
        move.w  #(\1|\2),MSU_COMM_CMD           ; Send msu cmd
        addq.b  #1,MSU_COMM_CMD_CK              ; Increment command clock
    endm

    macro PLAY_TRACK trackId
        MSU_WAIT
        MSU_COMMAND MSU_PLAY_LOOP,\1
    endm

; MEGA DRIVE OVERRIDES : ------------------------------------------------------------------------------------------

        ; M68000 Reset vector
        org     $4
        dc.l    ENTRY_POINT                     ; Custom entry point for redirecting

        org     $6bac                           ; Original ENTRY POINT
Game

        org $7ddc
            nop
            jsr     fade_out.l

        org $6852
            nop
            jsr     stop_music_ext.l
        org $689c
            nop
            jsr     stop_music.l
        org     $6a26
            nop
            jsr     stop_music.l
        org $739e
            nop
            jsr     stop_music.l
        org $8898
            nop
            jsr     stop_music.l
        org $b382
            nop
            jsr     stop_music.l
        org $abb6                               ; This seems to be a bug where address $b1 is used instead of immediate value #$b1
            nop
            jsr     stop_music.l

        org $ab20
            jsr     pause_music.l

        org $ab0e
            jsr     resume_music.l

        org $7e1e
            jmp     play_music_song_select.l
            nop
            nop

        org $871c
            jsr     play_music_stage_start.l
            nop
            nop

        org $68b6
            jsr     play_music_sound_test.l
            bra.s   play_music_sound_test_after
            org $6922
play_music_sound_test_after

        org $5f02
            nop
            jsr     play_music_81.l
        org $7c44
            nop
            jsr     play_music_81.l

        org $b42a
            nop
            jsr     play_music_86.l

        org $e2e0
            nop
            jsr     play_music_87.l

        org $507a
            nop
            jsr     play_music_8a.l
        org $6768
            nop
            jsr     play_music_8a.l

        org $6e8c
sound_command

; MSU-MD Init: -------------------------------------------------------------------------------------

        org     ROM_END
ENTRY_POINT
        bsr.s   audio_init
        jmp     Game

audio_init
        jsr     msu_driver_init
        tst.b   d0                              ; if 1: no CD Hardware found
.audio_init_fail
        bne.s   .audio_init_fail                ; Loop forever

        MSU_COMMAND MSU_NOSEEK, 1
        MSU_COMMAND MSU_VOL,    255
        rts

; Sound: -------------------------------------------------------------------------------------

    align 2

fade_out
        ; 2 second fade out
        MSU_COMMAND MSU_PAUSE, 150
        rts


stop_music_ext
        ; Original code
        move.w  d0,$c70e.w
stop_music
        MSU_COMMAND MSU_PAUSE, 0

        ; Send stop command to original code
        move.b  #$b1,d7
        jmp     sound_command


pause_music
        MSU_COMMAND MSU_PAUSE, 0

        ; Original code
        lea     $a01c08,a1
        rts


resume_music
        MSU_COMMAND MSU_RESUME, 0

        ; Original code
        lea     $a01c09,a1
        rts


play_music_song_select
        ; Original code
        move.b  d7,$ff0518
        bra.s   play_music


play_music_stage_start
        ; Original code
        move.b  $ff0518,d7
        ; Fall through to play_music


play_music
        movem.l d7/a0,-(sp)
        subi.w  #$81,d7
        ext.w   d7
        add.w   d7,d7
        lea     AUDIO_TBL,a0
        move.w  (a0,d7),MSU_COMM_CMD
        addq.b  #1,MSU_COMM_CMD_CK
        movem.l (sp)+,d7/a0
        rts


play_music_sound_test
        cmpi.w  #8,d0
        bge.s   .non_music
            movem.l d0/a0,-(sp)
            add.w   d0,d0
            lea     AUDIO_TBL,a0
            move.w  (a0,d0),MSU_COMM_CMD
            addq.b  #1,MSU_COMM_CMD_CK
            movem.l (sp)+,d0/a0
            rts
.non_music
        move.b (a0,d0),d7
        jmp     sound_command


; Select Your Class
play_music_81
        PLAY_TRACK 1
        rts

; Finished
play_music_86
        PLAY_TRACK 6
        rts

; Enter Your Name
play_music_87
        PLAY_TRACK 7
        rts

; Winner (Shop BGM)
play_music_8a
        PLAY_TRACK 8
        rts

; TABLES: ------------------------------------------------------------------------------------------

        align 2
AUDIO_TBL                                   ; #Track Name
        dc.w    MSU_PLAY_LOOP|01            ; 01 - Select Your Class
        dc.w    MSU_PLAY_LOOP|02            ; 02 - Outride a Crisis
        dc.w    MSU_PLAY_LOOP|04            ; 04 - Winning Run
        dc.w    MSU_PLAY_LOOP|03            ; 03 - Sprinter
        dc.w    MSU_PLAY_LOOP|05            ; 05 - Hard Road
        dc.w    MSU_PLAY_LOOP|06            ; 06 - Finished
        dc.w    MSU_PLAY_LOOP|07            ; 07 - Enter Your Name
        dc.w    MSU_PLAY_LOOP|08            ; 08 - Winner (Shop BGM)

; MSU-MD DRIVER: -----------------------------------------------------------------------------------

        align 2
msu_driver_init
        incbin  "msu-drv.bin"
