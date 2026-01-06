# EdgeNPU Documentation Site

Professional technical documentation for EdgeNPU - a high-performance Neural Processing Unit for Edge AI applications.

## Features

- 📚 Comprehensive documentation covering architecture, programming, and integration
- 🎨 Modern dark/light theme with professional styling
- 🔍 Full-text search capability
- 📱 Responsive design for all devices
- ⚡ Fast navigation with React + Vite
- 🖼️ Interactive architecture diagrams

## Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Project Structure

```
doc-site/
├── components/          # React components
│   ├── Header.tsx       # Navigation header
│   ├── Sidebar.tsx      # Documentation sidebar
│   ├── ContentArea.tsx  # Main content renderer
│   ├── PageSummary.tsx  # Table of contents
│   └── ArchitectureDiagram.tsx  # SVG diagrams
├── data/
│   └── content.ts       # Documentation content
├── styles/
│   └── index.css        # Global styles
├── App.tsx              # Main application
├── metadata.json        # Navigation structure
└── types.ts             # TypeScript definitions
```

## Documentation Sections

1. **Overview** - Introduction, features, specifications
2. **Architecture** - System design, PE array, memory, DMA
3. **Programming Model** - ISA, registers, quantization
4. **Integration Guide** - SoC integration, AXI interface
5. **Software SDK** - C/C++ and Python APIs
6. **Getting Started** - Quick start, setup, examples

## Technology Stack

- React 18
- TypeScript
- Vite 5
- Lucide React (icons)
- React Syntax Highlighter

## License

Proprietary - EdgeNPU Team
