import React from 'react';

interface ArchitectureDiagramProps {
    type: string;
}

export const ArchitectureDiagram: React.FC<ArchitectureDiagramProps> = ({ type }) => {
    if (type === 'system-overview') {
        return (
            <div className="architecture-diagram">
                <svg viewBox="0 0 900 550" className="diagram-svg">
                    {/* Background */}
                    <defs>
                        <linearGradient id="bg-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#0f172a" />
                            <stop offset="100%" stopColor="#1e293b" />
                        </linearGradient>
                        <linearGradient id="compute-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#4f46e5" />
                            <stop offset="100%" stopColor="#6366f1" />
                        </linearGradient>
                        <linearGradient id="memory-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#0369a1" />
                            <stop offset="100%" stopColor="#0ea5e9" />
                        </linearGradient>
                        <linearGradient id="post-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#047857" />
                            <stop offset="100%" stopColor="#10b981" />
                        </linearGradient>
                        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
                            <feDropShadow dx="0" dy="4" stdDeviation="8" floodOpacity="0.3"/>
                        </filter>
                        <marker id="arrow" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
                            <polygon points="0 0, 10 3.5, 0 7" fill="#6366f1" />
                        </marker>
                        <marker id="arrow-blue" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
                            <polygon points="0 0, 10 3.5, 0 7" fill="#0ea5e9" />
                        </marker>
                    </defs>
                    
                    <rect x="0" y="0" width="900" height="550" fill="url(#bg-gradient)" rx="12" />

                    {/* Title */}
                    <text x="450" y="35" textAnchor="middle" fill="#f8fafc" fontSize="18" fontWeight="600" letterSpacing="0.5">
                        EdgeNPU System Architecture
                    </text>
                    <text x="450" y="55" textAnchor="middle" fill="#64748b" fontSize="12">
                        16×16 Systolic Array • 512 GOPS Peak • &lt;500mW
                    </text>

                    {/* External Memory */}
                    <g filter="url(#shadow)">
                        <rect x="30" y="85" width="120" height="380" fill="#1e293b" rx="8" stroke="#334155" strokeWidth="1" />
                        <text x="90" y="115" textAnchor="middle" fill="#94a3b8" fontSize="11" fontWeight="500">External</text>
                        <text x="90" y="130" textAnchor="middle" fill="#94a3b8" fontSize="11" fontWeight="500">Memory</text>
                        <rect x="45" y="150" width="90" height="30" fill="#334155" rx="4" />
                        <text x="90" y="170" textAnchor="middle" fill="#cbd5e1" fontSize="10">DDR4/LPDDR</text>
                        <rect x="45" y="195" width="90" height="25" fill="#334155" rx="4" />
                        <text x="90" y="212" textAnchor="middle" fill="#64748b" fontSize="9">Weights</text>
                        <rect x="45" y="230" width="90" height="25" fill="#334155" rx="4" />
                        <text x="90" y="247" textAnchor="middle" fill="#64748b" fontSize="9">Activations</text>
                        <rect x="45" y="265" width="90" height="25" fill="#334155" rx="4" />
                        <text x="90" y="282" textAnchor="middle" fill="#64748b" fontSize="9">Instructions</text>
                    </g>

                    {/* Main NPU Block */}
                    <g filter="url(#shadow)">
                        <rect x="180" y="85" width="690" height="380" fill="#1e293b" rx="10" stroke="#3b82f6" strokeWidth="2" strokeOpacity="0.5" />
                        <text x="525" y="105" textAnchor="middle" fill="#3b82f6" fontSize="12" fontWeight="600">EdgeNPU Core</text>
                    </g>

                    {/* AXI Interface */}
                    <g>
                        <rect x="200" y="115" width="650" height="45" fill="#1e3a5f" rx="6" stroke="#3b82f6" strokeWidth="1.5" />
                        <text x="525" y="143" textAnchor="middle" fill="#f8fafc" fontSize="12" fontWeight="500">AXI4 Master (128-bit) + AXI4-Lite Slave (32-bit)</text>
                    </g>

                    {/* DMA Engine */}
                    <g filter="url(#shadow)">
                        <rect x="200" y="175" width="180" height="80" fill="url(#memory-gradient)" rx="8" fillOpacity="0.9" />
                        <text x="290" y="200" textAnchor="middle" fill="#f8fafc" fontSize="12" fontWeight="600">DMA Engine</text>
                        <text x="290" y="218" textAnchor="middle" fill="#e0f2fe" fontSize="10">4 Channels</text>
                        <g transform="translate(220, 230)">
                            <rect x="0" y="0" width="30" height="18" fill="#0c4a6e" rx="3" />
                            <text x="15" y="13" textAnchor="middle" fill="#7dd3fc" fontSize="8">CH0</text>
                            <rect x="35" y="0" width="30" height="18" fill="#0c4a6e" rx="3" />
                            <text x="50" y="13" textAnchor="middle" fill="#7dd3fc" fontSize="8">CH1</text>
                            <rect x="70" y="0" width="30" height="18" fill="#0c4a6e" rx="3" />
                            <text x="85" y="13" textAnchor="middle" fill="#7dd3fc" fontSize="8">CH2</text>
                            <rect x="105" y="0" width="30" height="18" fill="#0c4a6e" rx="3" />
                            <text x="120" y="13" textAnchor="middle" fill="#7dd3fc" fontSize="8">CH3</text>
                        </g>
                    </g>

                    {/* Memory Buffers */}
                    <g>
                        <rect x="400" y="175" width="130" height="80" fill="#0c4a6e" rx="6" stroke="#0ea5e9" strokeWidth="1" />
                        <text x="465" y="200" textAnchor="middle" fill="#f8fafc" fontSize="11" fontWeight="500">Weight Buffer</text>
                        <text x="465" y="218" textAnchor="middle" fill="#7dd3fc" fontSize="10">256 KB</text>
                        <text x="465" y="235" textAnchor="middle" fill="#64748b" fontSize="9">16 Banks × 128-bit</text>

                        <rect x="545" y="175" width="130" height="80" fill="#0c4a6e" rx="6" stroke="#0ea5e9" strokeWidth="1" />
                        <text x="610" y="200" textAnchor="middle" fill="#f8fafc" fontSize="11" fontWeight="500">Act Buffer</text>
                        <text x="610" y="218" textAnchor="middle" fill="#7dd3fc" fontSize="10">256 KB</text>
                        <text x="610" y="235" textAnchor="middle" fill="#64748b" fontSize="9">Double-buffered</text>

                        <rect x="690" y="175" width="90" height="80" fill="#0c4a6e" rx="6" stroke="#0ea5e9" strokeWidth="1" />
                        <text x="735" y="200" textAnchor="middle" fill="#f8fafc" fontSize="11" fontWeight="500">Inst Buf</text>
                        <text x="735" y="218" textAnchor="middle" fill="#7dd3fc" fontSize="10">16 KB</text>
                    </g>

                    {/* Controller */}
                    <g filter="url(#shadow)">
                        <rect x="795" y="175" width="60" height="280" fill="#581c87" rx="6" stroke="#a855f7" strokeWidth="1" />
                        <text x="825" y="320" textAnchor="middle" fill="#f8fafc" fontSize="10" fontWeight="500" transform="rotate(-90, 825, 320)">Controller</text>
                    </g>

                    {/* PE Array */}
                    <g filter="url(#shadow)">
                        <rect x="200" y="275" width="280" height="180" fill="url(#compute-gradient)" rx="10" fillOpacity="0.95" />
                        <text x="340" y="300" textAnchor="middle" fill="#f8fafc" fontSize="14" fontWeight="600">PE Array (Systolic)</text>
                        <text x="340" y="318" textAnchor="middle" fill="#e0e7ff" fontSize="11">16 × 16 = 256 MACs</text>
                        
                        {/* PE Grid visualization */}
                        <g transform="translate(230, 335)">
                            {[0, 1, 2, 3, 4, 5].map(row =>
                                [0, 1, 2, 3, 4, 5].map(col => (
                                    <rect
                                        key={`pe-${row}-${col}`}
                                        x={col * 35}
                                        y={row * 18}
                                        width="30"
                                        height="14"
                                        fill="#818cf8"
                                        rx="2"
                                        opacity={0.6 + (row + col) * 0.03}
                                    />
                                ))
                            )}
                        </g>
                        <text x="340" y="450" textAnchor="middle" fill="#c7d2fe" fontSize="9">512 GOPS @ 1GHz (INT8)</text>
                    </g>

                    {/* Post Processing */}
                    <g filter="url(#shadow)">
                        <rect x="500" y="275" width="280" height="180" fill="url(#post-gradient)" rx="10" fillOpacity="0.9" />
                        <text x="640" y="300" textAnchor="middle" fill="#f8fafc" fontSize="14" fontWeight="600">Post-Processing</text>
                        
                        <rect x="520" y="320" width="75" height="40" fill="#064e3b" rx="5" />
                        <text x="557" y="345" textAnchor="middle" fill="#f8fafc" fontSize="10">Activation</text>
                        <text x="557" y="355" textAnchor="middle" fill="#6ee7b7" fontSize="8">ReLU/GELU</text>

                        <rect x="605" y="320" width="75" height="40" fill="#064e3b" rx="5" />
                        <text x="642" y="345" textAnchor="middle" fill="#f8fafc" fontSize="10">Pooling</text>
                        <text x="642" y="355" textAnchor="middle" fill="#6ee7b7" fontSize="8">Max/Avg</text>

                        <rect x="690" y="320" width="75" height="40" fill="#064e3b" rx="5" />
                        <text x="727" y="345" textAnchor="middle" fill="#f8fafc" fontSize="10">Quantize</text>
                        <text x="727" y="355" textAnchor="middle" fill="#6ee7b7" fontSize="8">INT8/FP16</text>

                        <rect x="560" y="380" width="160" height="35" fill="#064e3b" rx="5" />
                        <text x="640" y="402" textAnchor="middle" fill="#f8fafc" fontSize="10">Data Reshaper</text>

                        <rect x="560" y="425" width="160" height="25" fill="#064e3b" rx="5" />
                        <text x="640" y="442" textAnchor="middle" fill="#6ee7b7" fontSize="9">Output → Memory</text>
                    </g>

                    {/* Data Flow Arrows */}
                    <path d="M 150 275 L 180 275" stroke="#0ea5e9" strokeWidth="2" markerEnd="url(#arrow-blue)" />
                    <path d="M 290 255 L 290 275" stroke="#6366f1" strokeWidth="2" markerEnd="url(#arrow)" />
                    <path d="M 380 175 L 400 175" stroke="#0ea5e9" strokeWidth="1.5" strokeDasharray="4,2" />
                    <path d="M 465 255 L 340 275" stroke="#6366f1" strokeWidth="1.5" markerEnd="url(#arrow)" />
                    <path d="M 610 255 L 340 275" stroke="#6366f1" strokeWidth="1.5" markerEnd="url(#arrow)" />
                    <path d="M 480 365 L 500 365" stroke="#10b981" strokeWidth="2" markerEnd="url(#arrow)" />
                    <path d="M 640 450 L 640 470 L 150 470 L 150 350" stroke="#10b981" strokeWidth="1.5" strokeDasharray="5,3" />

                    {/* Legend */}
                    <g transform="translate(200, 490)">
                        <rect x="0" y="0" width="14" height="14" fill="url(#compute-gradient)" rx="3" />
                        <text x="20" y="11" fill="#94a3b8" fontSize="10">Compute</text>
                        
                        <rect x="100" y="0" width="14" height="14" fill="url(#memory-gradient)" rx="3" />
                        <text x="120" y="11" fill="#94a3b8" fontSize="10">Memory/DMA</text>
                        
                        <rect x="220" y="0" width="14" height="14" fill="url(#post-gradient)" rx="3" />
                        <text x="240" y="11" fill="#94a3b8" fontSize="10">Post-Processing</text>
                        
                        <rect x="360" y="0" width="14" height="14" fill="#581c87" rx="3" />
                        <text x="380" y="11" fill="#94a3b8" fontSize="10">Control</text>
                        
                        <line x1="460" y1="7" x2="490" y2="7" stroke="#6366f1" strokeWidth="2" />
                        <text x="500" y="11" fill="#94a3b8" fontSize="10">Data Flow</text>
                    </g>
                </svg>
            </div>
        );
    }

    if (type === 'pe-detail') {
        return (
            <div className="architecture-diagram">
                <svg viewBox="0 0 700 400" className="diagram-svg">
                    <defs>
                        <linearGradient id="pe-bg" x1="0%" y1="0%" x2="100%" y2="100%">
                            <stop offset="0%" stopColor="#0f172a" />
                            <stop offset="100%" stopColor="#1e293b" />
                        </linearGradient>
                        <filter id="pe-shadow" x="-20%" y="-20%" width="140%" height="140%">
                            <feDropShadow dx="0" dy="2" stdDeviation="4" floodOpacity="0.3"/>
                        </filter>
                    </defs>
                    
                    <rect x="0" y="0" width="700" height="400" fill="url(#pe-bg)" rx="12" />

                    <text x="350" y="30" textAnchor="middle" fill="#f8fafc" fontSize="16" fontWeight="600">
                        Processing Element (PE) Architecture
                    </text>
                    <text x="350" y="50" textAnchor="middle" fill="#64748b" fontSize="11">
                        Single-cycle MAC with systolic data propagation
                    </text>

                    {/* PE Box */}
                    <g filter="url(#pe-shadow)">
                        <rect x="150" y="70" width="400" height="260" fill="#1e3a5f" rx="10" stroke="#6366f1" strokeWidth="2" />
                        <text x="350" y="95" textAnchor="middle" fill="#a5b4fc" fontSize="12" fontWeight="500">Processing Element</text>
                    </g>

                    {/* Weight Register */}
                    <rect x="180" y="115" width="120" height="45" fill="#581c87" rx="6" />
                    <text x="240" y="135" textAnchor="middle" fill="#f8fafc" fontSize="11" fontWeight="500">Weight Register</text>
                    <text x="240" y="150" textAnchor="middle" fill="#d8b4fe" fontSize="9">8-bit (stationary)</text>

                    {/* Multiplier */}
                    <rect x="230" y="185" width="80" height="50" fill="#4f46e5" rx="6" />
                    <text x="270" y="210" textAnchor="middle" fill="#f8fafc" fontSize="14" fontWeight="600">×</text>
                    <text x="270" y="225" textAnchor="middle" fill="#c7d2fe" fontSize="9">8×8→16</text>

                    {/* Adder */}
                    <rect x="340" y="185" width="60" height="50" fill="#4f46e5" rx="6" />
                    <text x="370" y="215" textAnchor="middle" fill="#f8fafc" fontSize="14" fontWeight="600">+</text>

                    {/* Accumulator */}
                    <rect x="320" y="260" width="140" height="50" fill="#047857" rx="6" />
                    <text x="390" y="285" textAnchor="middle" fill="#f8fafc" fontSize="11" fontWeight="500">Accumulator</text>
                    <text x="390" y="300" textAnchor="middle" fill="#6ee7b7" fontSize="9">32-bit</text>

                    {/* Data In */}
                    <rect x="30" y="190" width="90" height="40" fill="#334155" rx="6" stroke="#64748b" strokeWidth="1" />
                    <text x="75" y="215" textAnchor="middle" fill="#f8fafc" fontSize="10">data_in</text>

                    {/* Data Out */}
                    <rect x="580" y="190" width="90" height="40" fill="#334155" rx="6" stroke="#64748b" strokeWidth="1" />
                    <text x="625" y="215" textAnchor="middle" fill="#f8fafc" fontSize="10">data_out</text>

                    {/* Acc Out */}
                    <rect x="355" y="340" width="90" height="35" fill="#334155" rx="6" stroke="#10b981" strokeWidth="1" />
                    <text x="400" y="362" textAnchor="middle" fill="#10b981" fontSize="10">acc_out</text>

                    {/* Weight In */}
                    <rect x="195" y="55" width="90" height="30" fill="#334155" rx="6" stroke="#a855f7" strokeWidth="1" />
                    <text x="240" y="75" textAnchor="middle" fill="#a855f7" fontSize="10">weight_in</text>

                    {/* Arrows */}
                    <path d="M 120 210 L 150 210" stroke="#94a3b8" strokeWidth="2" markerEnd="url(#arrow)" />
                    <path d="M 550 210 L 580 210" stroke="#94a3b8" strokeWidth="2" markerEnd="url(#arrow)" />
                    <path d="M 240 85 L 240 115" stroke="#a855f7" strokeWidth="1.5" markerEnd="url(#arrow)" />
                    <path d="M 240 160 L 240 185" stroke="#818cf8" strokeWidth="1.5" />
                    <path d="M 180 210 L 230 210" stroke="#818cf8" strokeWidth="1.5" />
                    <path d="M 310 210 L 340 210" stroke="#818cf8" strokeWidth="1.5" markerEnd="url(#arrow)" />
                    <path d="M 370 235 L 370 260" stroke="#818cf8" strokeWidth="1.5" />
                    <path d="M 390 310 L 390 340" stroke="#10b981" strokeWidth="2" markerEnd="url(#arrow)" />
                    <path d="M 460 285 L 500 285 L 500 210 L 400 210" stroke="#64748b" strokeWidth="1" strokeDasharray="4,2" />

                    {/* Formula */}
                    <text x="350" y="385" textAnchor="middle" fill="#94a3b8" fontSize="11">
                        acc[n+1] = acc[n] + (data_in × weight_reg)
                    </text>
                </svg>
            </div>
        );
    }

    return (
        <div className="architecture-diagram placeholder">
            <div className="placeholder-text">
                Diagram: {type}
            </div>
        </div>
    );
};
