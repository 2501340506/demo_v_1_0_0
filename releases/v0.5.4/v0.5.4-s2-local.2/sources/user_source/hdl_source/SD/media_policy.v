module media_policy (
    input wire clk, input wire rst,
    input wire next_event, input wire previous_event,
    input wire auto_toggle_event, input wire combo_event,
    output wire next_request, output wire previous_request,
    output wire auto_toggle_request, output wire combo_request
);
    assign next_request = next_event;
    assign previous_request = previous_event;
    assign auto_toggle_request = auto_toggle_event;
    assign combo_request = combo_event;
endmodule
