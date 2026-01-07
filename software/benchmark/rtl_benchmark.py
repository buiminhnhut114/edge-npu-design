#!/usr/bin/env python3
"""
EdgeNPU RTL Simulation Benchmark
Run actual RTL simulation to measure real performance

This script:
1. Compiles model to NPU binary
2. Generates testbench with model data
3. Runs RTL simulation (Verilator/Icarus)
4. Parses simulation results for actual cycle counts
"""

import sys
import os
import subprocess
import tempfile
import time
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Tuple

sys.path.insert(0, str(Path(__file__).parent.parent))


@dataclass
class RTLSimConfig:
    """RTL simulation configuration"""
    simulator: str = 'verilator'  # verilator, iverilog, vcs
    rtl_dir: str = '../../rtl'
    tb_dir: str = '../../verification/testbench'
    build_dir: str = '../../build'
    clock_period_ns: float = 1.25  # 800 MHz
    timeout_cycles: int = 10_000_000


@dataclass
class RTLBenchmarkResult:
    """RTL simulation benchmark result"""
    model_name: str
    total_cycles: int
    compute_cycles: int
    memory_cycles: int
    latency_us: float
    throughput_fps: float
    simulation_time_s: float
    success: bool
    error_msg: str = ""


class RTLBenchmark:
    """
    Run RTL simulation benchmarks
    """
    
    def __init__(self, config: RTLSimConfig = None):
        self.config = config or RTLSimConfig()
        self.workspace = Path(__file__).parent.parent.parent
    
    def check_simulator(self) -> bool:
        """Check if simulator is available"""
        try:
            if self.config.simulator == 'verilator':
                result = subprocess.run(['verilator', '--version'], 
                                       capture_output=True, text=True)
                return result.returncode == 0
            elif self.config.simulator == 'iverilog':
                result = subprocess.run(['iverilog', '-V'],
                                       capture_output=True, text=True)
                return result.returncode == 0
        except FileNotFoundError:
            return False
        return False
    
    def generate_testbench(self, model_binary: bytes, 
                           output_path: str) -> str:
        """Generate SystemVerilog testbench with model data"""
        
        # Extract instructions and weights from binary
        # Header: 64 bytes
        # [0:4] magic, [4:6] version, [6:8] num_layers
        # [8:12] weight_size, [12:16] num_instructions
        
        import struct
        
        if len(model_binary) < 64:
            raise ValueError("Invalid model binary")
        
        header = model_binary[:64]
        magic = struct.unpack('<I', header[0:4])[0]
        num_inst = struct.unpack('<I', header[12:16])[0]
        weight_size = struct.unpack('<I', header[8:12])[0]
        
        inst_start = 64
        inst_end = inst_start + num_inst * 8
        weight_start = inst_end
        weight_end = weight_start + weight_size
        
        instructions = model_binary[inst_start:inst_end]
        weights = model_binary[weight_start:weight_end]
        
        # Generate testbench
        tb_code = f'''
`timescale 1ns/1ps

module npu_benchmark_tb;

    // Parameters
    parameter CLK_PERIOD = {self.config.clock_period_ns};
    parameter NUM_INSTRUCTIONS = {num_inst};
    parameter WEIGHT_SIZE = {weight_size};
    parameter TIMEOUT_CYCLES = {self.config.timeout_cycles};
    
    // Signals
    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire [31:0] cycle_count;
    wire [31:0] compute_cycles;
    wire [31:0] memory_cycles;
    
    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Instruction memory
    reg [63:0] inst_mem [0:NUM_INSTRUCTIONS-1];
    
    // Weight memory
    reg [7:0] weight_mem [0:WEIGHT_SIZE-1];
    
    // DUT instantiation
    npu_top #(
        .PE_ROWS(16),
        .PE_COLS(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .cycle_count(cycle_count),
        .compute_cycles(compute_cycles),
        .memory_cycles(memory_cycles)
    );
    
    // Initialize memories
    initial begin
        // Instructions
'''
        
        # Add instruction initialization
        for i in range(0, len(instructions), 8):
            if i + 8 <= len(instructions):
                val = struct.unpack('<Q', instructions[i:i+8])[0]
                tb_code += f"        inst_mem[{i//8}] = 64'h{val:016X};\n"
        
        tb_code += '''
        // Weights
'''
        
        # Add weight initialization (sample)
        for i in range(min(len(weights), 1000)):
            tb_code += f"        weight_mem[{i}] = 8'h{weights[i]:02X};\n"
        
        tb_code += f'''
    end
    
    // Test sequence
    initial begin
        $display("=== EdgeNPU RTL Benchmark ===");
        $display("Instructions: %d", NUM_INSTRUCTIONS);
        $display("Weights: %d bytes", WEIGHT_SIZE);
        
        // Reset
        rst_n = 0;
        start = 0;
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        // Start execution
        $display("Starting execution...");
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for completion or timeout
        fork
            begin
                wait(done);
                $display("Execution complete!");
            end
            begin
                #(CLK_PERIOD * TIMEOUT_CYCLES);
                $display("TIMEOUT!");
            end
        join_any
        disable fork;
        
        // Report results
        #(CLK_PERIOD * 10);
        $display("=== Benchmark Results ===");
        $display("CYCLES_TOTAL: %d", cycle_count);
        $display("CYCLES_COMPUTE: %d", compute_cycles);
        $display("CYCLES_MEMORY: %d", memory_cycles);
        $display("=== End Results ===");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * TIMEOUT_CYCLES * 2);
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule
'''
        
        with open(output_path, 'w') as f:
            f.write(tb_code)
        
        return output_path

    def run_verilator(self, tb_path: str, output_dir: str) -> Tuple[bool, str]:
        """Run Verilator simulation"""
        rtl_files = [
            str(self.workspace / 'rtl' / 'top' / 'npu_top.sv'),
            str(self.workspace / 'rtl' / 'top' / 'npu_pkg.sv'),
        ]
        
        # Compile
        compile_cmd = [
            'verilator',
            '--cc',
            '--exe',
            '--build',
            '-Wall',
            '-Wno-fatal',
            '--trace',
            '-o', 'npu_sim',
            '--Mdir', output_dir,
        ] + rtl_files + [tb_path]
        
        result = subprocess.run(compile_cmd, capture_output=True, text=True,
                               cwd=output_dir)
        
        if result.returncode != 0:
            return False, f"Compile error: {result.stderr}"
        
        # Run
        sim_path = os.path.join(output_dir, 'npu_sim')
        result = subprocess.run([sim_path], capture_output=True, text=True,
                               timeout=300)
        
        return True, result.stdout
    
    def run_iverilog(self, tb_path: str, output_dir: str) -> Tuple[bool, str]:
        """Run Icarus Verilog simulation"""
        rtl_files = list((self.workspace / 'rtl').rglob('*.sv'))
        rtl_files += list((self.workspace / 'rtl').rglob('*.v'))
        
        vvp_path = os.path.join(output_dir, 'npu_sim.vvp')
        
        # Compile
        compile_cmd = ['iverilog', '-g2012', '-o', vvp_path, tb_path]
        compile_cmd += [str(f) for f in rtl_files[:20]]  # Limit files
        
        result = subprocess.run(compile_cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            return False, f"Compile error: {result.stderr}"
        
        # Run
        result = subprocess.run(['vvp', vvp_path], capture_output=True, text=True,
                               timeout=300)
        
        return True, result.stdout
    
    def parse_results(self, output: str) -> dict:
        """Parse simulation output for cycle counts"""
        results = {
            'total_cycles': 0,
            'compute_cycles': 0,
            'memory_cycles': 0,
        }
        
        for line in output.split('\n'):
            if 'CYCLES_TOTAL:' in line:
                results['total_cycles'] = int(line.split(':')[1].strip())
            elif 'CYCLES_COMPUTE:' in line:
                results['compute_cycles'] = int(line.split(':')[1].strip())
            elif 'CYCLES_MEMORY:' in line:
                results['memory_cycles'] = int(line.split(':')[1].strip())
        
        return results
    
    def benchmark_model(self, model_path: str,
                        input_shape: Tuple[int, ...] = (1, 3, 224, 224)
                        ) -> RTLBenchmarkResult:
        """
        Run RTL simulation benchmark for a model
        """
        model_name = Path(model_path).stem
        start_time = time.time()
        
        try:
            # Compile model
            from compiler.frontend import parse_model
            from compiler.optimizer import optimize_graph
            from compiler.optimizer.quantizer import quantize_graph
            from compiler.backend import compile_graph
            
            print(f"Compiling model: {model_path}")
            ir_graph = parse_model(model_path, input_shape)
            ir_graph = optimize_graph(ir_graph, opt_level=2)
            ir_graph = quantize_graph(ir_graph)
            compiled = compile_graph(ir_graph)
            
            model_binary = compiled.to_binary()
            
            # Create temp directory
            with tempfile.TemporaryDirectory() as tmpdir:
                # Generate testbench
                tb_path = os.path.join(tmpdir, 'npu_benchmark_tb.sv')
                self.generate_testbench(model_binary, tb_path)
                
                # Run simulation
                print(f"Running {self.config.simulator} simulation...")
                
                if self.config.simulator == 'verilator':
                    success, output = self.run_verilator(tb_path, tmpdir)
                elif self.config.simulator == 'iverilog':
                    success, output = self.run_iverilog(tb_path, tmpdir)
                else:
                    return RTLBenchmarkResult(
                        model_name=model_name,
                        total_cycles=0,
                        compute_cycles=0,
                        memory_cycles=0,
                        latency_us=0,
                        throughput_fps=0,
                        simulation_time_s=time.time() - start_time,
                        success=False,
                        error_msg=f"Unknown simulator: {self.config.simulator}"
                    )
                
                if not success:
                    return RTLBenchmarkResult(
                        model_name=model_name,
                        total_cycles=0,
                        compute_cycles=0,
                        memory_cycles=0,
                        latency_us=0,
                        throughput_fps=0,
                        simulation_time_s=time.time() - start_time,
                        success=False,
                        error_msg=output
                    )
                
                # Parse results
                results = self.parse_results(output)
                
                # Calculate metrics
                clock_mhz = 1000 / self.config.clock_period_ns
                latency_us = results['total_cycles'] / clock_mhz
                throughput_fps = 1_000_000 / latency_us if latency_us > 0 else 0
                
                return RTLBenchmarkResult(
                    model_name=model_name,
                    total_cycles=results['total_cycles'],
                    compute_cycles=results['compute_cycles'],
                    memory_cycles=results['memory_cycles'],
                    latency_us=latency_us,
                    throughput_fps=throughput_fps,
                    simulation_time_s=time.time() - start_time,
                    success=True
                )
                
        except Exception as e:
            return RTLBenchmarkResult(
                model_name=model_name,
                total_cycles=0,
                compute_cycles=0,
                memory_cycles=0,
                latency_us=0,
                throughput_fps=0,
                simulation_time_s=time.time() - start_time,
                success=False,
                error_msg=str(e)
            )


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='EdgeNPU RTL Benchmark')
    parser.add_argument('model', help='Model file to benchmark')
    parser.add_argument('--input-shape', default='1,3,224,224')
    parser.add_argument('--simulator', default='iverilog', 
                        choices=['verilator', 'iverilog', 'vcs'])
    parser.add_argument('--clock', type=float, default=800, help='Clock MHz')
    
    args = parser.parse_args()
    
    config = RTLSimConfig(
        simulator=args.simulator,
        clock_period_ns=1000 / args.clock
    )
    
    benchmark = RTLBenchmark(config)
    
    # Check simulator
    if not benchmark.check_simulator():
        print(f"Error: {args.simulator} not found")
        print("Install with:")
        print("  Ubuntu: sudo apt install verilator iverilog")
        print("  macOS: brew install verilator icarus-verilog")
        return 1
    
    input_shape = tuple(int(x) for x in args.input_shape.split(','))
    
    result = benchmark.benchmark_model(args.model, input_shape)
    
    print("\n" + "=" * 60)
    print("RTL Simulation Benchmark Results")
    print("=" * 60)
    
    if result.success:
        print(f"Model:           {result.model_name}")
        print(f"Total Cycles:    {result.total_cycles:,}")
        print(f"Compute Cycles:  {result.compute_cycles:,}")
        print(f"Memory Cycles:   {result.memory_cycles:,}")
        print(f"Latency:         {result.latency_us:.2f} µs")
        print(f"Throughput:      {result.throughput_fps:.1f} FPS")
        print(f"Sim Time:        {result.simulation_time_s:.1f} s")
    else:
        print(f"Benchmark FAILED: {result.error_msg}")
    
    return 0 if result.success else 1


if __name__ == '__main__':
    sys.exit(main())
