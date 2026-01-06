// Định nghĩa các kiểu dữ liệu cho trang tài liệu EdgeNPU

export interface MenuItem {
    id: string;
    title: string;
    icon?: string;
    children?: MenuItem[];
}

export interface Section {
    id: string;
    title: string;
    items: MenuItem[];
}

export interface ContentBlock {
    type: 'paragraph' | 'heading' | 'code' | 'table' | 'diagram' | 'note' | 'warning' | 'list';
    content: string;
    language?: string;
    level?: number;
    items?: string[];
}

export interface PageContent {
    id: string;
    title: string;
    description: string;
    lastUpdated: string;
    blocks: ContentBlock[];
}

export interface TableData {
    headers: string[];
    rows: string[][];
}

export interface Metadata {
    projectName: string;
    version: string;
    description: string;
    author: string;
    lastUpdated: string;
    sections: Section[];
}

export interface SearchResult {
    id: string;
    title: string;
    excerpt: string;
    section: string;
}
