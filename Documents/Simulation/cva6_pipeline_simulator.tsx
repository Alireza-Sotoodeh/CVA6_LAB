import React, { useState } from 'react';
import { Play, RotateCcw, Cpu, Code2, Database } from 'lucide-react';

// --- INSTRUCTION PARSING & EXECUTION ---
const parseInstruction = (text) => {
  const clean = text.split(';')[0].split('//')[0].trim();
  if (!clean) return null;
  
  const parts = clean.replace(/,/g, ' ').split(/\s+/);
  const op = parts[0].toUpperCase();
  let type = 'ALU';
  let rd = 0, rs1 = 0, rs2 = 0, imm = 0;

  try {
    if (['ADD', 'SUB', 'XOR', 'OR', 'AND'].includes(op)) {
      type = 'ALU';
      rd = parseInt(parts[1].replace('x',''));
      rs1 = parseInt(parts[2].replace('x',''));
      rs2 = parseInt(parts[3].replace('x',''));
    } else if (['ADDI', 'XORI', 'ORI', 'ANDI'].includes(op)) {
      type = 'ALU';
      rd = parseInt(parts[1].replace('x',''));
      rs1 = parseInt(parts[2].replace('x',''));
      imm = parseInt(parts[3]);
    } else if (['LW'].includes(op)) {
      type = 'LSU';
      rd = parseInt(parts[1].replace('x',''));
      const mem = parts[2].split('(');
      imm = parseInt(mem[0]);
      rs1 = parseInt(mem[1].replace('x','').replace(')',''));
    } else if (['SW'].includes(op)) {
      type = 'LSU';
      rs2 = parseInt(parts[1].replace('x',''));
      const mem = parts[2].split('(');
      imm = parseInt(mem[0]);
      rs1 = parseInt(mem[1].replace('x','').replace(')',''));
    } else if (['BEQ', 'BNE', 'BLT', 'BGE'].includes(op)) {
      type = 'BRANCH';
      rs1 = parseInt(parts[1].replace('x',''));
      rs2 = parseInt(parts[2].replace('x',''));
      imm = parts[3]; 
    } else if (['MUL', 'DIV'].includes(op)) {
      type = 'MUL';
      rd = parseInt(parts[1].replace('x',''));
      rs1 = parseInt(parts[2].replace('x',''));
      rs2 = parseInt(parts[3].replace('x',''));
    } else if (['CSRRW', 'CSRRS', 'CSRRC'].includes(op)) {
      type = 'CSR';
      rd = parseInt(parts[1].replace('x',''));
    } else {
      type = 'ALU'; // fallback
    }
  } catch (e) {
    console.error("Parse error", e);
  }

  return { text: clean, op, type, rd, rs1, rs2, imm };
};

const executeInstruction = (inst, regs) => {
  const newRegs = [...regs];
  if (!inst) return newRegs;

  const { op, rd, rs1, rs2, imm } = inst;
  
  if (op === 'ADD') newRegs[rd] = newRegs[rs1] + newRegs[rs2];
  if (op === 'SUB') newRegs[rd] = newRegs[rs1] - newRegs[rs2];
  if (op === 'ADDI') newRegs[rd] = newRegs[rs1] + imm;
  if (op === 'MUL') newRegs[rd] = newRegs[rs1] * newRegs[rs2];
  if (op === 'LW') newRegs[rd] = 100; // Mock memory load
  
  newRegs[0] = 0; // Hardwired zero
  return newRegs;
};

// --- UI COMPONENTS ---
const Block = ({ title, active, inst, className = "", highlightColor = "ring-blue-500", shape = "rect" }) => {
  const isActive = active && inst;
  const baseClasses = "flex flex-col items-center justify-center text-center transition-all duration-300 relative border border-slate-400 bg-white shadow-sm text-xs font-semibold text-slate-800 p-1";
  
  let shapeClasses = "rounded-sm";
  if (shape === "circle") shapeClasses = "rounded-full aspect-square";
  if (shape === "pill") shapeClasses = "rounded-full px-3 py-1";

  return (
    <div className={`${baseClasses} ${shapeClasses} ${className} ${isActive ? `ring-4 ${highlightColor} z-10 scale-105 shadow-lg` : 'opacity-80'}`}>
      <span>{title}</span>
      {isActive && (
        <div className="absolute -top-6 left-1/2 transform -translate-x-1/2 bg-slate-800 text-emerald-400 font-mono text-[10px] px-2 py-0.5 rounded shadow-lg whitespace-nowrap z-20 pointer-events-none">
          {inst.text}
        </div>
      )}
    </div>
  );
};

export default function App() {
  const [code, setCode] = useState("ADDI x1, x0, 5\nADDI x2, x0, 10\nADD x3, x1, x2\nLW x4, 0(x1)\nMUL x5, x3, x2\nBEQ x1, x2, label");
  const [instructions, setInstructions] = useState([]);
  const [pc, setPc] = useState(0);
  
  // Pipeline: { fe, id, iss, ex, wb }
  const [pipe, setPipe] = useState({ fe: null, id: null, iss: null, ex: null, wb: null });
  const [registers, setRegisters] = useState(Array(16).fill(0));
  const [cycle, setCycle] = useState(0);
  const [isLoaded, setIsLoaded] = useState(false);

  const handleLoad = () => {
    const lines = code.split('\n').map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith('//'));
    const parsed = lines.map(parseInstruction).filter(Boolean);
    setInstructions(parsed);
    setPc(0);
    setPipe({ fe: null, id: null, iss: null, ex: null, wb: null });
    setRegisters(Array(16).fill(0));
    setCycle(0);
    setIsLoaded(true);
  };

  const handleStep = () => {
    if (!isLoaded) return;
    setCycle(c => c + 1);
    
    const nextInst = pc < instructions.length ? instructions[pc] : null;
    
    // Execute Writeback
    let updatedRegs = registers;
    if (pipe.wb) {
      updatedRegs = executeInstruction(pipe.wb, registers);
    }
    
    setRegisters(updatedRegs);
    setPipe({
      fe: nextInst,
      id: pipe.fe,
      iss: pipe.id,
      ex: pipe.iss,
      wb: pipe.ex
    });
    
    if (pc < instructions.length) setPc(p => p + 1);
  };

  const isDone = isLoaded && pc >= instructions.length && !pipe.fe && !pipe.id && !pipe.iss && !pipe.ex && !pipe.wb;

  return (
    <div className="flex h-screen bg-slate-900 text-slate-200 font-sans overflow-hidden">
      
      {/* LEFT SIDEBAR: Code & Registers */}
      <div className="w-80 flex flex-col border-r border-slate-700 bg-slate-800 shadow-xl shrink-0">
        <div className="p-4 border-b border-slate-700">
          <div className="flex items-center gap-2 mb-4">
            <Cpu className="text-blue-400" size={24} />
            <h1 className="text-lg font-bold text-white tracking-wide">CVA6 Simulator</h1>
          </div>
          <textarea
            className="w-full h-48 bg-slate-950 text-emerald-400 font-mono text-xs p-3 rounded border border-slate-700 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 outline-none resize-none"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            spellCheck="false"
            placeholder="Assembly code here..."
          />
          <div className="flex gap-2 mt-3">
            <button onClick={handleLoad} className="flex-1 flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white text-sm py-2 rounded transition-colors font-medium">
              <RotateCcw size={16} /> Load
            </button>
            <button 
              onClick={handleStep} disabled={!isLoaded || isDone}
              className={`flex-1 flex items-center justify-center gap-2 text-sm py-2 rounded transition-colors font-medium ${(!isLoaded || isDone) ? 'bg-slate-700 text-slate-500 cursor-not-allowed' : 'bg-emerald-600 hover:bg-emerald-500 text-white'}`}
            >
              <Play size={16} /> Step ({cycle})
            </button>
          </div>
        </div>

        <div className="flex-1 p-4 overflow-y-auto">
          <div className="flex items-center gap-2 mb-3">
            <Database className="text-amber-400" size={18} />
            <h2 className="text-sm font-semibold text-slate-200">Register File</h2>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {registers.map((val, i) => (
              <div key={i} className={`flex justify-between items-center px-2 py-1 rounded text-xs border ${val !== 0 ? 'bg-slate-700 border-amber-500/50' : 'bg-slate-900 border-slate-800'}`}>
                <span className="text-slate-400 font-mono">x{i}</span>
                <span className={`font-mono font-bold ${val !== 0 ? 'text-amber-400' : 'text-slate-500'}`}>{val}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* MAIN AREA: Pipeline Diagram */}
      <div className="flex-1 overflow-auto p-4 bg-white text-slate-900 relative min-w-[900px]">
        {/* Top Cache Subsystem */}
        <div className="w-full bg-yellow-50 border border-yellow-200 p-2 mb-2 rounded-md shadow-sm border-dashed">
          <div className="text-xs font-bold text-slate-600 mb-1">Cache Subsystem</div>
          <div className="flex justify-between gap-2 h-10">
            <Block title="I$" active={pipe.fe} inst={pipe.fe} className="flex-1 bg-white" />
            <Block title="D$ Miss Unit" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="flex-1 bg-white" />
            <Block title="D$ Mem" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="flex-1 bg-white" />
            <Block title="D$ Controller" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="flex-1 bg-white" />
            <Block title="D$ Buffer" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="flex-1 bg-white" />
            <Block title="D$" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="flex-1 bg-white" />
          </div>
        </div>

        {/* 5 Stages Grid */}
        <div className="grid grid-cols-5 h-[700px] border border-slate-300 rounded-md overflow-hidden bg-slate-50 relative">
          
          {/* FRONTEND */}
          <div className="bg-[#e6f4ea] flex flex-col p-2 relative border-r border-slate-300 border-dashed">
            <div className="text-xs font-bold text-slate-600 mb-2 absolute top-2 left-2">Frontend</div>
            <div className="text-xs font-semibold text-green-800 rotate-90 origin-left absolute left-4 top-32 opacity-50 tracking-widest uppercase">Speculative Regime</div>
            
            <div className="flex-1 flex flex-col justify-between mt-6 relative pl-6">
              <Block title="Re-aligner" active={pipe.fe} inst={pipe.fe} className="w-24 h-10 mx-auto" />
              
              <div className="flex flex-row justify-center gap-2 h-40 items-center">
                <Block title="Instruction Scan" active={pipe.fe} inst={pipe.fe} className="w-10 h-full" />
                <div className="flex flex-col gap-2">
                  <Block title="BHT" active={pipe.fe && pipe.fe.type === 'BRANCH'} inst={pipe.fe} className="w-16 h-8" />
                  <Block title="RAS" active={pipe.fe && pipe.fe.type === 'BRANCH'} inst={pipe.fe} className="w-16 h-8" />
                  <Block title="BTB" active={pipe.fe && pipe.fe.type === 'BRANCH'} inst={pipe.fe} className="w-16 h-8" />
                </div>
              </div>
              
              <div className="flex justify-between items-end pb-8">
                <Block title="CSR Write" active={false} className="w-14 h-12" />
                <Block title="PC Select" active={pipe.fe} inst={pipe.fe} className="w-16 h-12" />
              </div>
            </div>
          </div>

          {/* ID */}
          <div className="bg-[#fff9e6] flex flex-col p-2 relative border-r border-slate-300 border-dashed">
            <div className="text-xs font-bold text-slate-600 mb-2 text-center">ID</div>
            
            <div className="flex flex-col items-center justify-start gap-4 mt-6">
              <div className="flex border border-slate-400 bg-white">
                <div className="flex flex-col w-20">
                  <div className="border-b border-slate-300 h-4"></div>
                  <div className="border-b border-slate-300 h-4 bg-blue-100/50"></div>
                  <div className="border-b border-slate-300 h-4 bg-blue-200/50"></div>
                  <div className="h-4 bg-blue-300/50"></div>
                </div>
                <div className="px-2 py-4 text-[10px] font-bold writing-vertical flex items-center bg-slate-50">Instr. Queue</div>
              </div>

              <Block title="Compressed Decoder" active={pipe.id} inst={pipe.id} className="w-28 h-12 mt-4" />
              <Block title="Decoder" active={pipe.id} inst={pipe.id} className="w-28 h-12" />
            </div>
          </div>

          {/* ISSUE */}
          <div className="bg-[#f1f3f4] flex flex-col p-2 relative border-r border-slate-300 border-dashed">
            <div className="text-xs font-bold text-slate-600 mb-2 text-center">Issue</div>
            <div className="text-xs font-semibold text-slate-400 text-center mb-4">In-order Issue</div>

            <div className="flex h-full pb-10 justify-center items-stretch gap-2">
              <Block title={<span className="-rotate-90 block">Issue Buffer</span>} active={pipe.iss} inst={pipe.iss} className="w-10 h-3/4 my-auto" />
              
              <div className="flex flex-col justify-center gap-4 py-10 w-24">
                <Block title="Issue Read" active={pipe.iss} inst={pipe.iss} className="w-full h-12" />
                <Block title="Scoreboard" active={pipe.iss || pipe.wb} inst={pipe.iss || pipe.wb} className="w-full h-24" />
              </div>
            </div>
          </div>

          {/* EXECUTE */}
          <div className="bg-[#e8f0fe] flex flex-col p-2 relative border-r border-slate-300 border-dashed">
            <div className="text-xs font-bold text-slate-600 mb-2 text-center">Execute</div>
            <div className="text-xs font-semibold text-slate-400 text-center mb-2">OoO WB</div>

            <div className="flex h-full pb-6 items-stretch gap-2">
              <Block title={<span className="-rotate-90 block whitespace-nowrap">Execute Stage Pipe</span>} active={pipe.ex} inst={pipe.ex} className="w-8 h-3/4 my-auto bg-white" />
              
              <div className="flex-1 flex flex-col gap-2 pt-4">
                <div className="flex gap-1">
                   <div className="flex flex-col gap-1 w-1/2">
                      <Block title="PTW" active={false} className="w-full h-8 text-[9px]" />
                      <Block title="DTLB" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} className="w-full h-8 text-[9px]" />
                   </div>
                   <div className="flex flex-col gap-1 w-1/2">
                      <Block title="LSU" active={pipe.ex && pipe.ex.type === 'LSU'} inst={pipe.ex} highlightColor="ring-amber-500" className="w-full h-8 text-[9px]" />
                      <Block title="ITLB" active={false} className="w-full h-8 text-[9px]" />
                   </div>
                </div>

                <Block title="ALU" active={pipe.ex && pipe.ex.type === 'ALU'} inst={pipe.ex} highlightColor="ring-emerald-500" className="w-full h-8 mt-2 text-[10px]" />
                <Block title="CSR Buffer" active={pipe.ex && pipe.ex.type === 'CSR'} inst={pipe.ex} className="w-full h-8 text-[10px]" />
                <Block title="FPU" active={pipe.ex && pipe.ex.type === 'FPU'} inst={pipe.ex} className="w-full h-8 text-[10px]" />
                <Block title="Mul / Div" active={pipe.ex && pipe.ex.type === 'MUL'} inst={pipe.ex} highlightColor="ring-purple-500" className="w-full h-8 text-[10px]" />
                <Block title="Branch Unit" active={pipe.ex && pipe.ex.type === 'BRANCH'} inst={pipe.ex} highlightColor="ring-rose-500" className="w-full h-8 text-[10px]" />
                
                <div className="flex flex-col items-center gap-4 mt-6">
                   <Block title="Branch" shape="pill" active={pipe.ex && pipe.ex.type === 'BRANCH'} inst={pipe.ex} className="w-20" />
                   <Block title="Mispredict" shape="pill" active={false} className="w-20" />
                </div>
              </div>
            </div>
          </div>

          {/* COMMIT */}
          <div className="bg-[#fce8e6] flex flex-col p-2 relative">
            <div className="text-xs font-bold text-slate-600 mb-2 text-center">Commit</div>
            <div className="text-[10px] leading-tight font-semibold text-slate-400 text-center mb-2">In-order Architectural Commit</div>

            <div className="flex h-full items-stretch gap-3 pl-2">
               <Block title={<span className="-rotate-90 block">Scoreboard</span>} active={pipe.wb} inst={pipe.wb} className="w-10 h-3/5 mt-10 bg-white" />
               
               <div className="flex-1 flex flex-col justify-start pt-16 relative">
                 <div className="border border-slate-400 bg-white p-1 rounded shadow-sm w-full">
                    <Block title="Commit Logic" active={pipe.wb} inst={pipe.wb} className="w-full h-10 mb-6 border-0 shadow-none bg-transparent" />
                    <Block title="Regfile Write" active={pipe.wb && pipe.wb.rd !== undefined} inst={pipe.wb} highlightColor="ring-green-500" className="w-full h-12 mb-6 border-slate-300" />
                    <Block title="CSR Write" active={pipe.wb && pipe.wb.type === 'CSR'} inst={pipe.wb} className="w-full h-10 border-slate-300" />
                 </div>

                 <div className="absolute bottom-16 left-0 right-0 flex flex-col items-center gap-4">
                    <Block title="Privilege Check" shape="pill" active={false} className="w-24 text-[9px]" />
                    <Block title="Exception" shape="pill" active={false} className="w-24" />
                    <div className="text-[9px] font-bold self-end pr-2">Interrupt</div>
                 </div>
               </div>
            </div>
          </div>

        </div>
      </div>

    </div>
  );
}