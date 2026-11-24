
package test_fe_types_pkg;
  import config_pkg::*;
  import ariane_pkg::*;

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  typedef struct packed {
    logic                    valid;
    cf_t                     cf;
    logic [CVA6Cfg.VLEN-1:0] predict_address;
  } branchpredict_sbe_t;

  typedef struct packed {
    logic [CVA6Cfg.XLEN-1:0] cause;
    logic [CVA6Cfg.XLEN-1:0] tval;
    logic [CVA6Cfg.GPLEN-1:0] tval2;
    logic [31:0] tinst;
    logic gva;
    logic valid;
    logic timing;
  } exception_t;

  typedef struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] pc;
    logic [CVA6Cfg.VLEN-1:0] target_address;
    logic                    is_mispredict;
    logic                    is_taken;
    cf_t                     cf_type;
  } bp_resolve_t;

  typedef struct packed {
    logic                    req;
    logic                    kill_s1;
    logic                    kill_s2;
    logic                    spec;
    logic [CVA6Cfg.VLEN-1:0] vaddr;
  } icache_dreq_t;

  typedef struct packed {
    logic                                ready;
    logic                                valid;
    logic [CVA6Cfg.FETCH_WIDTH-1:0]      data;
    logic [CVA6Cfg.FETCH_USER_WIDTH-1:0] user;
    logic [CVA6Cfg.VLEN-1:0]             vaddr;
    exception_t                          ex;
  } icache_drsp_t;

  typedef struct packed {
    logic [CVA6Cfg.VLEN-1:0] address;
    logic [31:0] instruction;
    branchpredict_sbe_t     branch_predict;
    exception_t             ex;
  } fetch_entry_t;
  typedef struct packed {
    logic valid;
    logic [CVA6Cfg.VLEN-1:0] ra;
  } ras_t;
endpackage
