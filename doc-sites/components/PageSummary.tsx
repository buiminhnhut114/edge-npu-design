import React from 'react';
import { Edit3 } from 'lucide-react';
import type { PageContent, ContentBlock } from '../types';

interface PageSummaryProps {
    content: PageContent;
}

interface HeadingItem {
    text: string;
    level: number;
    id: string;
}

export const PageSummary: React.FC<PageSummaryProps> = ({ content }) => {
    const headings: HeadingItem[] = content.blocks
        .filter((block: ContentBlock) => block.type === 'heading')
        .map((block: ContentBlock) => ({
            text: block.content,
            level: block.level || 2,
            id: block.content.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, ''),
        }));

    const [activeId, setActiveId] = React.useState<string>('');

    React.useEffect(() => {
        const observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        setActiveId(entry.target.id);
                    }
                });
            },
            { rootMargin: '-20% 0% -70% 0%', threshold: 0.1 }
        );

        headings.forEach((heading) => {
            const element = document.getElementById(heading.id);
            if (element) observer.observe(element);
        });

        return () => observer.disconnect();
    }, [headings]);

    const scrollToSection = (id: string) => {
        const element = document.getElementById(id);
        if (element) {
            const headerOffset = 80;
            const elementPosition = element.getBoundingClientRect().top;
            const offsetPosition = elementPosition + window.pageYOffset - headerOffset;
            
            window.scrollTo({
                top: offsetPosition,
                behavior: 'smooth'
            });
        }
    };

    if (headings.length === 0) {
        return null;
    }

    return (
        <aside className="page-summary">
            <div className="summary-header">
                <span>On this page</span>
            </div>

            <nav className="summary-nav" aria-label="Table of contents">
                <ul>
                    {headings.map((heading, index) => (
                        <li
                            key={index}
                            className={`summary-item level-${heading.level} ${activeId === heading.id ? 'active' : ''}`}
                        >
                            <button 
                                onClick={() => scrollToSection(heading.id)}
                                aria-current={activeId === heading.id ? 'location' : undefined}
                            >
                                {heading.text}
                            </button>
                        </li>
                    ))}
                </ul>
            </nav>

            <div className="summary-footer">
                <a 
                    href="https://github.com/edgenpu/EdgeNPU/edit/main/docs" 
                    className="edit-link"
                    target="_blank"
                    rel="noopener noreferrer"
                >
                    <Edit3 size={14} />
                    Edit this page
                </a>
            </div>
        </aside>
    );
};
