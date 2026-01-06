import React from 'react';
import {
    Home, Star, Cpu, FileText, Settings, Zap, Play,
    Grid, Database, ArrowRightLeft, Plug, Code, List,
    Terminal, TrendingUp, FileCode, BookOpen, Layers,
    Monitor, ChevronDown, ChevronRight, Package,
    Clock, CheckCircle, Sliders
} from 'lucide-react';
import type { Section, MenuItem } from '../types';

interface SidebarProps {
    sections: Section[];
    currentPage: string;
    onNavigate: (pageId: string) => void;
    isOpen: boolean;
}

const iconMap: Record<string, React.ReactNode> = {
    'home': <Home size={16} />,
    'star': <Star size={16} />,
    'cpu': <Cpu size={16} />,
    'file-text': <FileText size={16} />,
    'settings': <Settings size={16} />,
    'zap': <Zap size={16} />,
    'play': <Play size={16} />,
    'grid': <Grid size={16} />,
    'database': <Database size={16} />,
    'arrow-right-left': <ArrowRightLeft size={16} />,
    'plug': <Plug size={16} />,
    'code': <Code size={16} />,
    'list': <List size={16} />,
    'terminal': <Terminal size={16} />,
    'trending-up': <TrendingUp size={16} />,
    'file-code': <FileCode size={16} />,
    'book-open': <BookOpen size={16} />,
    'layers': <Layers size={16} />,
    'monitor': <Monitor size={16} />,
    'chip': <Cpu size={16} />,
    'package': <Package size={16} />,
    'clock': <Clock size={16} />,
    'check-circle': <CheckCircle size={16} />,
    'sliders': <Sliders size={16} />,
};

export const Sidebar: React.FC<SidebarProps> = ({
    sections,
    currentPage,
    onNavigate,
    isOpen,
}) => {
    const [expandedSections, setExpandedSections] = React.useState<string[]>(
        sections.map((s: Section) => s.id)
    );

    const toggleSection = (sectionId: string) => {
        setExpandedSections((prev: string[]) =>
            prev.includes(sectionId)
                ? prev.filter((id: string) => id !== sectionId)
                : [...prev, sectionId]
        );
    };

    return (
        <aside className={`sidebar ${isOpen ? 'open' : 'closed'}`}>
            <nav className="sidebar-nav" aria-label="Documentation navigation">
                {sections.map((section: Section) => (
                    <div key={section.id} className="sidebar-section">
                        <button
                            className="section-header"
                            onClick={() => toggleSection(section.id)}
                            aria-expanded={expandedSections.includes(section.id)}
                        >
                            {expandedSections.includes(section.id) ? (
                                <ChevronDown size={14} />
                            ) : (
                                <ChevronRight size={14} />
                            )}
                            <span>{section.title}</span>
                        </button>

                        {expandedSections.includes(section.id) && (
                            <ul className="section-items">
                                {section.items.map((item: MenuItem) => (
                                    <li key={item.id}>
                                        <button
                                            className={`nav-item ${currentPage === item.id ? 'active' : ''}`}
                                            onClick={() => onNavigate(item.id)}
                                            aria-current={currentPage === item.id ? 'page' : undefined}
                                        >
                                            {item.icon && iconMap[item.icon]}
                                            <span>{item.title}</span>
                                        </button>
                                    </li>
                                ))}
                            </ul>
                        )}
                    </div>
                ))}
            </nav>

            <div className="sidebar-footer">
                <div className="update-info">
                    <span className="update-label">Last updated</span>
                    <span className="update-date">January 6, 2026</span>
                </div>
            </div>
        </aside>
    );
};
