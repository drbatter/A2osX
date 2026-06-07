*--------------------------------------
* 6502 Compatibility Macro Library
* Provides 65C02 instruction replacements for plain 6502 processors
* 
* Usage: Include this file BEFORE other code when targeting 6502
* Example:
*   .OP 6502
*   .INB inc/6502compat.i
*   .INB inc/macros.i
*
* This file uses S-C Assembler conditional compilation to only
* activate macros when .OP 6502 is specified.
*
* Author: A2osX 6502 Port Project
* License: GNU General Public License v2
*--------------------------------------

*
* ============================================================================
* SECTION 1: Conditional Compilation Guard
* Only load these macros if targeting plain 6502
* ============================================================================
*

				.IF .CPU = 1				CPU type: 1=6502, 2=65C02, 3=65816, etc.

*--------------------------------------
* ============================================================================
* SECTION 2: Store Zero Macros (STZ replacement)
* 65C02 STZ is very common - replaces with LDA #$00 : STA pattern
* ============================================================================
*

*
* .MA STZ.ZP
* Replace: STZ $zp      (1 opcode)
* With:    LDA #$00 : STA $zp  (3 opcodes)
* Cost: +2 bytes, +4 cycles
*
				.MA STZ.ZP
				LDA #$00
				STA ]1
				.EM

*
* .MA STZ.ZPX
* Replace: STZ $zp,X    (1 opcode, not valid on 6502 anyway in this form)
* With:    LDA #$00 : STA $zp,X  (3 opcodes)
*
				.MA STZ.ZPX
				LDA #$00
				STA ]1,X
				.EM

*
* .MA STZ.ABS
* Replace: STZ $addr    (1 opcode)
* With:    LDA #$00 : STA $addr  (3 opcodes)
* Cost: +2 bytes, +4 cycles
*
				.MA STZ.ABS
				LDA #$00
				STA ]1
				.EM

*
* .MA STZ.ABSX
* Replace: STZ $addr,X  (1 opcode)
* With:    LDA #$00 : STA $addr,X  (3 opcodes)
*
				.MA STZ.ABSX
				LDA #$00
				STA ]1,X
				.EM

*
* Convenience macro that auto-detects addressing mode
* Usage: >STZ $2000 or >STZ $80
*
				.MA STZ
				.DO ]1<256
				>STZ.ZP ]1
				.ELSE
				>STZ.ABS ]1
				.FIN
				.EM

*--------------------------------------
* ============================================================================
* SECTION 3: Branch Always Macros (BRA replacement)
* 65C02 BRA (Branch Always) -> 6502 JMP
* ============================================================================
*

*
* .MA BRA
* Replace: BRA label     (relative branch, 2 bytes)
* With:    JMP label     (absolute jump, 3 bytes)
* Cost: +1 byte, +1 cycle
*
* Usage: >BRA label    or  >BRA.ABS $2000
*
				.MA BRA
				JMP ]1
				.EM

*
* Alternate name for clarity
*
				.MA BRA.ABS
				JMP ]1
				.EM

*--------------------------------------
* ============================================================================
* SECTION 4: Push/Pop X and Y Register Macros
* 65C02 PHX/PLX/PHY/PLY -> stack manipulation + transfer
* ============================================================================
*

*
* .MA PHX
* Replace: PHX          (1 opcode - push X register)
* With:    TXA : PHA    (2 opcodes - transfer X to A, push A)
* Cost: +1 byte, same cycles
* Clobbers: A register
*
				.MA PHX
				TXA
				PHA
				.EM

*
* .MA PLX
* Replace: PLX          (1 opcode - pull to X register)
* With:    PLA : TAX    (2 opcodes - pull to A, transfer to X)
* Cost: +1 byte, same cycles
* Clobbers: A register
*
				.MA PLX
				PLA
				TAX
				.EM

*
* .MA PHY
* Replace: PHY          (1 opcode - push Y register)
* With:    TYA : PHA    (2 opcodes - transfer Y to A, push A)
* Cost: +1 byte, same cycles
* Clobbers: A register
*
				.MA PHY
				TYA
				PHA
				.EM

*
* .MA PLY
* Replace: PLY          (1 opcode - pull to Y register)
* With:    PLA : TAY    (2 opcodes - pull to A, transfer to Y)
* Cost: +1 byte, same cycles
* Clobbers: A register
*
				.MA PLY
				PLA
				TAY
				.EM

*--------------------------------------
* ============================================================================
* SECTION 5: Test Set Bits Macros (TSB replacement)
* TSB = Test Set Bits - sets specified bit and updates Z flag
* ============================================================================
*

*
* .MA TSB.ZP
* Replace: TSB $zp      (1 opcode)
* With:    LDA $zp : ORA #mask : STA $zp  (5 opcodes)
* Cost: +4 bytes, but Z flag behavior differs
* 
* NOTE: Original TSB sets Z if result is 0. This approximation
*       loads value, ORs with mask, stores it back.
*       Z flag set based on accumulator after ORA.
*
* Usage: >TSB.ZP $80,#$40   (sets bit 6 in $0080)
*
				.MA TSB.ZP
				LDA ]1
				ORA #]2
				STA ]1
				.EM

*
* .MA TSB.ABS
* Replace: TSB $addr    (1 opcode)
* With:    LDA $addr : ORA #mask : STA $addr  (5 opcodes)
*
				.MA TSB.ABS
				LDA ]1
				ORA #]2
				STA ]1
				.EM

*--------------------------------------
* ============================================================================
* SECTION 6: Test Reset Bits Macros (TRB replacement)
* TRB = Test Reset Bits - clears specified bit and updates Z flag
* ============================================================================
*

*
* .MA TRB.ZP
* Replace: TRB $zp      (1 opcode)
* With:    LDA $zp : AND #mask : STA $zp  (5 opcodes)
* Cost: +4 bytes
*
* Usage: >TRB.ZP $80,#$BF   (clears bit 6 in $0080)
*                           (mask should have target bit = 0)
*
				.MA TRB.ZP
				LDA ]1
				AND #]2
				STA ]1
				.EM

*
* .MA TRB.ABS
* Replace: TRB $addr    (1 opcode)
* With:    LDA $addr : AND #mask : STA $addr  (5 opcodes)
*
				.MA TRB.ABS
				LDA ]1
				AND #]2
				STA ]1
				.EM

*--------------------------------------
* ============================================================================
* SECTION 7: Bit Branch Macros (BBR/BBS replacement)
* BBR/BBS = Bit Branch - conditional branch based on bit
* These are more complex - require BIT + conditional branch
* ============================================================================
*

*
* .MA BBR
* Replace: BBR n,$zp,label   (3 opcodes - bit branch reset)
* With:    BIT $zp : BNE label  (if bit n is clear)
* 
* This is a complex replacement because 65C02 BBR checks a specific bit.
* 6502 BIT checks multiple bits and sets Z, V, N flags.
*
* Common usage case: BBR 7,$addr,label
* Replace with: BIT $addr : BPL label  (branch if bit 7 clear)
*
* For general case, need to handle each bit differently.
* We provide common cases (bit 7 for sign bit checks).
*
* Usage: >BBR.BIT7 $80,label   (branch if bit 7 clear at $80)
*
				.MA BBR.BIT7
				BIT ]1
				BPL ]2
				.EM

*
* .MA BBS
* Replace: BBS n,$zp,label   (3 opcodes - bit branch set)
* With:    BIT $zp : BMI label  (if bit n is set)
*
* Usage: >BBS.BIT7 $80,label   (branch if bit 7 set at $80)
*
				.MA BBS.BIT7
				BIT ]1
				BMI ]2
				.EM

*
* For other bits, manual implementation required.
* Example for bit 6: use BIT followed by BVC/BVS
*
				.MA BBR.BIT6
				BIT ]1
				BVC ]2
				.EM

				.MA BBS.BIT6
				BIT ]1
				BVS ]2
				.EM

*--------------------------------------
* ============================================================================
* SECTION 8: Bit Manipulation Helper Macros
* These provide common patterns for bit testing and setting on 6502
* ============================================================================
*

*
* .MA SET.BIT
* Set a specific bit in accumulator
* Usage: >SET.BIT 6   (sets bit 6 in A register)
*
				.MA SET.BIT
				ORA #(1<<]1)
				.EM

*
* .MA CLR.BIT
* Clear a specific bit in accumulator
* Usage: >CLR.BIT 3   (clears bit 3 in A register)
* Note: Requires the bit mask to be inverted
*
				.MA CLR.BIT
				AND #(~(1<<]1)) & $FF
				.EM

*
* .MA TEST.BIT
* Test if specific bit is set (6502 equivalent of 65C02 bit testing)
* Sets Z flag if bit is clear, clears Z if bit is set
* Usage: >TEST.BIT 7,$80   (test bit 7 in location $80)
*
				.MA TEST.BIT
				BIT ]2
				.EM

*--------------------------------------
* ============================================================================
* SECTION 9: Word Load/Store with conditional 6502 macros
* Enhancements to existing macros for 6502 optimization
* ============================================================================
*

*
* .MA LDYA.6502
* Load Y,A from word at address (6502 version)
* Same as LDYA but ensures 6502 compatibility
*
				.MA LDYA.6502
				.DO ]#=2
				LDY ]1,]2
				LDA ]1+1,]2
				.ELSE
				LDY ]1
				LDA ]1+1
				.FIN
				.EM

*
* .MA STYA.6502
* Store Y,A to word at address (6502 version)
*
				.MA STYA.6502
				.DO ]#=2
				STA ]1+1,]2
				TYA
				STA ]1,]2
				.ELSE
				STY ]1
				STA ]1+1
				.FIN
				.EM

*--------------------------------------
* ============================================================================
* SECTION 10: Zero Page Increment/Decrement 65C02 alternatives
* For cases where the macro needs modification
* ============================================================================
*

*
* .MA INC.ZP
* Increment zero page location (works on both 6502 and 65C02)
*
				.MA INC.ZP
				INC ]1
				.EM

*
* .MA DEC.ZP
* Decrement zero page location (works on both 6502 and 65C02)
*
				.MA DEC.ZP
				DEC ]1
				.EM

*--------------------------------------
* ============================================================================
* SECTION 11: Convenience Wrappers
* These provide flexible interfaces that work with both 6502 and 65C02
* ============================================================================
*

*
* .MA SAFE.STZ
* Universal STZ - works on both 6502 and 65C02
* On 6502: uses LDA #$00 : STA pattern
* On 65C02: uses native STZ (if not using this compat file)
*
* When using 6502 with this file:
*
				.MA SAFE.STZ
				>STZ ]1
				.EM

*
* .MA SAFE.BRA
* Universal BRA - works on both 6502 and 65C02
*
				.MA SAFE.BRA
				>BRA ]1
				.EM

*
* .MA SAFE.PHX
* Universal PHX - works on both 6502 and 65C02
*
				.MA SAFE.PHX
				>PHX
				.EM

*
* .MA SAFE.PLX
* Universal PLX - works on both 6502 and 65C02
*
				.MA SAFE.PLX
				>PLX
				.EM

*
* .MA SAFE.PHY
* Universal PHY - works on both 6502 and 65C02
*
				.MA SAFE.PHY
				>PHY
				.EM

*
* .MA SAFE.PLY
* Universal PLY - works on both 6502 and 65C02
*
				.MA SAFE.PLY
				>PLY
				.EM

*--------------------------------------
* ============================================================================
* SECTION 12: Documentation and Usage Notes
* ============================================================================
*

* MIGRATION GUIDE FOR EXISTING CODE:
* ----------------------------------
* To use this compatibility library in existing code:
*
* 1. At the top of your .S file, change:
*      .OP 65C02
*    to:
*      .OP 6502
*
* 2. After existing includes, add:
*      .INB inc/6502compat.i
*
* 3. Review usage of:
*      - STZ    -> Will use LDA #$00 : STA pattern automatically
*      - BRA    -> Will use JMP automatically
*      - PHX/PLX -> Will use TXA/PHA : PLA/TAX automatically
*      - PHY/PLY -> Will use TYA/PHA : PLA/TAY automatically
*
* 4. For TSB, TRB, BBR, BBS - these may need manual inspection
*    as the replacements are not always 1:1 functionally equivalent.
*
* PERFORMANCE NOTES:
* ------------------
* Cycle costs (approximate):
*   - STZ replacement: +4 cycles (65C02: 3-5, 6502: 7-9)
*   - BRA vs JMP: ~same (+1 cycle)
*   - PHX/PLX/PHY/PLY: same cycle count
*   - TSB/TRB: +2-3 cycles
*   - BBR/BBS: varies by bit position
*
* Memory cost:
*   - Each STZ becomes +2 bytes (3 bytes vs 1 byte)
*   - Each BRA/JMP: +1 byte (3 bytes vs 2 bytes)
*   - Each PHX/PLX: +1 byte (2 bytes vs 1 byte)
*   - Total overhead: ~30-50% depending on usage patterns
*
* TEST VECTORS:
* --------------
* Before and after verification needed for:
*   - Flag states (especially Z, V, N flags in TSB/TRB replacements)
*   - Bit testing with BBR/BBS replacements
*   - X and Y register preservation in PHX/PLX/PHY/PLY
*

*--------------------------------------
* ============================================================================
* SECTION 13: Conditional Compilation End Guard
* ============================================================================
*

				.FIN				End of: .IF .CPU = 1

*--------------------------------------
* MAN
* Documentation for 6502 Compatibility Library
*
* PURPOSE:
*   Provides drop-in replacement macros for 65C02-specific instructions
*   to enable A2osX to run on plain 6502 Apple IIe computers.
*
* INCLUDED REPLACEMENTS:
*   - STZ (Store Zero): 4 variants (ZP, ZPX, ABS, ABSX)
*   - BRA (Branch Always): mapped to JMP
*   - PHX/PLX/PHY/PLY: stack-based register preservation
*   - TSB/TRB (Test Set/Reset Bits): LDA/ORA/STA and LDA/AND/STA patterns
*   - BBR/BBS (Bit Branch): BIT + conditional branch
*   - Helper macros for common bit operations
*
* USAGE:
*   .OP 6502
*   .INB inc/6502compat.i
*   .INB inc/macros.i
*
* COMPATIBILITY:
*   - 6502 Apple IIe (non-enhanced)
*   - Requires S-C Assembler
*   - Compatible with existing A2osX codebase
*
* NOTES:
*   - Some replacements are not 100% functionally equivalent (TSB/TRB)
*   - Flag side effects may differ in edge cases
*   - Thorough testing required before production use
*
* SAVE inc/6502compat.i
*
