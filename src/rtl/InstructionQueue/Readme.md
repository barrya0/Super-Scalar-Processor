## Instruction Queue
### Design Parameters
1.  Instruction Package

    a.  Stores RISC-V instruction fields

        i.  Op

        ii. Rd

        iii. Funct3

        iv. Rs1

        v.  Rs2

        vi. Funct7

        vii. Imm

2.  Instruction Queue:

        a.  Queue Depth - 16

        b.  Utilizes 2 parallel instruction 1 and instruction 2 registers as
            the queues, think of a 2x16 table or matrix.

        c.  Read and Write pointers

        d.  Uses RISC-V instruction package to parse through instructions
            and set different fields such as op, rs1, rs2, etc.

        e.  Stores instructions on positive edge of clock

        f.  Outputs instructions on negative edge of clock

### Description

<p align="center"> 
  <img src="./iqMedia/instrqu.png" />
</p>
<p align="center"><em>Figure 2: Instruction Queue Structure</em></p>


Hinted at by Figure 2 the instruction queue follows a very simple
design. As I've mentioned previously however, I designed the queue to
be 2 separate arrays in parallel that represent pairs of instructions.
So essentially at every positive edge of the clock cycle, my testbench
drives a 'valid' instruction 1 and instruction 2 bit that enables the
queue to begin filling itself with instructions. These instructions
are loaded from a test file with assembly instructions decoded into
machine code.

When the dispatch unit sends a high fetch\_1 or fetch\_2 signal, the
instruction queue will respond on the next negative edge of the clock
with the RISC-V form of the instructions. Meaning the 32-bit machine
code realized into the different fields of a RISC-V instruction (op,
rs1, rs2, etc.). I chose to do this to improve clock cycle
utilization. And so naturally, on the rising edge, the write pointers
will increment if the valid signal is high, and the read pointers will
also increment if the fetch signal from the dispatch unit is high.
When the read pointers and write pointers are equal, the queue is full
and must be emptied. With my current design, when the read/write
pointers assume the max value they can take, they reset to 0 and the
queues simply \'refresh\' themselves from the head again when the
queue is full, this seems to be a functioning version of the queue \--
will have to figure if I want the queue to actually flush.

### Instruction Queue Simulation

<div align="center">
  <img src="./iqMedia/instr_sim1.png" style="display: inline-block; margin-right: 10px;" />
  <img src="./iqMedia/instr_sim2.png" style="display: inline-block; margin-left: 10px;" />
</div>
Initially instruction queues 1 and 2, these 'columns' are empty or
undefined as the reset signal is asserted at the beginning of simulation
time for a little over 1 clock cycle.

<p align="center"> 
  <img src="./iqMedia/instr_sim3.png" />
</p>

These two instructions are first to be read.

<p align="center"> 
  <img src="./iqMedia/instr_sim4.png" />
</p>

On the next positive edge of the clock, the testbench simulates a valid
instruction1 and valid instruction2. The queue recognizes these flags
and begins filling the queue. I randomized these flags but eventually
later in simulation time, the queues became increasingly full of
instructions.

<p align="center"> 
  <img src="./iqMedia/instr_sim5.png" />
</p>

On the next fetch from the dispatch unit and negative edge of the clock,
instr\_1 and instr\_2 have values based on the fields of a RISC-V
instruction.

<p align="center"> 
  <img src="./iqMedia/instr_sim6.png" />
</p>

<p align="center"> 
  <img src="./iqMedia/instr_sim7.png" />
</p>

The immediate is not shown as this as an R-type instruction with no
immediate field. Furthermore, the queue is able to recognize two
different instructions and dispatch them at the same clock cycle.

<p align="center"> 
  <img src="./iqMedia/instr_sim8.png" />
</p>

At a later timestep, the columns have more instructions. Like so:

<p align="center"> 
  <img src="./iqMedia/instr_sim9.png" />
</p>

I hope this was enough to show the ability of the queue to load and
shift instructions and send them to the dispatch unit if requested.
