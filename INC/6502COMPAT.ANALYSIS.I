*--------------------------------------
* 6502 Compatibility Macro Library - ANALYSIS & SAFE VARIANTS
* Critical Register Preservation for A2osX 6502 Port
*
* This document analyzes where register clobbering is DANGEROUS
* in the existing codebase and provides SAFE macro variants.
*--------------------------------------

*
* ============================================================================
* CRITICAL FINDING: When Accumulator MUST Be Preserved
* ============================================================================
*
* Analysis of actual code patterns from A2osX codebase:
*

*
* PATTERN 1: CMP/BIT followed by conditional branch
* ============================================================
* Source: DRV/PPPSSC.DRV.S.txt (SSC.ReadPPP function)
*
*   lda SSC.STATUS-$8F,x     ; Load status byte into A
*   bit #SSC.STATUS.nDCD     ; Test bit using BIT (Z flag = condition)
*   bne .9                     ; Branch based on Z flag
*   bit #SSC.STATUS.RDRF     ; Another bit test (A still has SSC.STATUS!)
*   bne .3                     ; Branch based on Z flag
*
* DANGER: If STZ macro clobbers A between these operations,
*         the BIT instruction operates on wrong value!
*
* SAFE USAGE: Use >STZ.SAFE instead
*

*
* PATTERN 2: Loop counter in X, critical value in A
* ============================================================
* Source: BIN/WC.S.txt (CS.RUN.OpenFile loop)
*
*   ldx #12                    ; X = loop counter
*   ldy #fCharCount
*   lda #0                     ; A = value to store in loop
* .1 sta (pData),y             ; Store A through pointer
*    iny                       ; Next byte
*    dex                       ; Decrement counter (Z flag = loop condition!)
*    bne .1                    ; Branch if counter != 0
*
* DANGER: If PHX macro uses TXA (A = counter value),
*         then the code would be confused about what A contains.
*         If STZ used after DEX, Z flag would be destroyed!
*
* SAFE USAGE: Ensure A=0 is preserved, don't use unsafe macros in loop
*

*
* PATTERN 3: Accumulator holds shift/rotate result
* ============================================================
* Source: BASIC.FX/BASIC.S.XF.txt (BSX.FMT.CheckP)
*
*   lda GP.ParamS
*   asl                        ; A = A << 1
*   asl                        ; A = A << 1 (now 4 shifts)
*   asl
*   asl
*   asl
*   pha                        ; Save shifted result on stack
*   lda GP.ParamD
*   lsr                        ; A = A >> 1
*   lsr
*   pla                        ; Restore shifted value to A
*   ror                        ; Rotate with previous value
*   sta BS.WBlock.P.NUM        ; Store result
*   >STZ BS.WBlock.P.BLK       ; DANGER: This clobbers A rotation result!
*
* SAFE USAGE: If A holds shift result, use safe variants
*

*
* PATTERN 4: X/Y register save/restore with A transfer
* ============================================================
* Source: BIN/CC.S.F.txt (F.CallRetV)
*
*   ldx ZPPtr1
*   phx                        ; Save X (uses A as transfer medium!)
*   ldx ZPPtr1+1
*   phx                        ; Save another X
*   ...process code...
*   plx                        ; Restore X (A = transfer medium again)
*   stx ZPPtr2+1
*   plx
*   stx ZPPtr2                 ; DANGER: After restore, A must still work!
*   ...later: more A operations...
*
* DANGER: If unsafe PHX/PLX macros corrupt A, subsequent code fails
*
* SAFE USAGE: Use >PHX.SAFE and >PLX.SAFE around save/restore blocks
*

*
* PATTERN 5: Bit testing with TSB/TRB
* ============================================================
* Source: BIN/ASM.S.SYM.txt (SYM.NewGlobal)
*
*   lda #SYMG.F.FWREF
*   tsb SRC.ACC.F              ; Test Set Bit - sets flag in memory,
*                               ; but also affects Z flag based on result
*   ...later...
*   beq .7                     ; Branch depends on Z flag from TSB!
*
* DANGER: If unsafe TSB macro changes Z flag differently,
*         branching logic breaks. Z flag semantics differ
*         between 65C02 TSB and 6502 LDA/ORA/STA replacement!
*
* SAFE USAGE: Document TSB/TRB flag side effects carefully
*

*
* PATTERN 6: After return from subroutine (PHX pattern)
* ============================================================
* Source: ProDOS.FX/ProDOS.S.IRQ.txt (IRQ handler)
*
*   phx                        ; Save X register on stack
*   jsr IRQ.GoX               ; Call interrupt handler
*   plx                        ; Restore X from stack
*   bcc IRQ.Done              ; Branch based on carry flag
*
* ANALYSIS: After JSR, A is undefined (subroutine may clobber it).
*           Unsafe PHX/PLX is OK here because A is garbage anyway.
*           Use unsafe variant for performance.
*

*
* PATTERN 7: Zero page flag updates
* ============================================================
* Source: SHARED/X.VT.CS.txt (X.VT.GetCh.CSI)
*
*   lda #$ff
*   >STA.G X.VT.bCSIMode      ; Store flag value
*   >STZ.G X.VT.bEscMode      ; Clear escape mode flag
*   clc
*   rts
*
* ANALYSIS: Flag values being stored, A will be modified anyway before
*           any important operation. Unsafe STZ is OK here.
*
* SAFE USAGE: Unsafe variant is acceptable (A not needed)
*

* ============================================================================
* DECISION MATRIX: Which macro variant to use
* ============================================================================
*
* Question 1: After which instruction?
* ---
*   After BIT/CMP/TSB/TRB        → A contains TEST RESULT
*   After ROR/ROL/ASL/LSR        → A contains ROTATED RESULT
*   After LDA/LAX/LDX/LDY        → A/X/Y contain LOADED VALUE
*   After TAX/TAY/TXA/TYA        → A/X/Y contain TRANSFERRED VALUE
*   After addition/subtraction   → A contains ARITHMETIC RESULT
*   → USE SAFE VARIANT (preserve A)
*
*   After JSR/JMP/RTS            → A is UNDEFINED (return value unknown)
*   After BEQ/BNE/BCC/BCS        → A was already tested, don't care
*   At start of routine          → A is INCOMING PARAMETER
*   Before unconditional branch  → Path doesn't matter, A not used
*   → USE UNSAFE VARIANT (faster)
*
* Question 2: Is Z flag important next?
* ---
*   Before BEQ/BNE/BMI/BPL       → YES, preserve Z flag
*   After CMP/BIT/TSB/TRB result → YES, preserve Z flag
*   → USE SAFE VARIANTS
*
*   After operations that don't affect branches → NO
*   → USE UNSAFE VARIANTS
*
* Question 3: Are X or Y critical?
* ---
*   Loop counter in X (DEX/BNE pattern)     → YES, preserve X
*   Register save/restore pattern           → YES, preserve through sequence
*   Offset calculation in Y                 → YES, preserve Y
*   → USE SAFE.PHX/SAFE.PLX/SAFE.PHY/SAFE.PLY
*
* Question 4: Is this performance critical?
* ---
*   Hot loop (executes 1000+ times)         → Use unsafe if possible
*   Initialization code                     → Can use safe
*   Interrupt handler                       → Use unsafe (fast)
*   → BALANCE safety vs performance
*

* ============================================================================
* RECOMMENDED MACRO USAGE SUMMARY
* ============================================================================
*

* SAFE (Preserve registers) variants to use:
* ==========================================
* 1. >STZ.SAFE $addr       - After CMP/BIT, before branches
* 2. >STZ.SAFE $addr,X    - In loops where A is critical
* 3. >PHX.SAFE             - In function prologue/epilogue
* 4. >PLX.SAFE             - When restoring must not clobber A
* 5. >PHY.SAFE             - Loop variable preservation
* 6. >PLY.SAFE             - Register restoration
*
* UNSAFE (Fast, smaller) variants acceptable:
* ============================================
* 1. >STZ $addr            - After unconditional JMP
* 2. >STZ $addr            - In initialization loops
* 3. >STZ $addr            - After JSR where A undefined
* 4. >PHX                  - At start of new block
* 5. >PLX                  - At end where A not used again
*
* ============================================================================
* IMPLEMENTATION NOTES
* ============================================================================
*
* The SAFE variants use stack operations:
*
*   >STZ.SAFE $addr
*   = PHA                 ; Save A to stack
*   = LDA #$00
*   = STA $addr
*   = PLA                 ; Restore A from stack
*
*   >PHX.SAFE
*   = PHA                 ; Save A (transfer medium) to stack
*   = TXA                 ; Move X to A
*   = PHA                 ; Save X (in A) to stack
*   After restoring:
*   = PLA                 ; Get X (was in A)
*   = TAX                 ; Move back to X
*   = PLA                 ; Restore A
*
* Cost: Extra 2-4 bytes and 2-4 cycles per operation
* Safety: Guarantees A and flags are not clobbered
*

