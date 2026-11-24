// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: Ariane Top-level module

`include "rvfi_types.svh"
`include "cvxif_types.svh"

module ariane import ariane_pkg::*;
  import cva6_types_pkg::*; 
  ),
  ;
    rvfi_probes_instr_t instr;
  },

  // CVXIF Types
  localparam type readregflags_t      = `READREGFLAGS_T(CVA6Cfg),
  localparam type writeregflags_t     = `WRITEREGFLAGS_T(CVA6Cfg),
  localparam type id_t                = `ID_T(CVA6Cfg),
  localparam type hartid_t            = `HARTID_T(CVA6Cfg),
  localparam type x_compressed_req_t  = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
  localparam type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
  localparam type x_issue_req_t       = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
  localparam type x_issue_resp_t      = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
  localparam type x_register_t        = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
  localparam type x_commit_t          = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
  localparam type x_result_t          = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
  localparam type cvxif_req_t         = `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t),
  localparam type cvxif_resp_t        = `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t),
  // AXI Types
  parameter int unsigned AxiAddrWidth = ariane_axi::AddrWidth,
  parameter int unsigned AxiDataWidth = ariane_axi::DataWidth,
  parameter int unsigned AxiIdWidth   = ariane_axi::IdWidth
  
  
  
  
  ) (
  input  logic                         clk_i,
  input  logic                         rst_ni,
  // Core ID, Cluster ID and boot address are considered more or less static
  input  logic [CVA6Cfg.VLEN-1:0]       boot_addr_i,  // reset boot address
  input  logic [CVA6Cfg.XLEN-1:0]       hart_id_i,    // hart id in a multicore environment (reflected in a CSR)

  // Interrupt inputs
  input  logic [1:0]                   irq_i,        // level sensitive IR lines, mip & sip (async)
  input  logic                         ipi_i,        // inter-processor interrupts (async)
  // Timer facilities
  input  logic                         time_irq_i,   // timer interrupt in (async)
  input  logic                         debug_req_i,  // debug request (async)
  // RISC-V formal interface port (`rvfi`):
  // Can be left open when formal tracing is not needed.
  output rvfi_probes_t rvfi_probes_o,
  // memory side
  output noc_req_t                     noc_req_o,
  input  noc_resp_t                    noc_resp_i
);

  cvxif_req_t  cvxif_req;
  cvxif_resp_t cvxif_resp;

  cva6  i_cva6 (
    .clk_i                ( clk_i                     ),
    .rst_ni               ( rst_ni                    ),
    .boot_addr_i          ( boot_addr_i               ),
    .hart_id_i            ( hart_id_i                 ),
    .irq_i                ( irq_i                     ),
    .ipi_i                ( ipi_i                     ),
    .time_irq_i           ( time_irq_i                ),
    .debug_req_i          ( debug_req_i               ),
    .rvfi_probes_o        ( rvfi_probes_o             ),
    .cvxif_req_o          ( cvxif_req                 ),
    .cvxif_resp_i         ( cvxif_resp                ),
    .noc_req_o            ( noc_req_o                 ),
    .noc_resp_i           ( noc_resp_i                )
  );

  if (CVA6Cfg.CvxifEn) begin: gen_cvxif
    if (CVA6Cfg.CoproType == config_pkg::COPRO_EXAMPLE) begin: gen_COPRO_EXAMPLE
      cvxif_example_coprocessor #(
        .NrRgprPorts (CVA6Cfg.NrRgprPorts),
        .XLEN (CVA6Cfg.XLEN)
        
        
        
        
        
        
        
        
        
        
        
        
        ) i_cvxif_coprocessor (
        .clk_i                ( clk_i                          ),
        .rst_ni               ( rst_ni                         ),
        .cvxif_req_i          ( cvxif_req                      ),
        .cvxif_resp_o         ( cvxif_resp                     )
      );
    end else begin: gen_COPRO_NONE
      assign cvxif_resp = '{compressed_ready: 1'b1, issue_ready: 1'b1, register_ready: 1'b1, default: '0};
    end
  end else begin: gen_no_cvxif
    assign cvxif_resp = '0;
  end


endmodule // ariane
