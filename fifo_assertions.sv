module assertions #(
parameter int DW =16,
parameter int DEPTH = 8
)(

input logic clk,
input  logic               rst_n,
input  logic               push,
input  logic [DW-1:0]      push_data,
input  logic               pop,
input  logic [DW-1:0]      pop_data,
input  logic               full,
input  logic               empty,
input  logic [$clog2(DEPTH):0] count
);
localparam int CW = $clog2(DEPTH);


default clocking cb_clk@(posedge clk); endclocking
default disable iff(!rst_n);

cover_for_full1: cover property (full==1);
cover_for_full0: cover property (full==0);
cover_for_empty1: cover property (empty==1);
cover_for_empty0: cover property (empty==0);

assume_property_push: assume property (full |-> !push);
assume_property_pull: assume property (empty |-> !pop);

//AFTER RESET
ast_check_count: assert property ($rose(rst_n)|-> count ==1);
ast_check_empty: assert property ($rose(rst_n) |-> (empty==1));
ast_check_full: assert property ($rose(rst_n) |-> (full==0));

//FLag correctness
ast_flag_empty: assert property ((count ==0) |-> empty);
//ast_flag_high: assert property ((count == DEPTH-1) |-> full );
ast_flag_high: assert property ((count == DEPTH) |-> full );
ast_mutual_exclusion_empty_high: assert property (!(full && empty));

// Occupancy accounting
ast_count_values: assert property(count inside {[0:DEPTH]}) ;
ast_count_empty: assert property (empty |-> (count ==0));
//ast_count_full:assert property (full |-> (count ==DEPTH-1));
ast_count_full:assert property (full |-> (count ==DEPTH));

cover_depth_count:cover property (count ==DEPTH -1);

//No overflow / no underflow
/*
The below property cannot be checked without disabling assume_property_push
It is an illegal check but worhyt to keep it rather than saying if assume is not there chekc will ...
*/
//ast_no_write_full: assert property ((push && full) |=> $stable(fifo_inst.wr_ptr) && $stable(count));

//Data integrity check

//Symbolic data value : free at reset , then constant
logic [DW-1:0] sym_data;
asm_sym_stable : assume property ($stable(sym_data));

//accepted operations
logic wr_ok,rd_ok;
assign wr_ok = push && !full;
assign rd_ok = pop && !empty;

//-- tracker : follows ONE push of sym_data through FIFO ---
logic tracking;
logic [CW:0] ahead;

always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
                tracking <= 0;
                ahead <=0;
        end
        else if(!tracking && wr_ok && push_data == sym_data) begin
                tracking <= 1'b1;
                ahead <= count -rd_ok;
        end
        else if(tracking && rd_ok)begin
                if(ahead ==0) tracking <=0;
                ahead <= ahead -1;
end
end

//the check L when it is the tracked entry's turn , it must come out --
ast_data_integrity: assert property ((tracking && ahead ==0 && rd_ok) |-> (pop_data== sym_data));

//vacuity guard
cov_tracked_pop: cover property (tracking && ahead ==0 && rd_ok);
cov_tracked_depe: cover property (tracking && ahead >= 3);


ast_push_pull_bigh_count_stable: assert property( (push && pop) |=> $stable (count));

//Covers worth adding
cov_to_check_DEPTH: cover property(count == DEPTH);
cov_to_chcekc_DEPTH1:cover property (count == DEPTH-1);
cov_checkpush_pop_tog: cover property (push && pop);
cov_full_empty: cover property (full |=> ##[1:$](empty));
cov_back_to_back_push:cover property (push[*7]);
cov_back_to_back_pop:cover property (pop[*7]);


endmodule


bind fifo assertions  asser(.*);
