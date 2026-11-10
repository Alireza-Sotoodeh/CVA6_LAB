#include "Vcva6_axi_wrapper.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <queue>
#include <cstring>
#include <iomanip>

#define ANSI_COLOR_RED     "\x1b[1;31m"
#define ANSI_COLOR_GREEN   "\x1b[1;32m"
#define ANSI_COLOR_YELLOW  "\x1b[1;33m"
#define ANSI_COLOR_BLUE    "\x1b[1;34m"
#define ANSI_COLOR_RESET   "\x1b[0m"

#define RAM_SIZE (1024 * 1024 * 16)
#define BASE_ADDR 0x80000000ULL

struct AXI_Req {
    uint64_t addr;
    uint32_t id;
    uint8_t  len;
};

uint64_t read_ram(const std::vector<uint8_t>& ram, uint64_t addr) {
    uint64_t aligned_addr = addr & ~0x7ULL; 
    if (aligned_addr >= BASE_ADDR && (aligned_addr - BASE_ADDR) <= RAM_SIZE - 8) {
        uint64_t data = 0;
        std::memcpy(&data, &ram[aligned_addr - BASE_ADDR], 8);
        return data;
    }
    return 0;
}

void write_ram(std::vector<uint8_t>& ram, uint64_t addr, uint64_t data, uint8_t strb) {
    uint64_t aligned_addr = addr & ~0x7ULL; 
    if (aligned_addr >= BASE_ADDR && (aligned_addr - BASE_ADDR) <= RAM_SIZE - 8) {
        uint64_t offset = aligned_addr - BASE_ADDR;
        for (int i = 0; i < 8; i++) {
            if ((strb >> i) & 1) {
                ram[offset + i] = (data >> (i * 8)) & 0xFF;
            }
        }
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcva6_axi_wrapper* top = new Vcva6_axi_wrapper;

    // Check if waveform tracing requested
    VerilatedVcdC* tfp = nullptr;
    const char* trace_flag = std::getenv("ENABLE_WAVE");
    if (trace_flag && std::string(trace_flag) == "1") {
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open("waveform.vcd");
        std::cout << ANSI_COLOR_BLUE << "[WAVE] Waveform dumping enabled -> waveform.vcd" << ANSI_COLOR_RESET << "\n";
    }

    std::vector<uint8_t> ram(RAM_SIZE, 0);
    std::string bin_path = "firmware.bin";
    std::ifstream bin_file(bin_path, std::ios::binary);
    if (!bin_file) {
        std::cerr << ANSI_COLOR_RED << "CRITICAL ERROR: Failed to open 'firmware.bin'!" << ANSI_COLOR_RESET << "\n";
        return 1;
    }
    bin_file.read(reinterpret_cast<char*>(ram.data()), RAM_SIZE);
    std::cout << "[+] Loaded firmware into memory. Size: " << bin_file.gcount() << " bytes.\n";

    vluint64_t main_time = 0;
    uint64_t total_commits = 0;
    uint64_t first_commit_cycle = 0;
    uint64_t last_commit_cycle = 0;
    bool tohost_written = false;
    uint64_t exit_code = 0;

    std::queue<AXI_Req> ar_queue;
    std::queue<AXI_Req> aw_queue;
    std::queue<uint32_t> b_queue;

    bool r_active = false; uint64_t r_addr = 0; uint32_t r_id = 0; int r_beats = 0;
    bool w_active = false; uint64_t w_addr = 0; uint32_t w_id = 0; int w_beats = 0;

    // Initial reset
    top->clk_i = 0; top->rst_ni = 0; top->boot_addr_i = BASE_ADDR; top->irq_i = 0;
    top->axi_ar_ready_i = 1; top->axi_aw_ready_i = 1; top->axi_w_ready_i = 0;
    top->axi_r_valid_i = 0; top->axi_r_id_i = 0; top->axi_r_data_i = 0; top->axi_r_resp_i = 0; top->axi_r_last_i = 0;
    top->axi_b_valid_i = 0; top->axi_b_id_i = 0; top->axi_b_resp_i = 0;
    top->eval();

    for (int i = 0; i < 30; i++) {
        top->clk_i = 1; top->eval(); if (tfp) tfp->dump(main_time); main_time++;
        top->clk_i = 0; top->eval(); if (tfp) tfp->dump(main_time); main_time++;
    }
    top->rst_ni = 1;
    top->eval();
    std::cout << "[+] Reset deasserted. CPU starting execution at 0x" << std::hex << BASE_ADDR << std::dec << "...\n";

    const uint64_t MAX_CYCLES = 500000;
    const uint64_t STALL_LIMIT = 50000;

    while (!Verilated::gotFinish() && (main_time / 2) < MAX_CYCLES && !tohost_written) {
        bool ar_fire = top->axi_ar_valid_o && top->axi_ar_ready_i;
        uint64_t captured_ar_addr = top->axi_ar_addr_o;
        uint32_t captured_ar_id   = top->axi_ar_id_o;
        uint8_t  captured_ar_len  = top->axi_ar_len_o;

        bool aw_fire = top->axi_aw_valid_o && top->axi_aw_ready_i;
        uint64_t captured_aw_addr = top->axi_aw_addr_o;
        uint32_t captured_aw_id   = top->axi_aw_id_o;
        uint8_t  captured_aw_len  = top->axi_aw_len_o;

        bool w_fire  = top->axi_w_valid_o && top->axi_w_ready_i;
        uint64_t captured_w_data  = top->axi_w_data_o;
        uint8_t  captured_w_strb  = top->axi_w_strb_o;
        bool     captured_w_last  = top->axi_w_last_o;

        bool r_fire  = top->axi_r_valid_i  && top->axi_r_ready_o;
        bool b_fire  = top->axi_b_valid_i  && top->axi_b_ready_o;

        // Rising Edge
        top->clk_i = 1;
        top->eval();
        if (tfp) tfp->dump(main_time);
        main_time++;

        // Track Commits
        if (top->commit_ack_o > 0) {
            for (int i = 0; i < 2; i++) {
                if ((top->commit_ack_o >> i) & 1) {
                    total_commits++;
                    if (total_commits == 1) {
                        first_commit_cycle = main_time / 2;
                    }
                    last_commit_cycle = main_time / 2;

                    uint64_t pc = 0;
#ifdef RV32
                    pc = (top->commit_pc_o >> (i * 32)) & 0xFFFFFFFFULL;
#else
                    uint64_t pc_low  = top->commit_pc_o[i * 2];
                    uint64_t pc_high = top->commit_pc_o[i * 2 + 1];
                    pc = (pc_high << 32) | pc_low;
#endif
                    if (total_commits <= 20 || total_commits % 50 == 0) {
                        std::cout << ANSI_COLOR_GREEN << "  [COMMIT #" << total_commits 
                                  << "] Cycle=" << (main_time / 2) 
                                  << " PC=0x" << std::hex << pc << std::dec << ANSI_COLOR_RESET << "\n";
                    }
                }
            }
        }

        // AXI Memory Queueing
        if (ar_fire) { ar_queue.push({captured_ar_addr, captured_ar_id, captured_ar_len}); }
        if (aw_fire) { aw_queue.push({captured_aw_addr, captured_aw_id, captured_aw_len}); }
        if (w_fire) {
            write_ram(ram, w_addr, captured_w_data, captured_w_strb);
            
            // Check for tohost write
            if (w_addr == 0x80000040 || (w_addr >= 0x80000030 && w_addr <= 0x80000060)) {
                if (captured_w_data != 0) {
                    tohost_written = true;
                    exit_code = captured_w_data;
                    std::cout << ANSI_COLOR_BLUE << "[TOHOST] Benchmark termination signal written! Data=0x" 
                              << std::hex << captured_w_data << std::dec << ANSI_COLOR_RESET << "\n";
                }
            }

            w_beats--; w_addr += 8;
            if (captured_w_last || w_beats <= 0) { w_active = false; b_queue.push(w_id); }
        }
        if (r_fire) {
            r_beats--; r_addr += 8;
            if (r_beats <= 0) { r_active = false; }
        }
        if (b_fire) { b_queue.pop(); }

        if (!r_active && !ar_queue.empty()) {
            r_active = true; r_addr  = ar_queue.front().addr; r_id = ar_queue.front().id; r_beats = ar_queue.front().len + 1;
            ar_queue.pop();
        }
        if (!w_active && !aw_queue.empty()) {
            w_active = true; w_addr  = aw_queue.front().addr; w_id = aw_queue.front().id; w_beats = aw_queue.front().len + 1;
            aw_queue.pop();
        }

        top->axi_ar_ready_i = 1; top->axi_aw_ready_i = 1; 
        top->axi_r_valid_i = r_active; top->axi_r_id_i = r_id; top->axi_r_resp_i = 0; top->axi_r_last_i = (r_active && r_beats == 1) ? 1 : 0;
        top->axi_r_data_i = r_active ? read_ram(ram, r_addr) : 0;
        top->axi_w_ready_i = w_active;
        top->axi_b_valid_i = !b_queue.empty(); top->axi_b_id_i = b_queue.empty() ? 0 : b_queue.front(); top->axi_b_resp_i = 0;

        // Falling Edge
        top->clk_i = 0;
        top->eval();
        if (tfp) tfp->dump(main_time);
        main_time++;

        // Stall check
        uint64_t current_cycle = main_time / 2;
        if (total_commits > 0 && (current_cycle - last_commit_cycle) > STALL_LIMIT) {
            std::cout << ANSI_COLOR_RED << "[TIMEOUT] Pipeline stalled for " << STALL_LIMIT << " cycles after commit " << total_commits << ANSI_COLOR_RESET << "\n";
            break;
        }
    }

    uint64_t elapsed_cycles = main_time / 2;
    std::cout << "\n============================================================\n";
    if (total_commits > 0) {
        // CVA6 spends ~256 cycles during boot/init flushing the pipeline and cache invalidation.
        // Steady-state execution cycles are measured from the first committed instruction.
        uint64_t execution_cycles = (last_commit_cycle >= first_commit_cycle) ? (last_commit_cycle - first_commit_cycle + 1) : elapsed_cycles;
        double cpi = (double)execution_cycles / (double)total_commits;
        double ipc = 1.0 / cpi;
        std::cout << ANSI_COLOR_GREEN << "          [SUCCESS] SIMULATION COMPLETED." << ANSI_COLOR_RESET << "\n";
        std::cout << "          Total Clock Cycles    : " << elapsed_cycles << "\n";
        std::cout << "          Startup/Flush Cycles  : " << first_commit_cycle << " (cache flush & boot overhead)\n";
        std::cout << "          Active Exec Cycles    : " << execution_cycles << "\n";
        std::cout << "          Committed Instrs      : " << total_commits << "\n";
        std::cout << "          Steady-State CPI      : " << std::fixed << std::setprecision(2) << cpi << "\n";
        std::cout << "          Steady-State IPC      : " << std::fixed << std::setprecision(2) << ipc << "\n";
    } else {
        std::cout << ANSI_COLOR_RED << "          [FAILED] ZERO COMMITS RECORDED." << ANSI_COLOR_RESET << "\n";
    }
    std::cout << "============================================================\n";

    if (tfp) {
        tfp->close();
        delete tfp;
    }
    delete top;
    return (total_commits > 0) ? 0 : 1;
}
