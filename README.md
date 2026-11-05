# EIE330 Lab 4: three-screen VGA controller

The active-low switching button selects **color bars -> MUST -> END -> color
bars**. Holding a qualified press produces one transition. Both press and
release qualification use the production 500,000 pixel-clock cycles (20 ms at
25 MHz). A switching key held through reset must first be released stably
before another press counts.

The top module is `vga_screens`: 50 MHz `sys_clk`, active-low `sys_rst_n` and
`key_in`, and `hsync`, `vsync`, `rgb[15:0]` outputs. `pll` and `vga_ctrl` reuse
the previous lab's divider and VGA timing; the other four modules implement
click qualification, logical/display state and screen pixels. The divider is
a flip-flop, rather than a vendor PLL primitive.

The logical state follows each accepted click. A separate displayed-state
register changes only at the start of vertical blanking so an active frame
does not mix screens. The scan uses 800 by 525 counts and 25 MHz pixels:
32 us per line, 16.8 ms per frame, about 59.524 Hz. The course refers to this
as nominal 640 by 480 at 60 Hz, with high-going sync pulses.

MUST and END use white 8 by 8 bitmaps enlarged eight times on black. The
design/font specifications and expected screen diagrams are included in the
archive. Reset clears the divider/raster as well as the controller. A virtual
display may blank while reset remains asserted; the first complete image
after release is color bars.

## Reproduce the RTL checks

Download and extract **Lab4_Screens_Source.zip** for the project with separate
`RTL/`, `sim/`, `scripts/`, `verification/` and `build/` folders. The loose
Verilog files in the repository root are convenient previews; the archive is
the complete reproducible RTL layout. From its `Lab4_Screens` directory:

```sh
bash run_tests.sh
bash scripts/synthesize.sh
python3 verification_images.py
```

The first command needs Icarus Verilog and Python 3. Synthesis needs Yosys and
Graphviz; plotting additionally needs NumPy and Pillow. Versions used for the
recorded results were Icarus 12.0 and Yosys 0.33. The testbenches create actual
VCD, CSV and frame-hex outputs; plotting reads those outputs. The supplied
waveforms and observed screen images were generated from that recorded data.
Files named `expected_*` are separate design references from the specified
bitmaps and layout, rather than observed output.
Detailed VCD windows limit file size without changing the DUT clock or debounce
parameter. Long control traces also use continuously logged event snapshots.

All six testbenches passed. The top test used production debounce counts,
checked seven accepted clicks and 15 scenarios including bounce, long hold,
reset from every state and a key held through reset, and checked every pixel
across 32 complete active frames. Independent reference images also agree
with all 307,200 captured pixels of each BARS/MUST/END screen. The logs and
source-checksum manifest record the tested files. Generic Yosys synthesis has
909 cells and 54 flip-flop bits, with no inferred latches or memories; these
figures are not Cyclone IV logic-element usage or physical timing closure.

## Scope and attribution

The design follows the EIE330 Lab 4 requirements and button lecture examples;
the divider, timing controller and MUST glyph rows reuse the stated Lab 3
work. E/N/D glyph rows were specified before implementing the pixel source.
AI assistance was used in preparing and checking the design, RTL, tests,
figures and explanatory text. The repository provides the design and recorded
checks for group review and understanding.

This public archive contains RTL, testbenches, reproduction scripts, expected
design images, recorded simulation data/plots and generic synthesis evidence.
The course C++ virtual-board runtime and its local input support, board launch
scripts, course handouts, group report, student identifiers and recordings are
excluded. The complete local group-review package retains that separate board
support and its original MIT attribution. A virtual-board window cannot
demonstrate mechanical bounce; the bounce evidence comes from simulation.
