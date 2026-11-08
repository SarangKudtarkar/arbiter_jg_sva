module arbiter_sva #(
    parameter N      = 8,
    parameter IDX_W  = $clog2(N),
    parameter CNT_W  = $clog2(N+1)
)(
    input logic         clk,
    input logic         rst_n,
    input logic [N-1:0] req,
    input logic [N-1:0] gnt
);

    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // ----------------------------------------------
    // Environment assumptions
    //  - a granted request is deasserted in the next cycle
    //  - a request that was not granted stays asserted
    //    (this is what makes "outstanding" well defined)
    // ----------------------------------------------
    m_drop_after_gnt: assume property (
        1'b1 |=> ((req & $past(gnt)) == '0)
    );

    m_hold_until_gnt: assume property (
        1'b1 |=> (($past(req) & ~$past(gnt) & ~req) == '0)
    );

    // ----------------------------------------------
    // Symbolic requester (symbolic constant)
    // ----------------------------------------------
    logic [IDX_W-1:0] sym_req;

    m_sym_stable: assume property (disable iff (1'b0) $stable(sym_req));
    m_sym_range:  assume property (disable iff (1'b0) sym_req < N);

    // free input, undriven: each cycle JG may choose 0 or 1
    logic pick;

    // ----------------------------------------------
    // Mask of requesters with higher priority than sym_req
    // ----------------------------------------------
    logic [N-1:0] hp_mask;

    always_comb begin
        for (int i = 0; i < N; i++)
            hp_mask[i] = (i < sym_req);
    end

    // ----------------------------------------------
    // Outstanding high priority request counter
    // ----------------------------------------------
    logic [N-1:0]     req_q;       // previous cycle request
    logic             trk;         // sticky: tracking a sym_req request
    logic [CNT_W-1:0] out_q;       // outstanding after previous cycle

    logic             sym_rise;
    logic             sample_in;   // start tracking this occurrence
    logic             trk_now;     // tracking, including the sample cycle
    logic [CNT_W-1:0] new_hp;      // high priority requests added this cycle
    logic [CNT_W-1:0] out_now;     // outstanding in this cycle (before grant)
    logic [CNT_W-1:0] gnt_hp;      // high priority grants this cycle

    assign sym_rise  = req[sym_req] && !req_q[sym_req];
    assign sample_in = sym_rise && pick && !trk;
    assign trk_now   = trk || sample_in;

    // sample cycle: everything pending in the mask counts
    // later cycles: only newly arrived requests count
    assign new_hp  = trk ? $countones(req & ~req_q & hp_mask)
                         : $countones(req & hp_mask);

    assign out_now = (trk ? out_q : '0) + new_hp;
    assign gnt_hp  = $countones(gnt & hp_mask);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_q <= '0;
            trk   <= 1'b0;
            out_q <= '0;
        end
        else begin
            req_q <= req;

            if (trk_now && gnt[sym_req]) begin
                // sym_req served: stop, a later occurrence can be picked
                trk   <= 1'b0;
                out_q <= '0;
            end
            else if (trk_now) begin
                trk   <= 1'b1;
                out_q <= out_now - gnt_hp;
            end
        end
    end

    // ----------------------------------------------
    // Basic arbiter properties
    // ----------------------------------------------
    a_gnt_onehot0:     assert property ($onehot0(gnt));
    a_gnt_subset_req:  assert property ((gnt & ~req) == '0);

    // ----------------------------------------------
    // Core check: grant at the cycle the counter drains
    // ----------------------------------------------
    a_sym_granted: assert property (
        (trk_now && req[sym_req] && (out_now == '0)) |-> gnt[sym_req]
    );

    // Helper invariant: the counter equals the number of high priority
    // requests that are really pending (validates the counter model and
    // the environment assumptions, and helps convergence)
    a_cnt_matches_pending: assert property (
        trk_now |-> (out_now == $countones(req & hp_mask))
    );

    // ----------------------------------------------
    // Forward progress
    // ----------------------------------------------
    // work conserving, zero latency: any request produces a grant
    a_work_conserving: assert property (
        (|req) |-> (|gnt)
    );

    // Starvation of low priority requesters is legal for a fixed
    // priority arbiter, so liveness needs a fairness assumption:
    // the higher priority region is empty infinitely often.
    m_hp_quiet: assume property (
        always (s_eventually ((req & hp_mask) == '0))
    );

    a_sym_eventually_granted: assert property (
        req[sym_req] |-> s_eventually gnt[sym_req]
    );

    // ----------------------------------------------
    // Spurious behaviour (nothing granted without a cause)
    // ----------------------------------------------
    a_no_gnt_without_req: assert property (
        !(|req) |-> !(|gnt)
    );

    // sym_req is never granted ahead of an outstanding higher priority request
    a_sym_no_early_gnt: assert property (
        (trk_now && gnt[sym_req]) |-> (out_now == '0)
    );

    // ----------------------------------------------
    // Cover properties (reachability / vacuity checks)
    // ----------------------------------------------
    c_sym_sampled:     cover property (sample_in);
    c_sym_lowest:      cover property (sample_in && (sym_req == N-1));
    c_sym_waits:       cover property (trk_now && req[sym_req] && (out_now != '0));
    c_hp_arrives_late: cover property (trk && ((req & ~req_q & hp_mask) != '0));
    c_sym_waited_gnt:  cover property (
        (trk_now && (out_now != '0)) ##[1:$] (trk_now && gnt[sym_req])
    );
    c_sym_immediate:   cover property (sample_in && gnt[sym_req]);
    c_all_requesting:  cover property (&req);

endmodule
