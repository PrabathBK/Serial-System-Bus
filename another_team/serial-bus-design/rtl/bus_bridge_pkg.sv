package bus_bridge_pkg;

    typedef struct packed {
        logic        is_write;
        logic [15:0] addr;
        logic [7:0]  write_data;
    } bus_bridge_req_t;

    typedef struct packed {
        logic        is_write;
        logic [7:0]  read_data;
    } bus_bridge_resp_t;

endpackage : bus_bridge_pkg
