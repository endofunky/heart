;; ------------------------------------------; ==>>[Build]<<===================
bits 64                                      ;
org 0                                        ; $ nasm -f bin -o heart heart.asm
;; ------------------------------------------; $ chmod +x heart
;; Byte Swap Macros                          ;
;; ------------------------------------------; ==>>[Run]<<=====================
%macro dws 1-* ; swap word                   ;
%rep    %0                                   ; ELF64: $ ./heart
        db (%1 >> 8) & 0xff, %1 & 0xff       ;
%rotate 1                                    ; DOS.COM: $ cp heart heart.com &&
%endrep                                      ;              dosbox ./heart.com
%endmacro                                    ;
                                             ; GameBoy: $ mgba ./heart
%macro dds 1-* ; swap dword                  ;          $ sameboy ./heart
%rep    %0                                   ;
        db (%1 >> 24) & 0xff                 ; MegaDrive: $ blastem ./heart
        db (%1 >> 16) & 0xff                 ;
        dws %1                               ; PDF: $ zathura ./heart
%rotate 1                                    ;
%endrep                                      ; ARJ: $ cp heart heart.arj &&
%endmacro                                    ;          arj e heart.arj
;; ------------------------------------------;
;; 7zip UINT64 Packing Macro                 ; 7zip: $ 7z e -t7z ./heart
;; ------------------------------------------;
%macro dq7 1                                 ; PKZIP: $ unzip ./heart
%assign m 0x80 ; mask                        ;
%assign p 0    ; prefix/first byte           ; ================================
%assign v %1   ; value                       ;
%assign i 0                                  ; Output size:
%rep    8                                    ;
        %if v < (1 << ( 7  * (i + 1)))       ; $ stat --printf="%s\n" ./heart
                %assign p p|(v >> (8 * i))   ; 1014
                %exitrep                     ;
        %endif            ;----------------------------------------------------
        %assign p p | m   ; Size of encoding sequence depends on first byte:
        %assign m m >> 1  ; First_Byte  Extra_Bytes        Value
        %assign i i + 1   ; (binary)
%endrep                   ; 0xxxxxxx               : ( xxxxxxx           )
        db p & 0xFF       ; 10xxxxxx    BYTE y[1]  : (  xxxxxx << (8 * 1)) + y
%rep    i                 ; 110xxxxx    BYTE y[2]  : (   xxxxx << (8 * 2)) + y
        db v & 0xFF       ; ...
        %assign v v >> 8  ; 1111110x    BYTE y[6]  : (       x << (8 * 6)) + y
%endrep                   ; 11111110    BYTE y[7]  :                         y
%endmacro                 ; 11111111    BYTE y[8]  :                         y
;; ----------------------------------------------------------------------------
;; ELF: Elf64_Ehdr
;; ----------------------------------------------------------------------------
elf_va: equ 0x1000           ; (org 0x1000)
elf_ehdr:                    ;
        db 0x7f, "ELF"       ; e_ident, jg 0x47, SEGA SP ------.
        dds smd_start-$$     ; e_ident, SEGA ROM EP (MSB) -----|-------.
        db "heart <3"        ; padding                         |       |
        dw 2                 ; e_type (ET_EXEC)                |       |
        dw 0x3e              ; e_machine (AMD x86-64)          |       |
        dd 1                 ; e_version (EV_CURRENT)          |       |
        dq elf_start+elf_va  ; e_entry ---------.              |       |
        dq elf_phdr          ; e_phoff ---------|-------.      |       |
        dq 0                 ; e_shoff          |       |      |       |
        dd 0                 ; e_flags          |       |      |       |
        dw elf_ehdrsize      ; e_ehsize         |       |      |       |
        dw elf_phdrsize      ; e_phentsize      |       |      |       |
        dw 1                 ; e_phnum          |       |      |       |
        dw 0                 ; e_shentsize      |       |      |       |
        dw 0                 ; e_shnum          |       |      |       |
        dw 0                 ; e_shstrndx       |       |      |       |
elf_ehdrsize: equ $-elf_ehdr ;                  |       |      |       |
;; ---------------------------------------------|-------|------|-------|-------
;; ELF: exit                                    |       |      |       |
;; ---------------------------------------------|-------|------|-------|-------
elf_exit:                    ;                  |       |      |       |
        mov bl, 0            ; exit status <----|-.     |      |       |
        mov al, 1            ; sys_exit         | |     |      |       |
        int 0x80             ;                  | |     |      |       |
;; ---------------------------------------------|-|-----|------|-------|-------
;; DOS COM EP (org 0x100)                       | |     |      |       |
;;                                              | |     |      |       |
;; Fixed at 0x47 due to jmp from ELF signature  | |     |      |       |
;; ---------------------------------------------|-|-----|------|-------|-------
        mov dx, msg + 0x100  ; <----------------|-|-----|------'       |
        mov ah, 9            ; print string     | |     |              |
        int 0x21             ;                  | |     |              |
        mov ah, 0x4c         ; exit w/ status   | |     |              |
        int 0x21             ;                  | |     |              |
;; ---------------------------------------------|-|-----|--------------|-------
;; ELF: EP                                      | |     |              |
;; ---------------------------------------------|-|-----|--------------|-------
elf_start:                   ; <----------------' |     |              |
        mov dl, msg_len-1    ; msg length         |     |              |
        mov cx, msg+elf_va   ; msg vaddr          |     |              |
        inc bx               ; (1 = stdout)       |     |              |
        mov al, 4            ; sys_write          |     |              |
        int 0x80             ;                    |     |              |
        jmp elf_exit         ; -------------------'     |              |
;; -----------------------------------------------------|--------------|-------
;; ELF: Elf64_Phdr                                      |              |
;; -----------------------------------------------------|--------------|-------
elf_phdr:                    ;                          |              |
        dd 1                 ; p_type (PT_LOAD) <-------'              |
        dd 0x01|0x04         ; p_flags (0x01 = E/0x04 = R)             |
        dq 0                 ; p_offset                                |
        dq elf_va            ; p_vaddr                                 |
        dq elf_va            ; p_paddr                                 |
        dq filesize          ; p_filesz                                |
        dq filesize          ; p_memsz                                 |
        dq 0x1000            ; p_align                                 |
elf_phdrsize: equ $-elf_phdr ;                                         |
;; --------------------------------------------------------------------|-------
;; SEGA MegaDrive: Font (MSB, 16-bit aligned)                          |
;;                                                                     |
;; Include this and the following sections early to fill up GB ROM     |
;; padding to 0x100.                                                   |
;; --------------------------------------------------------------------|-------
align 2, db 0                                              ;           |
smd_f:                                                     ;           |
        dds 0x00000110, 0x00011100, 0x01110000, 0x11000000 ; '<'       |
        dds 0x01110000, 0x00011100, 0x00000110, 0x00000000 ;           |
        dds 0x01111100, 0x11000110, 0x00000110, 0x11111100 ; '3'       |
        dds 0x00000110, 0x11000110, 0x01111100, 0x00000000 ;           |
smd_f_len: equ $-smd_f                                     ;           |
;; --------------------------------------------------------------------|-------
;; SEGA MegaDrive: Palette (MSB, 16-bit aligned)                       |
;; --------------------------------------------------------------------|-------
smd_p:                 ;                                               |
        dws 0, 0x0eee  ; transparent + white                           |
smd_p_len: equ $-smd_p ;                                               |
;; --------------------------------------------------------------------|-------
;; GameBoy: Font                                                       |
;; --------------------------------------------------------------------|-------
gb_f:                                                     ;            |
        db 0x03, 0x03, 0x0c, 0x0c, 0x30, 0x30, 0xc0, 0xc0 ; '<'        |
        db 0x30, 0x30, 0x0c, 0x0c, 0x03, 0x03, 0x00, 0x00 ;            |
        db 0x7c, 0x7c, 0x82, 0x82, 0x02, 0x02, 0x3c, 0x3c ; '3'        |
        db 0x02, 0x02, 0x82, 0x82, 0x7c, 0x7c, 0x00, 0x00 ;            |
gb_f_len: equ $-gb_f                                      ;            |
;; --------------------------------------------------------------------|-------
;; GameBoy: ROM EP (Sharp LR35902)                                     |
;;                                                                     |
;; Needs to be placed at offset 0x100.                                 |
;;                                                                     |
;; Sega MegaDrive/Genesis consoles with TMSS would check for a "SEGA"  |
;; string here, alas this will only run on earlier generations and     |
;; various emulators.                                                  |
;; --------------------------------------------------------------------|-------
        times 0x100-($-$$) db 0 ; Pad to 0x100                         |
        db 0                    ; nop                                  |
        db 0xc3                 ; jp gb_start -----------------------. |
        dw gb_start             ;                                    | |
;; ------------------------------------------------------------------|-|-------
;; GameBoy: ROM Header                                               | |
;; ------------------------------------------------------------------|-|-------
        db 0xce, 0xed, 0x66, 0x66, 0xcc, 0x0d, 0x00, 0x0b ; Ninten.  | |
        db 0x03, 0x73, 0x00, 0x83, 0x00, 0x0c, 0x00, 0x0d ; Logo     | |
        db 0x00, 0x08, 0x11, 0x1f, 0x88, 0x89, 0x00, 0x0e ;          | |
        db 0xdc, 0xcc, 0x6e, 0xe6, 0xdd, 0xdd, 0xd9, 0x99 ; Required | |
        db 0xbb, 0xbb, 0x67, 0x63, 0x6e, 0x0e, 0xec, 0xcc ;          | |
        db 0xdd, 0xdc, 0x99, 0x9f, 0xbb, 0xb9, 0x33, 0x3e ;          | |
gb_t:   db "<3"                ; Title (11 chars)                    | |
gb_t_len: equ $-gb_t           ;                                     | |
        times 11-gb_t_len db 0 ;                                     | |
        times 4 db " "         ; Product Code (4 chars)              | |
        db 0                   ; DMG                                 | |
        dw 0                   ; License Code                        | |
        db 0                   ; SGB Flag (GameBoy)                  | |
        db 0                   ; Carridge Type (ROM only)            | |
        db 0                   ; ROM size                            | |
        db 0                   ; RAM size                            | |
        db 0                   ; Destination code 0=Japan            | |
        db 0x33                ; Licensee Code                       | |
        db 0                   ; Mask ROM version                    | |
        db 0xc5                ; Complement Check                    | |
        dw 0x6fd7              ; Checksum                            | |
;; ------------------------------------------------------------------|-|-------
;; SEGA MegaDrive: EP (Motorola 68k, MSB, no-TMSS, 16-bit aligned)   | |
;;                                                                   | |
;; TMSS is not supported, so no need to check for it and/or write    | |
;; "SEGA" to 0x00A14000.                                             | |
;; ------------------------------------------------------------------|-|-------
align 2, db 0                            ;                           | |
smd_vc: equ 0x00C00004                   ; VDP Control               | |
smd_vd: equ 0x00C00000                   ; VDP Data                  | |
smd_start:                               ;                           | |
        db  0x46, 0xfc, 0x27, 0          ; move.w #$2700, sr <-------|-'
        db  0x20, 0x7c                   ; move.l #smd_vregs, a0     |
        dds smd_vregs-$$                 ;                           |
        db  0x30, 0x3c                   ; move.w #smd_vregs_len, d0 |
        dws smd_vregs_len-1              ;                           |
        db  0x32, 0x3c, 0x80, 0          ; move.w #$8000, d1         |
smd_v_l:                                 ;                           |
        db  0x12, 0x18                   ; move.b (a0)+, d1 <--.     |
        db  0x33, 0xc1, 0, 0xc0, 0, 0x04 ; move.w d1, smd_vc   |     |
        db  0xd2, 0x7c, 0x01, 0          ; add.w #$0100, d1    |     |
        db  0x51, 0xc8                   ; dbra d0, smd_vl ----'     |
        dws smd_v_l-$                    ;                           |
        db  0x23, 0xfc, 0xc0, 0, 0, 0x03 ; move.l #$C0000003, smd_vc |
        dds smd_vc                       ;                           |
        db  0x20, 0x7c                   ; move.l #smd_p, a0         |
        dds smd_p-$$                     ;                           |
        db  0x30, 0x3c                   ; move.w #(smd_p_len/2), d0 |
        dws ((smd_p_len)/2)-1            ;                           |
smd_p_l:                                 ;                           |
        db  0x33, 0xd8, 0, 0xc0, 0, 0    ; move.w (a0)+, smd_vd <.   |
        db  0x51, 0xc8                   ; dbra d0, smd_p_l -----'   |
        dws smd_p_l-$                    ;                           |
        db  0x23, 0xfc, 0x40, 0x20, 0, 0 ; move.l #$40200000, smd_vc |
        dds smd_vc                       ;                           |
        db  0x20, 0x7c                   ; move.l #smd_f, a0         |
        dds smd_f-$$                     ;                           |
        db  0x30, 0x3c                   ; move.w #(smd_f_len/4), d0 |
        dws ((smd_f_len)/4)-1            ;                           |
smd_f_l:                                 ;                           |
        db  0x23, 0xd8                   ; move.l (a0)+, smd_vd <-.  |
        dds smd_vd                       ;                        |  |
        db  0x51, 0xc8                   ; dbra d0, smd_f_l ------'  |
        dws smd_f_l-$                    ;                           |
        db  0x23, 0xfc, 0x40, 0, 0, 0x03 ; move.l #$40000003, smd_vc |
        dds smd_vc                       ;                           |
        db  0x33, 0xfc, 0, 1             ; move.w #$0001, smd_vd     |
        dds smd_vd                       ;                           |
        db  0x33, 0xfc, 0, 2             ; move.w #$0002, smd_vd     |
        dds smd_vd                       ;                           |
        db  0x4e, 0x72, 0x27, 0          ; stop #$2700               |
;; ------------------------------------------------------------------|---------
;; GameBoy: Main (Sharp LR35902)                                     |
;; ------------------------------------------------------------------|---------
gb_start:                     ;                                      |
        db 0xf0, 0x44         ; ld a, [rLY] <----.  <----------------'
        db 0xfe, 0x90         ; cp 144           |
        db 0x38, gb_start-$-2 ; jr c, gb-start --'
        db 0x21, 0x10, 0x90   ; ld hl, $9000 + 16
        db 0x11               ; ld de, $0172
        dw gb_f               ;
        db 0x06, gb_f_len     ; ld b, 32
gb_f_l:                       ;
        db 0x1a               ; ld a, [de] <----.
        db 0x13               ; inc de          |
        db 0x22               ; ld [hl+], a     |
        db 0x05               ; dec b           |
        db 0x20, gb_f_l-$-2   ; jr nz, gb_f_l --'
        db 0x21, 0, 0x98      ; ld hl, $9800
        db 0x36, 1            ; ld [hl], 1
        db 0x23               ; inc hl
        db 0x36, 2            ; ld [hl], %10000001
        db 0x3e, 0x81         ; ld a, $81
        db 0xe0, 0x40         ; ldh [rLCDC], a
        db 0x18, -2           ; jr -2 (loop)
;; -----------------------------------------------------------------------------
;; PKZIP: Local Header
;; -----------------------------------------------------------------------------
z_lh:
        db "P", "K", 3, 4 ; signature
        dw 10             ; version 10
        dw 0              ; flags
        dw 0              ; compression (none)
        dw 0              ; mod_date
        dw 0              ; mod_time
        dd z7_crc         ; crc-32
        dd z7_len         ; compressed size
        dd z7_len         ; uncompressed size
        dw z_l_fn_len     ; file name len
        dw 0              ; extra field len
z_l_fn:
;; ----------------------------------------------------------------------------
;; ARJ (Archive Header) / PKZIP Local File Name
;; ----------------------------------------------------------------------------
        db 0x60, 0xea     ; signature
        dw arj_abhdr_len  ; basic header size
arj_abhdr:                ;
        db arj_afhdr_len  ; header size
        db 0x0b           ; rev
        db 0x01           ; extract version
        db 0x0b           ; host OS (11 = WIN32)
        db 0x10           ; flags (0x10 = PATHSYM_FLAG))
        db 0              ; security version
        db 0x02           ; file type (2 = comment header)
        db 0x69           ; reserved
;; ----------------------------------------------------------------------------
;; SEGA MegaDrive: VDP Registers (overlays ARJ Archive Header for 24 bytes)
;; ----------------------------------------------------------------------------
smd_vregs:                        ;
        db 0x14, 0x74, 0x30, 0x00 ; ARJ: archive created
        db 0x07, 0x78, 0x00, 0x00 ; ARJ: archive last modified
        db 0x00, 0x00, 0x08, 0x00 ; ARJ: archive size
        db 0x81, 0x3f, 0x00, 0x02 ; ARJ: security envelope file position
        db 0x01, 0x00             ; ARJ: filespec position in filename
        db 0x00, 0xff             ; ARJ: length of security envelope data
        db 0xff                   ; ARJ: encryption version
        db 0x00                   ; ARJ: last chapter
        db 0x00                   ; ARJ: arj protection factor
        db 0x80                   ; ARJ: arj flags (second series)
smd_vregs_len: equ $-smd_vregs    ;
;; ----------------------------------------------------------------------------
;; ARJ (Archive Header, cont.)
;; ----------------------------------------------------------------------------
        dw 0                   ; spare bytes
arj_afhdr_len: equ $-arj_abhdr ;
        db 0                   ; filename of archive (string)
        db 0                   ; archive comment (string)
arj_abhdr_len: equ $-arj_abhdr ;
        dd 0xae5d500b          ; basic header CRC
        dw 0                   ; 1st extended header size (0 if none)
;; ----------------------------------------------------------------------------
;; ARJ (Local File Header)
;; ----------------------------------------------------------------------------
        db 0x60, 0xea          ; signature
        dw arj_fbhdr_len       ; basic header size
arj_fbhdr:                     ;
        db arj_ffhdr_len       ; first header size
        db 0x0b                ; rev
        db 0x01                ; extract version
        db 0x03                ; host OS (3 = AMIGA)
        db 0x10                ; flags (0x10 = PATHSYM_FLAG))
        db 0                   ; method (0 = stored)
        db 0                   ; file type (0 = binary)
        db 0                   ; garbled password modifier
        dd 0                   ; date time stamp modified
        dd arj_f_len           ; compressed size
        dd arj_f_len           ; original size
        dd z7_crc              ; file crc
        dw 0                   ; entryname position in filename
        dw 0x20                ; file access mode
        db 0                   ; first chapter of file's lifespan
        db 0                   ; last chapter of file's lifespan
        dd 0                   ; 4 bytes for extended file position
arj_ffhdr_len: equ $-arj_fbhdr ;
        db "<3.7z", 0          ; filename (string)
        db 0x00                ; comment  (string)
arj_fbhdr_len: equ $-arj_fbhdr ;
        dd 0x21c69ae5          ; basic header crc
        dw 0                   ; 1st extended header size
z_l_fn_len: equ $-z_l_fn
arj_f:
;; ----------------------------------------------------------------------------
;; 7zip: Signature/Start Header / PKZIP Loca File Name End
;; ----------------------------------------------------------------------------
z7_crc: equ 0x9059e205
z7:
        db "7z", 0xbc, 0xaf, 0x27, 0x1c ; kSignature
        db 0x00                         ; ArchiveVersion.Major
        db 0x04                         ; ArchiveVersion.Minor
        dd 0xe38ed5d2                   ; StartHeaderCRC
        dq pdf_len                      ; StartHeader.NextHeaderOffset
        dq z7_h_len                     ; StartHeader.NextHeaderSize
        dd 0x1c3345d9                   ; StardHeader.NextHeaderCRC
;; ----------------------------------------------------------------------------
;; 7zip: File / PDF
;; ----------------------------------------------------------------------------
pdf:
        db "%PDF-1.", 0xA
        db "1 0 obj<</Kids[<</Contents 3 0 R/Type/Page/MediaBox[0 0 58 50]>>]"
        db "/Type/Pages/Count 1>>endobj", 0xA
        db "2 0 obj<</Type/Catalog/Pages 1 0 R>>endobj", 0xA
        db "3 0 obj<<>>stream", 0xA
        db "BT /F 55 Tf -2 5 Td ("
msg:    db "<3", 0xA, "$"
msg_len: equ $-msg
        db ")' ET", 0xA
        db "endstream", 0xA
        db "endobj", 0xA
        db "trailer<</Root 2 0 R>>"
pdf_len: equ $-pdf
;; ----------------------------------------------------------------------------
;; 7zip: Header
;; ----------------------------------------------------------------------------
z7_h:                            ;
        db 0x01                  ; NID::kHeader
        db 0x04                  ; +- NID::kMainStreamsInfo
        db 0x06                  ; |  +- NID::kPackInfo
        dq7 0x00                 ; |  |  +- PackPos
        dq7 0x01                 ; |  |  +- NumPackStreams
        db 0x09                  ; |  |  +- NID::kSize
        dq7 pdf_len              ; |  |  |  `- PackSizes[0]
        db 0x00                  ; |  |  `- NID::kEnd
        db 0x07                  ; |  +- NID::kUnPackInfo (Coders Info)
        db 0x0b                  ; |  |  +- NID::kFolder
        dq7 0x01                 ; |  |  +- CodersInfo.NumFolders
        db 0x00                  ; |  |  +- CodersInfo.External
        db 0x01                  ; |  |  |  +- Folder[0].NumCoders
        db 0x01                  ; |  |  |  +- Folder[0].CodecIdSize
        db 0x00                  ; |  |  |  `- Folder[0].CodecId[0]
        db 0x0c                  ; |  |  +- NID::kCodersUnPackSize
        dq7 pdf_len              ; |  |  |  `- UnPackSize
        db 0x00                  ; |  |  `- NID::kEnd
        db 0x08                  ; |  +- NID::kSubStreamsInfo
        db 0x0a                  ; |  |  +- NID::kCRC (Digests)
        db 0x01                  ; |  |  |  +- AllAreDefined
        dd 0xe66cb0d2            ; |  |  |  `- CRCs[0]
        db 0x00                  ; |  |  `- NID::kEnd
        db 0x00                  ; |  `- NID::kEnd
        db 0x05                  ; +- NID::kFilesInfo
        dq7 0x01                 ; |  +- NumFiles
        db 0x11                  ; |  +- FilesInfo[0].PropertyType (kNames)
z7_fi_len: equ z7_fi_end-z7_fi   ; |  |  |
        dq7 z7_fi_len            ; |  |  +- FilesInfo[0].Size
z7_fi:                           ; |  |  |
        db 0x00                  ; |  |  +- FilesInfo[0].kNames.External
        db __utf16le__("<3.pdf") ; |  |  +- FilesInfo[0].kNames.Names[0]
        dw 0                     ; |  |  `- UTF-16 Little-Endian + NULL
z7_fi_end:                       ; |  |  (timestamp + attrs removed)
        db 0x00                  ; |  `- NID::kEnd (break FilesInfo loop)
        db 0x00                  ; `- NID::kEnd
z7_len: equ $-z7
z7_h_len: equ $-z7_h
arj_f_len: equ $-arj_f
;; ----------------------------------------------------------------------------
;; ARJ (End of Archive)
;; ----------------------------------------------------------------------------
        db 0x60, 0xea ; signature
        dw 0          ; basic header size
;; -----------------------------------------------------------------------------
;; PKZIP: Central Directory
;; -----------------------------------------------------------------------------
z_c:
        db "P", "K", 1, 2 ; signature
        dw 0              ; version made by
        dw 10             ; version 10
        dw 0              ; flags
        dw 0              ; compression (none)
        dw 0              ; last_mod_date
        dw 0              ; last_mod_time
        dd z7_crc         ; crc-32
        dd z7_len         ; compressed size
        dd z7_len         ; uncompressed size
        dw z_c_fn_len     ; filename length
        dw 0              ; extra fieds length
        dw 0              ; fille comment length
        dw 0              ; disk num
        dw 0              ; int_file_attr
        dd 0              ; ext_file_attr
        dd z_lh           ; fh offset
z_c_fn:
        db "<3.7z"
z_c_fn_len: equ $ - z_c_fn
z_c_len: equ $ - z_c
;; -----------------------------------------------------------------------------
;; PKZIP: End of Central Directory
;; -----------------------------------------------------------------------------
        db "P", "K", 5, 6 ; signature
        dw 0              ; disk_num
        dw 0              ; cd_start_disk_n
        dw 1              ; cd_entries_on_disk
        dw 1              ; cd_entries
        dd z_c_len        ; size of centra dir
        dd z_c            ; offset of centra dir
        dd 0              ; comment length
;; ----------------------------------------------------------------------------
;; Epilogue
;; ----------------------------------------------------------------------------
;; Uncomment the next line, rebuild and patch Nintendo GameBoy ROM checksum
;; (rgbfix -v <output>) if your emulator barks or when storing on a cartrdige:
;;
;; times 0x8000-($-$$) db 0xff ; Pad to offset 0x8000
;; ----------------------------------------------------------------------------
filesize: equ $ - $$
