"""
EdgeNPU Compiler Backend
Code generation for NPU
"""

from .code_generator import CodeGenerator
from .instruction_emitter import InstructionEmitter
from .memory_allocator import MemoryAllocator
from .scheduler import Scheduler

__all__ = [
    'CodeGenerator',
    'InstructionEmitter',
    'MemoryAllocator',
    'Scheduler',
]
