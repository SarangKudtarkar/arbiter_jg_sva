module fixed_prio_arbiter #(
    parameter N = 8
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic [N-1:0] req,
    output logic [N-1:0] gnt
);

    // scan from the lowest priority up, so the lowest index wins last
    always_comb begin
        gnt = '0;
        for (int i = N-1; i >= 0; i--) begin
            if (req[i]) begin
                gnt    = '0;
                gnt[i] = 1'b1;
            end
        end
    end

endmodule
