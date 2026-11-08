clear -all

analyze -sv12 \
    rtl/fixed_prio_arbiter.sv \
    formal/arbiter_sva.sv \
    formal/arbiter_bind.sv

# DUT is the top; checker comes in through the bind
elaborate -top fixed_prio_arbiter

clock clk
reset -expression {!rst_n}

# proves asserts and checks reachability of covers
prove -all

report -summary
report -results
