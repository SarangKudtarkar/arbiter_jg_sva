bind fixed_prio_arbiter arbiter_sva #(
    .N (N)
) u_arbiter_sva (
    .clk   (clk),
    .rst_n (rst_n),
    .req   (req),
    .gnt   (gnt)
);
