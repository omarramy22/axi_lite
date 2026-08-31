# Register Map

8 x 32-bit registers, word-aligned, all plain read/write.

| Offset | Name    | Type | Reset | Notes |
|--------|---------|------|-------|-------|
| 0x00   | REG0    | RW   | 0x0   | |
| 0x04   | REG1    | RW   | 0x0   | |
| 0x08   | REG2    | RW   | 0x0   | |
| 0x0C   | REG3    | RW   | 0x0   | |
| 0x10   | REG4    | RW   | 0x0   | |
| 0x14   | REG5    | RW   | 0x0   | |
| 0x18   | REG6    | RW   | 0x0   | |
| 0x1C   | REG7    | RW   | 0x0   | |
| 0x20+  | --      | --   | --    | unmapped, returns DECERR on read or write |

## Address decode

- Byte-addressed bus, word-aligned registers -> bottom 2 bits of the
  address are ignored, next 3 bits select the register (`addr[4:2]`).
- Any address where `addr[31:5]` is non-zero is out of range and gets
  `DECERR` on both the read and write path. The register file itself
  is untouched by an out-of-range write.

## Byte strobes

Every register supports partial writes via `wstrb`. Only the bytes
with their corresponding strobe bit set are updated; the rest of the
register keeps its previous value.

## Response codes

| Code | Meaning | When |
|------|---------|------|
| `OKAY` (2'b00)   | normal access | address in range |
| `DECERR` (2'b11) | address doesn't map to anything | address out of range, read or write |

`SLVERR` and `EXOKAY` are defined in `axi_lite_pkg.v` per the AXI4-Lite
spec but aren't produced by this slave, since every in-range register
is plain RW (no read-only or write-1-to-clear registers in this
design).
