# NPU Controller

Main controller and scheduler for the NPU.

## Modules

- `npu_controller.sv` - Main Controller FSM
- `instruction_decoder.sv` - Instruction Decoder
- `scheduler.sv` - Layer Scheduler
- `dependency_checker.sv` - Data Dependency Management

## Instruction Set

| Opcode | Instruction | Description |
|--------|-------------|-------------|
| 0x00   | NOP         | No operation |
| 0x01   | CONV        | Convolution |
| 0x02   | FC          | Fully connected |
| 0x03   | POOL        | Pooling |
| 0x04   | ACT         | Activation |
| 0x05   | LOAD        | Load data |
| 0x06   | STORE       | Store data |
| 0x07   | SYNC        | Synchronize |
