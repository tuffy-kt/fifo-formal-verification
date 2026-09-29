# fifo-formal-verification
# FIFO Formal Property Verification (FPV)

Formal verification of a parameterized synchronous FIFO using SystemVerilog Assertions (SVA). The property set covers reset behaviour, flag correctness, occupancy accounting, and end-to-end data integrity, which is proven with a symbolic data value and a tracker instead of a reference model.

The DUT contains **two intentionally injected bugs**, and both were caught by the property set. See [Bugs Detected](#bugs-detected).

**Tool:** Cadence JasperGold (FPV app)
**Language:** SystemVerilog / SVA
**Parameters:** `DW` (data width, default 16), `DEPTH` (default 8)

---

## Repository Structure

```
├── fifo.sv              # Design under test (with injected bugs)
├── fifo_assertions.sv   # Assertions, assumptions, covers + bind
└── README.md
```

The property module is attached to the design with:

```systemverilog
bind fifo assertions asser(.*);
```

---

## Verification Environment

| Item | Setting |
|---|---|
| Clock | `default clocking @(posedge clk)` |
| Reset | Active-low `rst_n`; all properties use `default disable iff (!rst_n)` |
| Occupancy signal | `count` is `$clog2(DEPTH)+1` bits wide, so it can represent 0 to `DEPTH` |

### Assumptions (input constraints)

| Name | Property | Purpose |
|---|---|---|
| `assume_property_push` | `full \|-> !push` | Environment never pushes into a full FIFO |
| `assume_property_pull` | `empty \|-> !pop` | Environment never pops from an empty FIFO |
| `asm_sym_stable` | `$stable(sym_data)` | Symbolic data value is free at reset, then held constant |

Because overflow and underflow are assumed away, a direct "no write when full" check (`ast_no_write_full`) is kept in the file but commented out. It can only be run with `assume_property_push` disabled.

---

## Assertions

### Reset behaviour

| Name | Checks |
|---|---|
| `ast_check_count` | `count` is 0 when reset is released |
| `ast_check_empty` | `empty` is asserted when reset is released |
| `ast_check_full` | `full` is deasserted when reset is released |

### Flag correctness

| Name | Checks |
|---|---|
| `ast_flag_empty` | `count == 0` implies `empty` |
| `ast_flag_high` | `count == DEPTH` implies `full` |
| `ast_mutual_exclusion_empty_high` | `full` and `empty` are never high together |

### Occupancy accounting

| Name | Checks |
|---|---|
| `ast_count_values` | `count` always stays within `[0:DEPTH]` |
| `ast_count_empty` | `empty` implies `count == 0` |
| `ast_count_full` | `full` implies `count == DEPTH` |
| `ast_push_pull_bigh_count_stable` | Simultaneous push and pop leave `count` unchanged |

Together, the flag and occupancy checks prove `empty ⇔ count == 0` and `full ⇔ count == DEPTH` in both directions.

### Data integrity

Proving that every word comes out in order without a scoreboard uses a **symbolic data tracker**:

1. `sym_data` is an unconstrained value that the solver may choose freely, then held constant.
2. When a write of `sym_data` is accepted (`wr_ok`) and nothing is being tracked yet, `tracking` is set and `ahead` records how many entries are in front of it (`count - rd_ok`).
3. Each accepted read (`rd_ok`) decrements `ahead`.
4. When `ahead == 0` and a read is accepted, the tracked entry must be the one coming out:

```systemverilog
ast_data_integrity: assert property
  ((tracking && ahead == 0 && rd_ok) |-> (pop_data == sym_data));
```

Because `sym_data` can take any value, a full proof covers **every** data value at **every** FIFO position. This checks both data correctness and ordering.

---

## Cover Properties

Covers confirm that the assumptions don't over-constrain the design and that the assertions are not passing vacuously.

| Name | Scenario reached |
|---|---|
| `cover_for_full1` / `cover_for_full0` | `full` toggles both ways |
| `cover_for_empty1` / `cover_for_empty0` | `empty` toggles both ways |
| `cover_depth_count`, `cov_to_chcekc_DEPTH1` | FIFO is one entry from full |
| `cov_to_check_DEPTH` | FIFO fills completely |
| `cov_checkpush_pop_tog` | Simultaneous push and pop |
| `cov_full_empty` | FIFO goes from full back to empty |
| `cov_back_to_back_push` / `cov_back_to_back_pop` | 7 consecutive pushes / pops |
| `cov_tracked_pop` | **Vacuity guard:** tracked entry is actually popped |
| `cov_tracked_depe` | **Vacuity guard:** tracked entry has 3 or more entries ahead of it |

---

## Bugs Detected

| # | Bug | Caught by | Counterexample |
|---|---|---|---|
| 1 | `full` is decoded as `count == DEPTH-1`, so the FIFO holds only DEPTH-1 entries | `ast_count_full`; `cov_to_check_DEPTH` unreachable | After 7 pushes, `full` rises while `count == 7` |
| 2 | `empty` is registered, so it lags `count` by one cycle | `ast_count_empty`, `ast_flag_empty` | First push into an empty FIFO: `count == 1` while `empty` is still high. Last pop: `count == 0` while `empty` is low, so a pop in that cycle underflows `count` |

**Fixes:**

```systemverilog
assign full  = (count == DEPTH);
assign empty = (count == 0);
```

With bug 1 present, `ast_flag_high` passes *vacuously*, because `count` never reaches `DEPTH`. The unreachable `cov_to_check_DEPTH` cover is what exposes it, which shows why covers matter as much as assertions.

---

## How to Run

```tcl
analyze -sv fifo.sv fifo_assertions.sv
elaborate -top fifo
clock clk
reset -expression !rst_n
prove -all
```

---

## Future Work

- Extend to an asynchronous (dual-clock) FIFO
- Add a SymbiYosys flow so the proof can be reproduced with open-source tools
