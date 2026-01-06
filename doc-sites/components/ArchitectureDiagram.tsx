import React from 'react';
import ArchitectureDiagrams from './ArchitectureDiagrams';

interface ArchitectureDiagramProps {
    type: string;
}

export const ArchitectureDiagram: React.FC<ArchitectureDiagramProps> = ({ type }) => {
    return (
        <div className="bg-white p-4 rounded-lg border shadow-sm">
            <ArchitectureDiagrams type={type} className="w-full" />
        </div>
    );
};
