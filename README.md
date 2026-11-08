# Arbiter Formal Verification (JasperGold SVA style)

Generic arbiter check using a symbolic requester and an outstanding
request counter, applied to a fixed priority arbiter (req[0] highest).
Same layout as fifo_jg_sva / async_fifo_jg_sva.

## Files

- rtl/fixed_prio_arbiter.sv    DUT (parameter N, default 8)
- formal/arbiter_sva.sv        SVA checker (assume / assert / cover + counter model)
- formal/arbiter_bind.sv       bind of checker into the arbiter
- scripts/arbiter_formal.tcl   JasperGold script

## Run

From the repository root:

    jg scripts/arbiter_formal.tcl   (or: jg, then source scripts/arbiter_formal.tcl)

## Approach

1. sym_req is a free signal (symbolic constant, $stable assume): JG picks
   one requester per proof, so one run covers every requester.
2. hp_mask marks the requesters that must be served before sym_req
   (fixed priority: index < sym_req). This is the only arbiter specific part.
3. When a sym_req request is picked (sample_in), the counter starts with
   the high priority requests already pending, then adds newly arrived
   high priority requests and subtracts high priority grants.
   High priority requests arriving later (e.g. req[0] showing up while
   sym_req waits) correctly delay sym_req.
4. trk is the sticky "sampled in" flag. The check is
   "trk && req[sym_req] && outstanding == 0 |-> gnt[sym_req]".
5. pick is a free non-deterministic input, so the tracked occurrence can
   be the first, second, ... request of sym_req. Tracking restarts after
   sym_req is served, so later occurrences are also covered.

## What is checked

- gnt one-hot or zero, gnt subset of req, no grant without a request.
- Core: sym_req is granted in the cycle the outstanding count is zero,
  and never granted earlier (a_sym_granted, a_sym_no_early_gnt).
- Helper invariant: counter equals the really pending high priority
  requests (a_cnt_matches_pending).
- Forward progress: work conserving with zero latency. Liveness for
  sym_req needs fairness (m_hp_quiet), since starving low priority
  requesters is legal for a fixed priority arbiter.

## Notes

- Assumptions: a granted request drops in the next cycle, and a request
  that is not granted stays asserted (m_drop_after_gnt, m_hold_until_gnt).
  The second one is needed for "outstanding" to be well defined.
- sym_req and pick are undriven signals in the checker, treated by JG as
  free inputs; sym_req is made constant with a $stable assume.
- For other arbiters only hp_mask (and possibly the grant timing) changes:
  - round robin: mask depends on the last granted requester
  - first come first served: mask is the set of older requests
  - weighted priority: mask follows the weights
- Review the cover results first: a vacuous cover means the assertions
  are not exercising the interesting behavior (c_hp_arrives_late and
  c_sym_lowest are the interesting ones here).
- Liveness properties need the JG liveness engines and run slower than
  the safety asserts.
