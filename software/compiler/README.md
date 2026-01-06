# EdgeNPU Compiler

Compiler cho NPU, chuyển đổi model ONNX/TFLite thành binary chạy trên NPU.

## Cấu trúc

```
compiler/
├── frontend/           # Model parsing và IR generation
│   ├── ir_builder.py   # IR graph builder
│   └── model_parser.py # ONNX/TFLite parsers
├── optimizer/          # Graph optimization
│   ├── passes.py       # Optimization passes
│   ├── quantizer.py    # INT8 quantization
│   └── graph_optimizer.py
├── backend/            # Code generation
│   ├── instruction_emitter.py  # NPU instruction emission
│   ├── memory_allocator.py     # Buffer allocation
│   ├── scheduler.py            # Operation scheduling
│   └── code_generator.py       # Binary generation
└── npu_compiler.py     # Legacy compiler (standalone)
```

## Sử dụng

### Command Line
```bash
python -m compiler model.onnx -o model.npu
```

### Python API
```python
from compiler import NPUCompiler

# Compile ONNX model
compiler = NPUCompiler(pe_rows=16, pe_cols=16)
model = compiler.compile("model.onnx", "model.npu", verbose=True)

# Or compile IR graph directly
from compiler.frontend import IRBuilder

builder = IRBuilder("my_model")
inp = builder.add_input("input", (1, 3, 224, 224))
# ... build graph ...
graph = builder.build()

model = compiler.compile_graph(graph)
model.save("model.npu")
```

## Pipeline

1. **Frontend**: Parse model → IR Graph
   - ONNX parser
   - TFLite parser
   - IR builder for custom models

2. **Optimizer**: Optimize IR Graph
   - Constant folding
   - Dead code elimination
   - Conv + BatchNorm fusion
   - Conv + ReLU fusion
   - Layout optimization
   - Tiling for PE array

3. **Quantizer**: Float32 → INT8
   - Per-channel weight quantization
   - Activation calibration
   - Scale/zero-point computation

4. **Backend**: IR → NPU Binary
   - Memory allocation
   - Operation scheduling
   - Instruction emission
   - Binary packing

## Optimization Levels

- **O0**: No optimization
- **O1**: Basic (constant folding, DCE)
- **O2**: Standard (+ fusion, layout opt)
- **O3**: Aggressive (+ tiling)

## Output Format

Binary format:
```
[Header: 64 bytes]
  - Magic: "NPUE" (4 bytes)
  - Version (2 bytes)
  - Num layers (2 bytes)
  - Weight size (4 bytes)
  - Instruction count (4 bytes)
  - Input size (4 bytes)
  - Output size (4 bytes)
  - Total size (4 bytes)
  - Checksum (4 bytes)
  - Reserved (32 bytes)

[Instructions: N * 8 bytes]
[Weights: M bytes]
[Bias: K bytes]
```

## Supported Operations

- Conv2D, DepthwiseConv2D
- FullyConnected, MatMul
- ReLU, ReLU6, Sigmoid, Tanh, Softmax
- MaxPool, AvgPool, GlobalAvgPool
- Add, Sub, Mul, Div
- BatchNorm, LayerNorm
- Reshape, Transpose, Concat

## License

Copyright (c) 2024 EdgeNPU Project
