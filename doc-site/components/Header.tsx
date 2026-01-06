import React from 'react';
import { Search, Menu, Moon, Sun, Github, BookOpen, Code, Cpu } from 'lucide-react';

interface HeaderProps {
    projectName: string;
    version: string;
    onSearch: (query: string) => void;
    onToggleSidebar: () => void;
}

export const Header: React.FC<HeaderProps> = ({
    projectName,
    version,
    onSearch,
    onToggleSidebar,
}) => {
    const [darkMode, setDarkMode] = React.useState(true);
    const [searchValue, setSearchValue] = React.useState('');

    const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        setSearchValue(e.target.value);
        onSearch(e.target.value);
    };

    const toggleDarkMode = () => {
        setDarkMode(!darkMode);
        document.documentElement.classList.toggle('light-mode');
    };

    return (
        <header className="header">
            <div className="header-left">
                <button
                    className="menu-toggle"
                    onClick={onToggleSidebar}
                    aria-label="Toggle menu"
                >
                    <Menu size={20} />
                </button>

                <div className="logo">
                    <div className="logo-icon">
                        <svg viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <rect x="2" y="2" width="36" height="36" rx="8" fill="url(#npu-gradient)" />
                            <g fill="white" opacity="0.9">
                                <rect x="8" y="8" width="6" height="6" rx="1" />
                                <rect x="17" y="8" width="6" height="6" rx="1" />
                                <rect x="26" y="8" width="6" height="6" rx="1" />
                                <rect x="8" y="17" width="6" height="6" rx="1" />
                                <rect x="17" y="17" width="6" height="6" rx="1" />
                                <rect x="26" y="17" width="6" height="6" rx="1" />
                                <rect x="8" y="26" width="6" height="6" rx="1" />
                                <rect x="17" y="26" width="6" height="6" rx="1" />
                                <rect x="26" y="26" width="6" height="6" rx="1" />
                            </g>
                            <defs>
                                <linearGradient id="npu-gradient" x1="2" y1="2" x2="38" y2="38">
                                    <stop stopColor="#3b82f6" />
                                    <stop offset="0.5" stopColor="#6366f1" />
                                    <stop offset="1" stopColor="#8b5cf6" />
                                </linearGradient>
                            </defs>
                        </svg>
                    </div>
                    <div className="logo-text-container">
                        <span className="logo-text">{projectName}</span>
                        <span className="logo-tagline">Documentation</span>
                    </div>
                    <span className="version-badge">v{version}</span>
                </div>
            </div>

            <div className="header-center">
                <div className="search-container">
                    <Search size={18} className="search-icon" />
                    <input
                        type="text"
                        placeholder="Search documentation..."
                        value={searchValue}
                        onChange={handleSearchChange}
                        className="search-input"
                    />
                    <kbd className="search-shortcut">⌘K</kbd>
                </div>
            </div>

            <div className="header-right">
                <nav className="header-nav">
                    <a href="#overview" className="nav-link">
                        <BookOpen size={16} />
                        <span>Docs</span>
                    </a>
                    <a href="#c-api" className="nav-link">
                        <Code size={16} />
                        <span>API</span>
                    </a>
                    <a href="#specifications" className="nav-link">
                        <Cpu size={16} />
                        <span>Specs</span>
                    </a>
                </nav>

                <div className="header-divider" />

                <div className="header-actions">
                    <button
                        className="icon-button"
                        onClick={toggleDarkMode}
                        aria-label="Toggle dark mode"
                        title={darkMode ? 'Switch to light mode' : 'Switch to dark mode'}
                    >
                        {darkMode ? <Sun size={18} /> : <Moon size={18} />}
                    </button>

                    <a
                        href="https://github.com/edgenpu/EdgeNPU"
                        className="icon-button github-link"
                        target="_blank"
                        rel="noopener noreferrer"
                        aria-label="View on GitHub"
                        title="View on GitHub"
                    >
                        <Github size={18} />
                    </a>
                </div>
            </div>
        </header>
    );
};
