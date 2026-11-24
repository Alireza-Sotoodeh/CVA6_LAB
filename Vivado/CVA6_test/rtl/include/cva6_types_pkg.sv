// Generated unified types package for CVA6 in Vivado 2019.2
package cva6_types_pkg;
  import config_pkg::*;
  import ariane_pkg::*;
  import wt_cache_pkg::*;
  import axi_pkg::*;
  `include "rvfi_types.svh"
  `include "cvxif_types.svh"

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  typedef `RVFI_PROBES_INSTR_T(CVA6Cfg) rvfi_probes_instr_t;

  typedef `RVFI_PROBES_CSR_T(CVA6Cfg) rvfi_probes_csr_t;

  typedef struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    } rvfi_probes_t;

  typedef struct packed {
      logic                    valid;            // valid control flow prediction
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    } branchpredict_sbe_t;

  typedef struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
      //timing of exception, timing = 0 : break immediately or timing = 1 break immediatemy AFTER (let current instruction commit but only this one)
      logic timing;
    } exception_t;

  typedef struct packed {
      logic                    fetch_valid;      // address translation valid
      logic [CVA6Cfg.PLEN-1:0] fetch_paddr;      // physical address in
      exception_t              fetch_exception;  // exception occurred during fetch
    } icache_areq_t;

  typedef struct packed {
      logic                    fetch_req;    // address translation request
      logic [CVA6Cfg.VLEN-1:0] fetch_vaddr;  // virtual address out
    } icache_arsp_t;

  typedef struct packed {
      logic                    req;      // we request a new word
      logic                    kill_s1;  // kill the current request
      logic                    kill_s2;  // kill the last request
      logic                    spec;     // request is speculative
      logic [CVA6Cfg.VLEN-1:0] vaddr;    // 1st cycle: 12 bit index is taken for lookup
    } icache_dreq_t;

  typedef struct packed {
      logic                                ready;  // icache is ready
      logic                                valid;  // signals a valid read
      logic [CVA6Cfg.FETCH_WIDTH-1:0]      data;   // 2+ cycle out: tag
      logic [CVA6Cfg.FETCH_USER_WIDTH-1:0] user;   // User bits
      logic [CVA6Cfg.VLEN-1:0]             vaddr;  // virtual address out
      exception_t                          ex;     // we've encountered an exception
    } icache_drsp_t;

  typedef struct packed {
      logic [CVA6Cfg.VLEN-1:0] address;  // the address of the instructions from below
      logic [31:0] instruction;  // instruction word
      branchpredict_sbe_t     branch_predict; // this field contains branch prediction information regarding the forward branch path
      exception_t             ex;             // this field contains exceptions which might have happened earlier, e.g.: fetch exceptions
    } fetch_entry_t;

  typedef struct packed {
      logic [CVA6Cfg.XLEN-7:0] base;
      logic [5:0] mode;
    } jvt_t;

  typedef struct packed {
      logic [CVA6Cfg.VLEN-1:0] pc;  // PC of instruction
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;      // this can potentially be simplified, we could index the scoreboard entry
      // with the transaction id in any case make the width more generic
      fu_t fu;  // functional unit to use
      fu_op op;  // operation to perform in each functional unit
      logic [REG_ADDR_SIZE-1:0] rs1;  // register source address 1
      logic [REG_ADDR_SIZE-1:0] rs2;  // register source address 2
      logic [REG_ADDR_SIZE-1:0] rd;  // register destination address
      logic [CVA6Cfg.XLEN-1:0] result;  // for unfinished instructions this field also holds the immediate,
      // for unfinished floating-point that are partly encoded in rs2, this field also holds rs2
      // for unfinished floating-point fused operations (FMADD, FMSUB, FNMADD, FNMSUB)
      // this field holds the address of the third operand from the floating-point register file
      logic valid;  // is the result valid
      logic use_imm;  // should we use the immediate as operand b?
      logic use_zimm;  // use zimm as operand a
      logic use_pc;  // set if we need to use the PC as operand a, PC from exception
      exception_t ex;  // exception has occurred
      branchpredict_sbe_t bp;  // branch predict scoreboard data structure
      logic                     is_compressed; // signals a compressed instructions, we need this information at the commit stage if
                                               // we want jump accordingly e.g.: +4, +2
      logic is_macro_instr;  // is an instruction executed as predefined sequence of instructions called macro definition
      logic is_last_macro_instr;  // is last decoded 32bit instruction of macro definition
      logic is_double_rd_macro_instr;  // is double move decoded 32bit instruction of macro definition
      logic vfp;  // is this a vector floating-point instruction?
      logic is_zcmt;  //is a zcmt instruction
    } scoreboard_entry_t;

  typedef struct packed {
      logic valid;  // wb data is valid
      logic [CVA6Cfg.XLEN-1:0] data;  //wb data
      logic ex_valid;  // exception from WB
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;  //transaction ID
    } writeback_t;

  typedef struct packed {
      logic                    valid;           // prediction with all its values is valid
      logic [CVA6Cfg.VLEN-1:0] pc;              // PC of predict or mis-predict
      logic [CVA6Cfg.VLEN-1:0] target_address;  // target address at which to jump, or not
      logic                    is_mispredict;   // set if this was a mis-predict
      logic                    is_taken;        // branch is taken
      cf_t                     cf_type;         // Type of control flow change
    } bp_resolve_t;

  typedef struct packed {
      logic [CVA6Cfg.XLEN-1:0] mie;
      logic [CVA6Cfg.XLEN-1:0] mip;
      logic [CVA6Cfg.XLEN-1:0] mideleg;
      logic [CVA6Cfg.XLEN-1:0] hideleg;
      logic                    sie;
      logic                    global_enable;
    } irq_ctrl_t;

  typedef struct packed {
      logic                             valid;
      logic [CVA6Cfg.VLEN-1:0]          vaddr;
      logic [31:0]                      tinst;
      logic                             hs_ld_st_inst;
      logic                             hlvx_inst;
      logic                             overflow;
      logic                             g_overflow;
      logic [CVA6Cfg.XLEN-1:0]          data;
      logic [(CVA6Cfg.XLEN/8)-1:0]      be;
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
      logic                             is_speculative_load;
      logic                             is_speculative_load_miss;
    } lsu_ctrl_t;

  typedef logic [7:0] cbo_t;

  typedef struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    } fu_data_t;

  typedef struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    } icache_req_t;

  typedef struct packed {
      wt_cache_pkg::icache_in_t rtype;  // see definitions above
      logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] data;  // full cache line width
      logic [CVA6Cfg.ICACHE_USER_LINE_WIDTH-1:0] user;  // user bits
      struct packed {
        logic                                      vld;  // invalidate only affected way
        logic                                      all;  // invalidate all ways
        logic [CVA6Cfg.ICACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
        logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
      } inv;  // invalidation vector
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    } icache_rtrn_t;

  typedef struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    } dcache_req_i_t;

  typedef struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
      logic                                 data_error;
    } dcache_req_o_t;

  typedef logic accelerator_req_t;

  typedef logic accelerator_resp_t;

  typedef logic acc_mmu_req_t;

  typedef logic acc_mmu_resp_t;

  typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } axi_ar_chan_t;

  typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } axi_aw_chan_t;

  typedef struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    } axi_w_chan_t;

  typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } b_chan_t;

  typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } r_chan_t;

  typedef struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    } noc_req_t;

  typedef struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    } noc_resp_t;
  typedef noc_req_t axi_req_t;
  typedef noc_resp_t axi_rsp_t;


  typedef logic acc_cfg_t;
  localparam acc_cfg_t AccCfg = '0;

  typedef `READREGFLAGS_T(CVA6Cfg) readregflags_t;

  typedef `WRITEREGFLAGS_T(CVA6Cfg) writeregflags_t;

  typedef `ID_T(CVA6Cfg) id_t;

  typedef `HARTID_T(CVA6Cfg) hartid_t;

  typedef `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t) x_compressed_req_t;

  typedef `X_COMPRESSED_RESP_T(CVA6Cfg) x_compressed_resp_t;

  typedef `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t) x_issue_req_t;

  typedef `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t) x_issue_resp_t;

  typedef `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t) x_register_t;

  typedef `X_COMMIT_T(CVA6Cfg, hartid_t, id_t) x_commit_t;

  typedef `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t) x_result_t;

  typedef `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t) cvxif_req_t;

  typedef `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t) cvxif_resp_t;


  // Frontend local types
  typedef struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] pc;
    logic [CVA6Cfg.VLEN-1:0] target_address;
  } btb_update_t;

  typedef struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] pc;
    logic                    taken;
  } bht_update_t;

  typedef struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] target_address;
  } btb_prediction_t;

  typedef struct packed {
    logic valid;
    logic [CVA6Cfg.VLEN-1:0] ra;
  } ras_t;


  // interrupts_t
  typedef struct packed {
    logic [CVA6Cfg.XLEN-1:0] S_SW;
    logic [CVA6Cfg.XLEN-1:0] VS_SW;
    logic [CVA6Cfg.XLEN-1:0] M_SW;
    logic [CVA6Cfg.XLEN-1:0] S_TIMER;
    logic [CVA6Cfg.XLEN-1:0] VS_TIMER;
    logic [CVA6Cfg.XLEN-1:0] M_TIMER;
    logic [CVA6Cfg.XLEN-1:0] S_EXT;
    logic [CVA6Cfg.XLEN-1:0] VS_EXT;
    logic [CVA6Cfg.XLEN-1:0] M_EXT;
    logic [CVA6Cfg.XLEN-1:0] HS_EXT;
  } interrupts_t;

  localparam interrupts_t INTERRUPTS = '{
      S_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_SOFT),
      VS_SW: '0,
      M_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_SOFT),
      S_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_TIMER),
      VS_TIMER: '0,
      M_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_TIMER),
      S_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_EXT),
      VS_EXT: '0,
      M_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_EXT),
      HS_EXT: '0
  };

  // rs3_len_t & forwarding_t
  typedef logic [(CVA6Cfg.NrRgprPorts == 3 ? CVA6Cfg.XLEN : CVA6Cfg.FLen)-1:0] rs3_len_t;

  typedef struct packed {
    logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer;
    writeback_t [CVA6Cfg.NrWbPorts-1:0] wb;
    scoreboard_entry_t [CVA6Cfg.NR_SB_ENTRIES-1:0] sbe;
  } forwarding_t;

  // pte_cva6_t
  typedef struct packed {
    logic n;
    logic [8:0] reserved;
    logic [CVA6Cfg.PPNW-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  } pte_cva6_t;

  // tlb_update_cva6_t
  typedef struct packed {
    logic valid;
    logic is_napot_64k;
    logic [CVA6Cfg.PtLevels-2:0][0:0] is_page;
    logic [CVA6Cfg.VpnLen-1:0] vpn;
    logic [CVA6Cfg.ASID_WIDTH-1:0] asid;
    logic [CVA6Cfg.VMID_WIDTH-1:0] vmid;
    logic [0:0] v_st_enbl;
    pte_cva6_t content;
    pte_cva6_t g_content;
  } tlb_update_cva6_t;

  // dcache_inval_t
  typedef struct packed {
    logic                                      vld;
    logic                                      all;
    logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0]     idx;
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] way;
  } dcache_inval_t;

  // dcache_req_t
  typedef struct packed {
    wt_cache_pkg::dcache_out_t                 rtype;
    logic [2:0]                                size;
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] way;
    logic [CVA6Cfg.PLEN-1:0]                   paddr;
    logic [CVA6Cfg.XLEN-1:0]                   data;
    logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]      user;
    logic                                      nc;
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0]          tid;
    ariane_pkg::amo_t                          amo_op;
  } dcache_req_t;

  // dcache_rtrn_t
  typedef struct packed {
    wt_cache_pkg::dcache_in_t                  rtype;
    logic [CVA6Cfg.DCACHE_LINE_WIDTH-1:0]      data;
    logic [CVA6Cfg.DCACHE_USER_LINE_WIDTH-1:0] user;
    dcache_inval_t                             inv;
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0]          tid;
  } dcache_rtrn_t;


  // wbuffer_t
  typedef struct packed {
    logic [CVA6Cfg.DCACHE_TAG_WIDTH+(CVA6Cfg.DCACHE_INDEX_WIDTH-CVA6Cfg.XLEN_ALIGN_BYTES)-1:0] wtag;
    logic [CVA6Cfg.XLEN-1:0] data;
    logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] user;
    logic [(CVA6Cfg.XLEN/8)-1:0] dirty;  // byte is dirty
    logic [(CVA6Cfg.XLEN/8)-1:0] valid;  // byte is valid
    logic [(CVA6Cfg.XLEN/8)-1:0] txblock;  // byte is part of transaction in-flight
    logic checked;  // if cache state of this word has been checked
    logic [CVA6Cfg.DCACHE_SET_ASSOC-1:0] hit_oh;  // valid way in the cache
  } wbuffer_t;

endpackage