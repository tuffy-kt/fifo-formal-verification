//==========================================================================
// fifo.sv - Synchronous FIFO (practice design for formal sign-off)
//
// NOTE: This design contains intentional bug(s). Do not read it looking for
//       the bug - verify it. Write the properties from the SPEC below and
//       let the tool tell you what is wrong.
//
//--------------------------------------------------------------------------
// SPEC
//--------------------------------------------------------------------------
// Synchronous FIFO, single clock, active-low asynchronous reset.
//
// Parameters
//   DW    : data width  (default 16)
//   DEPTH : number of entries, power of two (default 8)
//
// Ports
//   push       : write request. A write occurs on the clock edge when
//                push is high and full is low.
//   push_data  : data to write, valid when push is high.
//   pop        : read request. A read occurs on the clock edge when
//                pop is high and empty is low.
//   pop_data   : data at the head of the FIFO. Combinational: it is valid
//                in the SAME cycle as pop, whenever empty is low.
//   full       : high when the FIFO cannot accept a write this cycle.
//   empty      : high when the FIFO holds no data.
//   count      : number of entries currently stored, 0..DEPTH.
//
// Required behaviour
//   1. Data integrity and ordering: data read out equals data written in,
//      in the same order (first in, first out), with no corruption.
//   2. No overflow: a write is never performed when the FIFO is full.
//   3. No underflow: a read is never performed when the FIFO is empty.
//   4. count always equals the number of entries actually stored.
//   5. empty is high if and only if count == 0.
//      full  is high if and only if count == DEPTH.
//   6. Capacity: the FIFO can hold DEPTH entries.
//   7. A simultaneous push and pop in the same cycle is legal whenever
//      the FIFO is neither full nor empty, and leaves count unchanged.
//   8. After reset: count == 0, empty == 1, full == 0.
//
// Environment (what your assumptions may rely on)
//   - push is not asserted when full is high.
//   - pop  is not asserted when empty is high.
//   - push_data may be any value.
//   - rst_n is asserted (low) at time 0 and then stays high.
//==========================================================================

module fifo #(
  parameter int DW    = 16,
  parameter int DEPTH = 8
)(
  input  logic          clk,
  input  logic          rst_n,

  input  logic          push,
  input  logic [DW-1:0] push_data,

  input  logic          pop,
  output logic [DW-1:0] pop_data,

  output logic          full,
  output logic          empty,
  output logic [$clog2(DEPTH):0] count
);

  localparam int AW = $clog2(DEPTH);

  logic [DW-1:0] mem [DEPTH];
  logic [AW-1:0] wr_ptr;
  logic [AW-1:0] rd_ptr;

  // ---------------- write ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
    end
    else if (push && !full) begin
      mem[wr_ptr] <= push_data;
      wr_ptr      <= wr_ptr + 1'b1;
    end
  end

  // ---------------- read ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr <= '0;
    end
    else if (pop && !empty) begin
      rd_ptr <= rd_ptr + 1'b1;
    end
  end

  assign pop_data = mem[rd_ptr];

  // ---------------- occupancy ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= '0;
    end
    else begin
      case ({push && !full, pop && !empty})
        2'b10   : count <= count + 1'b1;
        2'b01   : count <= count - 1'b1;
        default : count <= count;
      endcase
    end
  end

  // ---------------- flags ----------------
 //Bug count never goes to DEPTH, so full is never asserted. It should be (count == DEPTH)
  assign full = (count == DEPTH - 1);
 //Bug empty is never asserted. It should be (count == 0)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) empty <= 1'b1;
    else        empty <= (count == 0);
  end

endmodule
