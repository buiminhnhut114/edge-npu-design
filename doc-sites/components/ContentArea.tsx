import React from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { Copy, Check, AlertCircle, Info, AlertTriangle, Clock, ThumbsUp, ThumbsDown } from 'lucide-react';
import { ArchitectureDiagram } from './ArchitectureDiagram';
import type { PageContent, ContentBlock } from '../types';

interface ContentAreaProps {
    content: PageContent;
}

interface CodeBlockProps {
    code: string;
    language: string;
}

const CodeBlock: React.FC<CodeBlockProps> = ({ code, language }) => {
    const [copied, setCopied] = React.useState(false);

    const handleCopy = async () => {
        await navigator.clipboard.writeText(code);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    const languageLabels: Record<string, string> = {
        'verilog': 'SystemVerilog',
        'c': 'C',
        'python': 'Python',
        'bash': 'Shell',
        'text': 'Plain Text',
    };

    return (
        <div className="code-block">
            <div className="code-header">
                <span className="code-language">{languageLabels[language] || language}</span>
                <button className="copy-button" onClick={handleCopy} aria-label="Copy code">
                    {copied ? <Check size={14} /> : <Copy size={14} />}
                    <span>{copied ? 'Copied!' : 'Copy'}</span>
                </button>
            </div>
            <SyntaxHighlighter
                language={language === 'verilog' ? 'verilog' : language}
                style={oneDark}
                customStyle={{
                    margin: 0,
                    padding: '1.25rem',
                    background: '#0f172a',
                    borderRadius: '0 0 8px 8px',
                    fontSize: '0.875rem',
                    lineHeight: '1.6',
                }}
                showLineNumbers={code.split('\n').length > 5}
                lineNumberStyle={{
                    minWidth: '2.5em',
                    paddingRight: '1em',
                    color: '#475569',
                    userSelect: 'none',
                }}
            >
                {code}
            </SyntaxHighlighter>
        </div>
    );
};

interface AlertBlockProps {
    type: string;
    content: string;
}

const AlertBlock: React.FC<AlertBlockProps> = ({ type, content }) => {
    const icons: Record<string, React.ReactNode> = {
        note: <Info size={18} />,
        warning: <AlertTriangle size={18} />,
        error: <AlertCircle size={18} />,
    };

    const labels: Record<string, string> = {
        note: 'Note',
        warning: 'Warning',
        error: 'Error',
    };

    return (
        <div className={`alert-block alert-${type}`} role="alert">
            <div className="alert-icon">
                {icons[type] || <Info size={18} />}
            </div>
            <div className="alert-content">
                <span className="alert-label">{labels[type] || 'Info'}</span>
                <p>{content}</p>
            </div>
        </div>
    );
};

interface TableBlockProps {
    content: string;
}

const TableBlock: React.FC<TableBlockProps> = ({ content }) => {
    try {
        const data = JSON.parse(content);
        return (
            <div className="table-wrapper">
                <table className="content-table">
                    <thead>
                        <tr>
                            {data.headers.map((header: string, i: number) => (
                                <th key={i}>{header}</th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {data.rows.map((row: string[], i: number) => (
                            <tr key={i}>
                                {row.map((cell: string, j: number) => (
                                    <td key={j}>{cell}</td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        );
    } catch {
        return <p className="error-text">Invalid table data</p>;
    }
};

const renderBlock = (block: ContentBlock, index: number): React.ReactNode => {
    switch (block.type) {
        case 'heading': {
            const level = block.level || 2;
            const id = block.content.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, '');
            const HeadingTag = `h${level}` as keyof JSX.IntrinsicElements;
            return (
                <HeadingTag key={index} id={id}>
                    {block.content}
                </HeadingTag>
            );
        }

        case 'paragraph':
            return <p key={index} dangerouslySetInnerHTML={{ __html: block.content }} />;

        case 'code':
            return <CodeBlock key={index} code={block.content} language={block.language || 'text'} />;

        case 'table':
            return <TableBlock key={index} content={block.content} />;

        case 'diagram':
            return <ArchitectureDiagram key={index} type={block.content} />;

        case 'note':
            return <AlertBlock key={index} type="note" content={block.content} />;

        case 'warning':
            return <AlertBlock key={index} type="warning" content={block.content} />;

        case 'list':
            return (
                <ul key={index} className="content-list">
                    {block.items?.map((item: string, i: number) => (
                        <li key={i} dangerouslySetInnerHTML={{ __html: item }} />
                    ))}
                </ul>
            );

        default:
            return null;
    }
};

export const ContentArea: React.FC<ContentAreaProps> = ({ content }) => {
    const [feedback, setFeedback] = React.useState<'yes' | 'no' | null>(null);

    const handleFeedback = (value: 'yes' | 'no') => {
        setFeedback(value);
        // Could send analytics here
    };

    return (
        <article className="content-area">
            <header className="content-header">
                <h1>{content.title}</h1>
                <p className="content-description">{content.description}</p>
                <div className="content-meta">
                    <span className="meta-item">
                        <Clock size={14} />
                        Last updated: {content.lastUpdated}
                    </span>
                </div>
            </header>

            <div className="content-body">
                {content.blocks.map((block: ContentBlock, index: number) => renderBlock(block, index))}
            </div>

            <footer className="content-footer">
                <div className="feedback-section">
                    <span>Was this page helpful?</span>
                    <div className="feedback-buttons">
                        <button 
                            className={`feedback-btn ${feedback === 'yes' ? 'active' : ''}`}
                            onClick={() => handleFeedback('yes')}
                            aria-pressed={feedback === 'yes'}
                        >
                            <ThumbsUp size={16} />
                            Yes
                        </button>
                        <button 
                            className={`feedback-btn ${feedback === 'no' ? 'active' : ''}`}
                            onClick={() => handleFeedback('no')}
                            aria-pressed={feedback === 'no'}
                        >
                            <ThumbsDown size={16} />
                            No
                        </button>
                    </div>
                    {feedback && (
                        <span className="feedback-thanks">Thanks for your feedback!</span>
                    )}
                </div>
            </footer>
        </article>
    );
};
