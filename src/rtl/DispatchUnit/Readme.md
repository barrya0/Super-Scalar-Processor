## Dispatch Unit
### Design Parameters
    a.  Dependency checks

        i.  RAW

        ii. Structural Hazard

    b.  Stalls if no RS available

    c.  Updates Register Alias Table

    d.  Decoded Instruction Output

        i.  [74:0] Instruction_to_RS -- Format {RS_ID<3-bits>,
            Sources 1 & 2< valid - 1 bit, tag - 3 (for 8 RS), value -
            32>}

    e.  Dispatches to RS on positive edge of clock

    f.  Reads instructions on negative edge of clock

## Description

The Dispatch Unit is a bit more complex than the instruction queue as
it simply must do more things. Although I don't have a diagram ready
for it, you can just imagine a black box that takes instructions and
decodes them to figure out how the two instructions relate to each
other, and which reservation station can be used if at all. Among
basic I/O like clock, reset, the instructions themselves (from
instruction queue) and fetch signals, the dispatch unit also takes in
status registers from the reservation station. These flags marked as
\[1:0\] add\_done for example represent the availability of the 2 add
reservation stations. As such 'add\_done\[0\]' marks the availability
of the first add RS and so on.

Furthermore, the dispatch unit must make changes to the Register Alias
Table (RAT) as instructions are decoded and the operands are known.
The dispatch unit assigns the source operands sent to the reservation
station based on the instructions and tags the destination register in
the RAT should eventually get it's value from. This is called the RSID
and is essentially the register renaming part of dispatch. In the case
where two instructions have a Read-After-Write dependency, meaning
either source register in I2 are equal to the destination register of
I1, the I2 source register sent to the reservation station should be
assigned to the tag from the related reservation station I1.dest
should get its value from.

<div align="center">
  <img src="./duMedia/rat1.png" style="display: inline-block; margin-right: 10px;" />
  <img src="./duMedia/rat2.png" style="display: inline-block; margin-left: 10px;" />
  <p><em>Figures 3 & 4: The RAT</em></p>
</div>


Figure 3 showcases the RAT and it's structure. It is initially empty,
and all of the registers are valid with the values incrementing by one.
As you can see the tags are undefined as there are no RSIDs the
registers should get their value from. Figure 4 is after one instruction
is decoded with source operands R1 and R2 and destination register R3.
R3 now has tag 'x' which means it's been renamed to get it's value from
the 'x' RS. Of course, if there are no RSs available, the system will be
stalled as a whole.

### Dispatch Unit Simulation

    For reference the RSIDs are defined like so:

    localparam a0 = 3\'b000; localparam a1 = 3\'b001.

    localparam m0 = 3\'b010; localparam m1 = 3\'b011.

    localparam ld0 = 3\'b100; localparam ld1 = 3\'b101.

    localparam st0 = 3\'b110; localparam st1 = 3\'b111.

    Each of these represent an assignment to a Reservation Station

The first two instructions the dispatch unit receives are:

I1: add x5, x3, x4

I2: add x7, x4, x5

As you can see, there is a RAW hazard, and the dispatch unit should
recognize this.

For more information: here is a view of the RAT Table at test start.

<p align="center"> 
  <img src="./duMedia/du_sim1.png" />
</p>

It is a table of 32 registers all defined as \<Valid(1-bit),
Tag(3-bits), Value(32-bits)\>. The value increments in binary match the
register number.

Since the dispatch unit decodes instructions on the negative edge, the
internal RAW signal goes high then.

<p align="center"> 
  <img src="./duMedia/du_sim2.png" />
</p>

<p align="center"> 
  <img src="./duMedia/du_sim3.png" />
</p>

This figure shows the RAT updating itself at the destination registers
x5 from I1 and x7 from I2. As you can see, the MSB -- valid is now low
as the result has yet to be determined. The next 3-bits (the tag) are
assigned based on the reservation station the value will come from. In
this case, x5 will get its value from station 3'b000 which is a0 or the
ADD\_0 RS. x7 will get its value from the next available add RS which is
3'b001 or a0 or ADD\_1. This is circled in red, and the value has been
set to 0 because again, it has not been computed at this timestep.
Circled in purple on the top left is actually the internal register I
mentioned way earlier that keeps track of which reservation station are
in use and which are free. When I1 and I2 are dispatched, the first 2
bits are set to 1 meaning the related reservation stations are busy.

<p align="center"> 
  <img src="./duMedia/du_sim4.png" />
</p>

Furthermore, since we know that the second source register of I2 is the
one triggering the RAW dependency, the dispatch unit appropriately just
sets that I2 source to be exactly equal to the renamed destination
register at R5 in the rat table. This way, the reservation station will
know where this source operand gets it's value from and appropriately
look for matches on the common data bus.

<p align="center"> 
  <img src="./duMedia/du_sim5.png" />
</p>


The image above shows the simulated input of the add\_done signal which
should come from the reservation station. It's value of 2'b10 means that
the ADD\_0 RS is open to use but the ADD\_1 is not. We, however, have
two add instructions. This introduces a structural hazard as there isn't
enough space for both instructions to be dispatched at the same clock
cycle.

<p align="center"> 
  <img src="./duMedia/du_sim6.png" />
</p>

And so, instruction 2 must wait to be dispatched until the next add RS
is available. This is shown in the waveform above.

<p align="center"> 
  <img src="./duMedia/du_sim7.png" />
</p>

Later when both add Reservation Stations are marked as open. These 2 add
instructions can be dispatched on the same clock cycle.

    I1: add x6, x7, x4

    I2: add x29, x28, x29

<p align="center"> 
  <img src="./duMedia/du_sim8.png" />
</p>

I hope these examples were able to show the basic functionality of my
dispatch unit and it's capabilities. This design is not without it's
bugs and I'm sure I have not yet caught every test case, but I will
continue to work on refining my simulations.
