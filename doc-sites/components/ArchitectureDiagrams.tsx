import React from 'react';

interface DiagramProps {
  type: string;
  className?: string;
}

export const ArchitectureDiagrams: React.FC<DiagramProps> = ({ type, className = "" }) => {
  const renderSystemOverview = () => (
    <svg viewBox="0 0 800 600" className={`w-full h-auto ${className}`}>
      {/* Background */}
      <rect width="800" height="600" fill="#f8fafc" stroke="#e2e8f0" strokeWidth="2"/>
      
      {/* Title */}
      <text x="400" y="30" textAnchor="middle" className="text-lg font-bold fill-gray-800">
        EdgeNPU System Architecture
      </text>
      
      {/* External Memory */}
      <rect x="50" y="80" width="120" height="60" fill="#fef3c7" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="110" y="105" textAnchor="middle" className="text-sm font-semibold fill-gray-800">External</text>
      <text x="110" y="120" textAnchor="middle" className="text-sm font-semibold fill-gray-800">DDR Memory</text>
      
      {/* AXI Interconnect */}
      <rect x="220" y="80" width="100" height="60" fill="#dbeafe" stroke="#3b82f6" strokeWidth="2" rx="5"/>
      <text x="270" y="105" textAnchor="middle" className="text-sm font-semibold fill-gray-800">AXI4</text>
      <text x="270" y="120" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Interconnect</text>
      
      {/* NPU Core */}
      <rect x="400" y="60" width="350" height="480" fill="#f0f9ff" stroke="#0ea5e9" strokeWidth="3" rx="10"/>
      <text x="575" y="85" textAnchor="middle" className="text-lg font-bold fill-gray-800">EdgeNPU Core</text>
      
      {/* Controller */}
      <rect x="420" y="110" width="120" height="50" fill="#ecfdf5" stroke="#10b981" strokeWidth="2" rx="5"/>
      <text x="480" y="130" textAnchor="middle" className="text-sm font-semibold fill-gray-800">NPU Controller</text>
      <text x="480" y="145" textAnchor="middle" className="text-xs fill-gray-600">Instruction Fetch/Decode</text>
      
      {/* DMA Engine */}
      <rect x="580" y="110" width="120" height="50" fill="#fef7ff" stroke="#a855f7" strokeWidth="2" rx="5"/>
      <text x="640" y="130" textAnchor="middle" className="text-sm font-semibold fill-gray-800">DMA Engine</text>
      <text x="640" y="145" textAnchor="middle" className="text-xs fill-gray-600">4-Channel Controller</text>
      
      {/* Memory Subsystem */}
      <rect x="420" y="180" width="280" height="120" fill="#fffbeb" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="560" y="200" textAnchor="middle" className="text-sm font-bold fill-gray-800">On-Chip Memory Subsystem (528KB)</text>
      
      {/* Weight Buffer */}
      <rect x="440" y="220" width="80" height="40" fill="#fef3c7" stroke="#d97706" strokeWidth="1" rx="3"/>
      <text x="480" y="235" textAnchor="middle" className="text-xs font-semibold fill-gray-800">Weight Buffer</text>
      <text x="480" y="248" textAnchor="middle" className="text-xs fill-gray-600">256KB</text>
      
      {/* Activation Buffer */}
      <rect x="540" y="220" width="80" height="40" fill="#fef3c7" stroke="#d97706" strokeWidth="1" rx="3"/>
      <text x="580" y="235" textAnchor="middle" className="text-xs font-semibold fill-gray-800">Act Buffer</text>
      <text x="580" y="248" textAnchor="middle" className="text-xs fill-gray-600">256KB</text>
      
      {/* Instruction Buffer */}
      <rect x="640" y="220" width="80" height="40" fill="#fef3c7" stroke="#d97706" strokeWidth="1" rx="3"/>
      <text x="680" y="235" textAnchor="middle" className="text-xs font-semibold fill-gray-800">Inst Buffer</text>
      <text x="680" y="248" textAnchor="middle" className="text-xs fill-gray-600">16KB</text>
      
      {/* PE Array */}
      <rect x="420" y="320" width="280" height="160" fill="#f0fdf4" stroke="#16a34a" strokeWidth="2" rx="5"/>
      <text x="560" y="340" textAnchor="middle" className="text-sm font-bold fill-gray-800">Processing Element Array (16×16)</text>
      
      {/* PE Grid */}
      {Array.from({length: 4}, (_, i) => 
        Array.from({length: 4}, (_, j) => (
          <rect key={`pe-${i}-${j}`} 
                x={450 + j * 50} 
                y={360 + i * 25} 
                width="40" 
                height="20" 
                fill="#dcfce7" 
                stroke="#16a34a" 
                strokeWidth="1" 
                rx="2"/>
        ))
      )}
      <text x="560" y="375" textAnchor="middle" className="text-xs fill-gray-600">256 Processing Elements</text>
      <text x="560" y="390" textAnchor="middle" className="text-xs fill-gray-600">Systolic Array Architecture</text>
      <text x="560" y="460" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Peak: 512 GOPS @ 1GHz</text>
      
      {/* Post Processing */}
      <rect x="420" y="500" width="280" height="50" fill="#fdf2f8" stroke="#ec4899" strokeWidth="2" rx="5"/>
      <text x="560" y="520" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Post-Processing Unit</text>
      <text x="560" y="535" textAnchor="middle" className="text-xs fill-gray-600">Activation Functions, Pooling, Quantization</text>
      
      {/* Control Interface */}
      <rect x="50" y="200" width="120" height="60" fill="#f3e8ff" stroke="#8b5cf6" strokeWidth="2" rx="5"/>
      <text x="110" y="220" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Host CPU</text>
      <text x="110" y="235" textAnchor="middle" className="text-xs fill-gray-600">AXI4-Lite</text>
      <text x="110" y="250" textAnchor="middle" className="text-xs fill-gray-600">Control Interface</text>
      
      {/* Arrows */}
      {/* DDR to AXI */}
      <path d="M170 110 L220 110" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* AXI to NPU */}
      <path d="M320 110 L400 110" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* Host to NPU */}
      <path d="M170 230 L400 230" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* Internal connections */}
      <path d="M480 160 L480 180" stroke="#374151" strokeWidth="1" markerEnd="url(#arrowhead)"/>
      <path d="M640 160 L640 180" stroke="#374151" strokeWidth="1" markerEnd="url(#arrowhead)"/>
      <path d="M560 300 L560 320" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M560 480 L560 500" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* Arrow marker definition */}
      <defs>
        <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#374151"/>
        </marker>
      </defs>
      
      {/* Performance specs */}
      <text x="50" y="350" className="text-sm font-bold fill-gray-800">Key Specifications:</text>
      <text x="50" y="370" className="text-xs fill-gray-700">• Peak Performance: 512 GOPS (INT8)</text>
      <text x="50" y="385" className="text-xs fill-gray-700">• Power Consumption: &lt;500mW</text>
      <text x="50" y="400" className="text-xs fill-gray-700">• Efficiency: &gt;1 TOPS/W</text>
      <text x="50" y="415" className="text-xs fill-gray-700">• On-chip Memory: 528KB SRAM</text>
      <text x="50" y="430" className="text-xs fill-gray-700">• Interface: AXI4/AXI4-Lite</text>
      <text x="50" y="445" className="text-xs fill-gray-700">• Process: 28nm/16nm/7nm</text>
    </svg>
  );

  const renderPEDetail = () => (
    <svg viewBox="0 0 800 600" className={`w-full h-auto ${className}`}>
      {/* Background */}
      <rect width="800" height="600" fill="#f8fafc" stroke="#e2e8f0" strokeWidth="2"/>
      
      {/* Title */}
      <text x="400" y="30" textAnchor="middle" className="text-lg font-bold fill-gray-800">
        Processing Element (PE) Internal Architecture
      </text>
      
      {/* Single PE Detail */}
      <rect x="50" y="80" width="300" height="400" fill="#f0fdf4" stroke="#16a34a" strokeWidth="3" rx="10"/>
      <text x="200" y="105" textAnchor="middle" className="text-md font-bold fill-gray-800">Single Processing Element</text>
      
      {/* Weight Register */}
      <rect x="80" y="130" width="80" height="40" fill="#fef3c7" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="120" y="145" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Weight Reg</text>
      <text x="120" y="160" textAnchor="middle" className="text-xs fill-gray-600">8-bit</text>
      
      {/* Data Input */}
      <rect x="80" y="200" width="80" height="40" fill="#dbeafe" stroke="#3b82f6" strokeWidth="2" rx="5"/>
      <text x="120" y="215" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Data In</text>
      <text x="120" y="230" textAnchor="middle" className="text-xs fill-gray-600">8-bit</text>
      
      {/* Multiplier */}
      <rect x="200" y="165" width="80" height="50" fill="#fdf2f8" stroke="#ec4899" strokeWidth="2" rx="5"/>
      <text x="240" y="185" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Multiplier</text>
      <text x="240" y="200" textAnchor="middle" className="text-xs fill-gray-600">8×8→16bit</text>
      
      {/* Accumulator */}
      <rect x="200" y="250" width="80" height="50" fill="#f0f9ff" stroke="#0ea5e9" strokeWidth="2" rx="5"/>
      <text x="240" y="270" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Accumulator</text>
      <text x="240" y="285" textAnchor="middle" className="text-xs fill-gray-600">32-bit</text>
      
      {/* Data Output */}
      <rect x="200" y="330" width="80" height="40" fill="#dcfce7" stroke="#16a34a" strokeWidth="2" rx="5"/>
      <text x="240" y="345" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Data Out</text>
      <text x="240" y="360" textAnchor="middle" className="text-xs fill-gray-600">8-bit</text>
      
      {/* Control Logic */}
      <rect x="80" y="400" width="200" height="40" fill="#f3e8ff" stroke="#8b5cf6" strokeWidth="2" rx="5"/>
      <text x="180" y="415" textAnchor="middle" className="text-sm font-semibold fill-gray-800">Control Logic</text>
      <text x="180" y="430" textAnchor="middle" className="text-xs fill-gray-600">Enable, Clear, Load Signals</text>
      
      {/* Systolic Array Overview */}
      <rect x="400" y="80" width="350" height="400" fill="#fffbeb" stroke="#f59e0b" strokeWidth="3" rx="10"/>
      <text x="575" y="105" textAnchor="middle" className="text-md font-bold fill-gray-800">16×16 Systolic Array</text>
      
      {/* PE Grid Representation */}
      {Array.from({length: 8}, (_, i) => 
        Array.from({length: 8}, (_, j) => (
          <rect key={`pe-grid-${i}-${j}`} 
                x={430 + j * 35} 
                y={130 + i * 35} 
                width="30" 
                height="30" 
                fill="#fef3c7" 
                stroke="#f59e0b" 
                strokeWidth="1" 
                rx="3"/>
        ))
      )}
      
      {/* Data Flow Arrows */}
      {/* Horizontal arrows (activation flow) */}
      {Array.from({length: 8}, (_, i) => 
        Array.from({length: 7}, (_, j) => (
          <path key={`h-arrow-${i}-${j}`} 
                d={`M${465 + j * 35} ${145 + i * 35} L${475 + j * 35} ${145 + i * 35}`} 
                stroke="#3b82f6" 
                strokeWidth="2" 
                markerEnd="url(#arrowhead-blue)"/>
        ))
      )}
      
      {/* Vertical arrows (weight flow) */}
      {Array.from({length: 7}, (_, i) => 
        Array.from({length: 8}, (_, j) => (
          <path key={`v-arrow-${i}-${j}`} 
                d={`M${445 + j * 35} ${165 + i * 35} L${445 + j * 35} ${175 + i * 35}`} 
                stroke="#16a34a" 
                strokeWidth="2" 
                markerEnd="url(#arrowhead-green)"/>
        ))
      )}
      
      {/* Weight Stationary Labels */}
      <text x="575" y="420" textAnchor="middle" className="text-sm font-bold fill-gray-800">Weight-Stationary Dataflow</text>
      <text x="430" y="440" className="text-xs fill-blue-600">→ Activations flow horizontally</text>
      <text x="430" y="455" className="text-xs fill-green-600">↓ Weights loaded vertically</text>
      
      {/* Connections in single PE */}
      <path d="M120 170 L200 190" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M160 220 L200 190" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M240 215 L240 250" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M240 300 L240 330" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M160 240 L200 350" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* Arrow markers */}
      <defs>
        <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#374151"/>
        </marker>
        <marker id="arrowhead-blue" markerWidth="8" markerHeight="6" 
                refX="7" refY="3" orient="auto">
          <polygon points="0 0, 8 3, 0 6" fill="#3b82f6"/>
        </marker>
        <marker id="arrowhead-green" markerWidth="8" markerHeight="6" 
                refX="7" refY="3" orient="auto">
          <polygon points="0 0, 8 3, 0 6" fill="#16a34a"/>
        </marker>
      </defs>
      
      {/* Performance metrics */}
      <text x="50" y="520" className="text-sm font-bold fill-gray-800">PE Specifications:</text>
      <text x="50" y="540" className="text-xs fill-gray-700">• MAC Operation: 1 cycle @ 1GHz</text>
      <text x="50" y="555" className="text-xs fill-gray-700">• Total PEs: 256 (16×16 array)</text>
      <text x="50" y="570" className="text-xs fill-gray-700">• Peak Throughput: 512 GOPS</text>
      
      <text x="400" y="520" className="text-sm font-bold fill-gray-800">Array Features:</text>
      <text x="400" y="540" className="text-xs fill-gray-700">• Weight-stationary dataflow</text>
      <text x="400" y="555" className="text-xs fill-gray-700">• Configurable precision (INT8/16, FP16)</text>
      <text x="400" y="570" className="text-xs fill-gray-700">• Optimized for CNN workloads</text>
    </svg>
  );

  const renderMemoryArchitecture = () => (
    <svg viewBox="0 0 800 600" className={`w-full h-auto ${className}`}>
      {/* Background */}
      <rect width="800" height="600" fill="#f8fafc" stroke="#e2e8f0" strokeWidth="2"/>
      
      {/* Title */}
      <text x="400" y="30" textAnchor="middle" className="text-lg font-bold fill-gray-800">
        Memory Subsystem Architecture
      </text>
      
      {/* External DDR */}
      <rect x="50" y="80" width="150" height="80" fill="#fef3c7" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="125" y="105" textAnchor="middle" className="text-md font-bold fill-gray-800">External DDR</text>
      <text x="125" y="125" textAnchor="middle" className="text-sm fill-gray-700">Model Storage</text>
      <text x="125" y="140" textAnchor="middle" className="text-sm fill-gray-700">Large Tensors</text>
      <text x="125" y="155" textAnchor="middle" className="text-xs fill-gray-600">GB capacity</text>
      
      {/* AXI Interface */}
      <rect x="250" y="100" width="100" height="40" fill="#dbeafe" stroke="#3b82f6" strokeWidth="2" rx="5"/>
      <text x="300" y="115" textAnchor="middle" className="text-sm font-semibold fill-gray-800">AXI4 Master</text>
      <text x="300" y="130" textAnchor="middle" className="text-xs fill-gray-600">128-bit, 12.8GB/s</text>
      
      {/* On-chip Memory Container */}
      <rect x="400" y="60" width="350" height="480" fill="#f0f9ff" stroke="#0ea5e9" strokeWidth="3" rx="10"/>
      <text x="575" y="85" textAnchor="middle" className="text-lg font-bold fill-gray-800">On-Chip Memory (528KB)</text>
      
      {/* Weight Buffer */}
      <rect x="420" y="110" width="150" height="120" fill="#ecfdf5" stroke="#10b981" strokeWidth="2" rx="5"/>
      <text x="495" y="130" textAnchor="middle" className="text-md font-bold fill-gray-800">Weight Buffer</text>
      <text x="495" y="150" textAnchor="middle" className="text-sm fill-gray-700">256KB SRAM</text>
      <text x="495" y="170" textAnchor="middle" className="text-sm fill-gray-700">16 Banks</text>
      <text x="495" y="190" textAnchor="middle" className="text-xs fill-gray-600">Sequential Read</text>
      <text x="495" y="205" textAnchor="middle" className="text-xs fill-gray-600">DMA Write</text>
      <text x="495" y="220" textAnchor="middle" className="text-xs fill-gray-600">16GB/s bandwidth</text>
      
      {/* Activation Buffer */}
      <rect x="590" y="110" width="150" height="120" fill="#fef7ff" stroke="#a855f7" strokeWidth="2" rx="5"/>
      <text x="665" y="130" textAnchor="middle" className="text-md font-bold fill-gray-800">Activation Buffer</text>
      <text x="665" y="150" textAnchor="middle" className="text-sm fill-gray-700">256KB SRAM</text>
      <text x="665" y="170" textAnchor="middle" className="text-sm fill-gray-700">16 Banks</text>
      <text x="665" y="190" textAnchor="middle" className="text-xs fill-gray-600">Random R/W</text>
      <text x="665" y="205" textAnchor="middle" className="text-xs fill-gray-600">Double Buffered</text>
      <text x="665" y="220" textAnchor="middle" className="text-xs fill-gray-600">16GB/s bandwidth</text>
      
      {/* Instruction Buffer */}
      <rect x="420" y="250" width="150" height="80" fill="#fffbeb" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="495" y="270" textAnchor="middle" className="text-md font-bold fill-gray-800">Instruction Buffer</text>
      <text x="495" y="290" textAnchor="middle" className="text-sm fill-gray-700">16KB SRAM</text>
      <text x="495" y="305" textAnchor="middle" className="text-sm fill-gray-700">2 Banks</text>
      <text x="495" y="320" textAnchor="middle" className="text-xs fill-gray-600">Sequential Fetch</text>
      
      {/* PE Array */}
      <rect x="420" y="350" width="310" height="100" fill="#f0fdf4" stroke="#16a34a" strokeWidth="2" rx="5"/>
      <text x="575" y="375" textAnchor="middle" className="text-md font-bold fill-gray-800">PE Array (16×16)</text>
      <text x="575" y="395" textAnchor="middle" className="text-sm fill-gray-700">256 Processing Elements</text>
      <text x="575" y="415" textAnchor="middle" className="text-sm fill-gray-700">Systolic Array</text>
      <text x="575" y="435" textAnchor="middle" className="text-xs fill-gray-600">Peak: 512 GOPS @ 1GHz</text>
      
      {/* Double Buffering Illustration */}
      <rect x="590" y="250" width="150" height="80" fill="#fdf2f8" stroke="#ec4899" strokeWidth="2" rx="5"/>
      <text x="665" y="270" textAnchor="middle" className="text-md font-bold fill-gray-800">Double Buffering</text>
      
      {/* Buffer A */}
      <rect x="610" y="280" width="50" height="20" fill="#dcfce7" stroke="#16a34a" strokeWidth="1" rx="2"/>
      <text x="635" y="292" textAnchor="middle" className="text-xs fill-gray-800">Buffer A</text>
      
      {/* Buffer B */}
      <rect x="670" y="280" width="50" height="20" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="2"/>
      <text x="695" y="292" textAnchor="middle" className="text-xs fill-gray-800">Buffer B</text>
      
      <text x="665" y="315" textAnchor="middle" className="text-xs fill-gray-600">Compute ↔ Load Overlap</text>
      
      {/* Memory Hierarchy */}
      <rect x="50" y="200" width="300" height="200" fill="#f9fafb" stroke="#6b7280" strokeWidth="2" rx="5"/>
      <text x="200" y="220" textAnchor="middle" className="text-md font-bold fill-gray-800">Memory Hierarchy</text>
      
      {/* Level indicators */}
      <rect x="70" y="240" width="260" height="30" fill="#fee2e2" stroke="#dc2626" strokeWidth="1" rx="3"/>
      <text x="90" y="255" className="text-sm font-semibold fill-gray-800">L1: PE Registers</text>
      <text x="250" y="255" className="text-xs fill-gray-600">~1KB, 1 cycle</text>
      
      <rect x="70" y="280" width="260" height="30" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="3"/>
      <text x="90" y="295" className="text-sm font-semibold fill-gray-800">L2: On-chip SRAM</text>
      <text x="250" y="295" className="text-xs fill-gray-600">528KB, 2-3 cycles</text>
      
      <rect x="70" y="320" width="260" height="30" fill="#dbeafe" stroke="#3b82f6" strokeWidth="1" rx="3"/>
      <text x="90" y="335" className="text-sm font-semibold fill-gray-800">L3: External DDR</text>
      <text x="250" y="335" className="text-xs fill-gray-600">GB scale, 100+ cycles</text>
      
      <text x="200" y="370" textAnchor="middle" className="text-sm font-bold fill-gray-800">Bandwidth vs Latency Trade-off</text>
      
      {/* Data Flow Arrows */}
      <path d="M200 120 L250 120" stroke="#374151" strokeWidth="3" markerEnd="url(#arrowhead)"/>
      <path d="M350 120 L420 170" stroke="#374151" strokeWidth="3" markerEnd="url(#arrowhead)"/>
      <path d="M350 120 L590 170" stroke="#374151" strokeWidth="3" markerEnd="url(#arrowhead)"/>
      <path d="M350 120 L420 290" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      <path d="M495 230 L575 350" stroke="#16a34a" strokeWidth="3" markerEnd="url(#arrowhead-green)"/>
      <path d="M665 230 L575 350" stroke="#a855f7" strokeWidth="3" markerEnd="url(#arrowhead-purple)"/>
      <path d="M495 330 L575 350" stroke="#f59e0b" strokeWidth="2" markerEnd="url(#arrowhead-yellow)"/>
      
      {/* Arrow markers */}
      <defs>
        <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#374151"/>
        </marker>
        <marker id="arrowhead-green" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#16a34a"/>
        </marker>
        <marker id="arrowhead-purple" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#a855f7"/>
        </marker>
        <marker id="arrowhead-yellow" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#f59e0b"/>
        </marker>
      </defs>
      
      {/* Performance specs */}
      <text x="50" y="450" className="text-sm font-bold fill-gray-800">Memory Performance:</text>
      <text x="50" y="470" className="text-xs fill-gray-700">• Total On-chip: 528KB SRAM</text>
      <text x="50" y="485" className="text-xs fill-gray-700">• Internal Bandwidth: 16GB/s per buffer</text>
      <text x="50" y="500" className="text-xs fill-gray-700">• External Bandwidth: 12.8GB/s (AXI4)</text>
      <text x="50" y="515" className="text-xs fill-gray-700">• Double buffering eliminates stalls</text>
      <text x="50" y="530" className="text-xs fill-gray-700">• Optimized for CNN data patterns</text>
    </svg>
  );

  const renderDataFlowPipeline = () => (
    <svg viewBox="0 0 800 600" className={`w-full h-auto ${className}`}>
      {/* Background */}
      <rect width="800" height="600" fill="#f8fafc" stroke="#e2e8f0" strokeWidth="2"/>
      
      {/* Title */}
      <text x="400" y="30" textAnchor="middle" className="text-lg font-bold fill-gray-800">
        Data Flow Pipeline & Execution Model
      </text>
      
      {/* Pipeline Stages */}
      <text x="50" y="70" className="text-md font-bold fill-gray-800">4-Stage Execution Pipeline:</text>
      
      {/* Stage 1: Fetch */}
      <rect x="50" y="90" width="150" height="60" fill="#fef3c7" stroke="#f59e0b" strokeWidth="2" rx="5"/>
      <text x="125" y="110" textAnchor="middle" className="text-sm font-bold fill-gray-800">FETCH</text>
      <text x="125" y="125" textAnchor="middle" className="text-xs fill-gray-700">Load instructions</text>
      <text x="125" y="140" textAnchor="middle" className="text-xs fill-gray-700">from inst buffer</text>
      
      {/* Stage 2: Decode */}
      <rect x="220" y="90" width="150" height="60" fill="#dbeafe" stroke="#3b82f6" strokeWidth="2" rx="5"/>
      <text x="295" y="110" textAnchor="middle" className="text-sm font-bold fill-gray-800">DECODE</text>
      <text x="295" y="125" textAnchor="middle" className="text-xs fill-gray-700">Decode instruction</text>
      <text x="295" y="140" textAnchor="middle" className="text-xs fill-gray-700">Setup DMA</text>
      
      {/* Stage 3: Execute */}
      <rect x="390" y="90" width="150" height="60" fill="#f0fdf4" stroke="#16a34a" strokeWidth="2" rx="5"/>
      <text x="465" y="110" textAnchor="middle" className="text-sm font-bold fill-gray-800">EXECUTE</text>
      <text x="465" y="125" textAnchor="middle" className="text-xs fill-gray-700">PE array compute</text>
      <text x="465" y="140" textAnchor="middle" className="text-xs fill-gray-700">Activation, pooling</text>
      
      {/* Stage 4: Writeback */}
      <rect x="560" y="90" width="150" height="60" fill="#fdf2f8" stroke="#ec4899" strokeWidth="2" rx="5"/>
      <text x="635" y="110" textAnchor="middle" className="text-sm font-bold fill-gray-800">WRITEBACK</text>
      <text x="635" y="125" textAnchor="middle" className="text-xs fill-gray-700">Store results to</text>
      <text x="635" y="140" textAnchor="middle" className="text-xs fill-gray-700">buffer or memory</text>
      
      {/* Pipeline arrows */}
      <path d="M200 120 L220 120" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M370 120 L390 120" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      <path d="M540 120 L560 120" stroke="#374151" strokeWidth="2" markerEnd="url(#arrowhead)"/>
      
      {/* Timeline */}
      <text x="50" y="200" className="text-md font-bold fill-gray-800">Overlapped Execution Timeline:</text>
      
      {/* Time axis */}
      <line x1="50" y1="240" x2="750" y2="240" stroke="#6b7280" strokeWidth="2"/>
      {Array.from({length: 8}, (_, i) => (
        <g key={`time-${i}`}>
          <line x1={50 + i * 100} y1="235" x2={50 + i * 100} y2="245" stroke="#6b7280" strokeWidth="2"/>
          <text x={50 + i * 100} y="255" textAnchor="middle" className="text-xs fill-gray-600">T{i}</text>
        </g>
      ))}
      
      {/* Layer N execution */}
      <text x="30" y="280" className="text-sm font-semibold fill-gray-800">Layer N:</text>
      <rect x="50" y="270" width="80" height="20" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="2"/>
      <rect x="130" y="270" width="80" height="20" fill="#dbeafe" stroke="#3b82f6" strokeWidth="1" rx="2"/>
      <rect x="210" y="270" width="80" height="20" fill="#f0fdf4" stroke="#16a34a" strokeWidth="1" rx="2"/>
      <rect x="290" y="270" width="80" height="20" fill="#fdf2f8" stroke="#ec4899" strokeWidth="1" rx="2"/>
      
      {/* Layer N+1 execution */}
      <text x="20" y="310" className="text-sm font-semibold fill-gray-800">Layer N+1:</text>
      <rect x="130" y="300" width="80" height="20" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="2"/>
      <rect x="210" y="300" width="80" height="20" fill="#dbeafe" stroke="#3b82f6" strokeWidth="1" rx="2"/>
      <rect x="290" y="300" width="80" height="20" fill="#f0fdf4" stroke="#16a34a" strokeWidth="1" rx="2"/>
      <rect x="370" y="300" width="80" height="20" fill="#fdf2f8" stroke="#ec4899" strokeWidth="1" rx="2"/>
      
      {/* Layer N+2 execution */}
      <text x="20" y="340" className="text-sm font-semibold fill-gray-800">Layer N+2:</text>
      <rect x="210" y="330" width="80" height="20" fill="#fef3c7" stroke="#f59e0b" strokeWidth="1" rx="2"/>
      <rect x="290" y="330" width="80" height="20" fill="#dbeafe" stroke="#3b82f6" strokeWidth="1" rx="2"/>
      <rect x="370" y="330" width="80" height="20" fill="#f0fdf4" stroke="#16a34a" strokeWidth="1" rx="2"/>
      <rect x="450" y="330" width="80" height="20" fill="#fdf2f8" stroke="#ec4899" strokeWidth="1" rx="2"/>
      
      {/* Convolution Mapping */}
      <text x="50" y="390" className="text-md font-bold fill-gray-800">Convolution Tiling Strategy:</text>
      
      <rect x="50" y="410" width="700" height="150" fill="#f9fafb" stroke="#6b7280" strokeWidth="2" rx="5"/>
      
      {/* Pseudo-code */}
      <text x="70" y="430" className="text-sm font-mono fill-gray-800">for (oc_tile = 0; oc_tile &lt; output_channels; oc_tile += 16) {</text>
      <text x="90" y="445" className="text-sm font-mono fill-gray-800">for (ic_tile = 0; ic_tile &lt; input_channels; ic_tile += 16) {</text>
      <text x="110" y="460" className="text-sm font-mono fill-blue-600">// Load weight tile [16 x 16 x K x K]</text>
      <text x="110" y="475" className="text-sm font-mono fill-gray-800">DMA.load(weights[oc_tile:oc_tile+16, ic_tile:ic_tile+16, :, :])</text>
      
      <text x="110" y="495" className="text-sm font-mono fill-gray-800">for (oh_tile = 0; oh_tile &lt; output_height; oh_tile += TILE_H) {</text>
      <text x="130" y="510" className="text-sm font-mono fill-gray-800">for (ow_tile = 0; ow_tile &lt; output_width; ow_tile += TILE_W) {</text>
      <text x="150" y="525" className="text-sm font-mono fill-green-600">// Compute on PE array</text>
      <text x="150" y="540" className="text-sm font-mono fill-gray-800">PE_Array.compute(); // 16x16 tile processing</text>
      <text x="130" y="555" className="text-sm font-mono fill-gray-800">}</text>
      <text x="110" y="570" className="text-sm font-mono fill-gray-800">}</text>
      <text x="90" y="585" className="text-sm font-mono fill-gray-800">}</text>
      <text x="70" y="600" className="text-sm font-mono fill-gray-800">}</text>
      
      {/* Arrow markers */}
      <defs>
        <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#374151"/>
        </marker>
      </defs>
    </svg>
  );

  switch (type) {
    case 'system-overview':
      return renderSystemOverview();
    case 'pe-detail':
      return renderPEDetail();
    case 'memory-architecture':
      return renderMemoryArchitecture();
    case 'dataflow-pipeline':
      return renderDataFlowPipeline();
    default:
      return renderSystemOverview();
  }
};

export default ArchitectureDiagrams;