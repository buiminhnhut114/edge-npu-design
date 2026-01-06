import React, { useState } from 'react';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { ContentArea } from './components/ContentArea';
import { PageSummary } from './components/PageSummary';
import metadata from './metadata.json';
import { getContent } from './data/content';

const App: React.FC = () => {
    const [currentPage, setCurrentPage] = useState('introduction');
    const [sidebarOpen, setSidebarOpen] = useState(true);
    const [, setSearchQuery] = useState('');

    const content = getContent(currentPage);

    const handleNavigate = (pageId: string) => {
        setCurrentPage(pageId);
        window.scrollTo(0, 0);
    };

    const handleSearch = (query: string) => {
        setSearchQuery(query);
        // Implement search functionality
    };

    return (
        <div className="app">
            <Header
                projectName={metadata.projectName}
                version={metadata.version}
                onSearch={handleSearch}
                onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
            />

            <div className="main-container">
                <Sidebar
                    sections={metadata.sections}
                    currentPage={currentPage}
                    onNavigate={handleNavigate}
                    isOpen={sidebarOpen}
                />

                <main className="content-wrapper">
                    <ContentArea content={content} />
                    <PageSummary content={content} />
                </main>
            </div>
        </div>
    );
};

export default App;
