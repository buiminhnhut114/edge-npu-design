// EdgeNPU Gemini AI Service
// Dịch vụ AI cho tìm kiếm thông minh và trợ lý tài liệu

interface GeminiResponse {
    answer: string;
    sources: string[];
    confidence: number;
}

interface SearchParams {
    query: string;
    context?: string;
    language?: 'vi' | 'en';
}

class GeminiService {
    private apiKey: string;
    private baseUrl: string = 'https://generativelanguage.googleapis.com/v1beta';
    private model: string = 'gemini-pro';

    constructor(apiKey?: string) {
        this.apiKey = apiKey || import.meta.env.VITE_GEMINI_API_KEY || '';
    }

    /**
     * Thiết lập API key
     */
    setApiKey(key: string): void {
        this.apiKey = key;
    }

    /**
     * Kiểm tra API đã được cấu hình
     */
    isConfigured(): boolean {
        return this.apiKey.length > 0;
    }

    /**
     * Tìm kiếm thông minh trong tài liệu
     */
    async smartSearch(params: SearchParams): Promise<GeminiResponse> {
        if (!this.isConfigured()) {
            throw new Error('Gemini API key chưa được cấu hình');
        }

        const systemPrompt = params.language === 'vi'
            ? `Bạn là trợ lý AI cho tài liệu EdgeNPU - bộ xử lý neural network. 
         Trả lời câu hỏi dựa trên ngữ cảnh tài liệu được cung cấp.
         Trả lời bằng tiếng Việt, ngắn gọn và chính xác.`
            : `You are an AI assistant for EdgeNPU documentation - a neural network processor.
         Answer questions based on the provided documentation context.
         Be concise and accurate.`;

        const prompt = `${systemPrompt}

Ngữ cảnh tài liệu:
${params.context || 'Không có ngữ cảnh cụ thể'}

Câu hỏi: ${params.query}

Trả lời:`;

        try {
            const response = await fetch(
                `${this.baseUrl}/models/${this.model}:generateContent?key=${this.apiKey}`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        contents: [{
                            parts: [{ text: prompt }]
                        }],
                        generationConfig: {
                            temperature: 0.3,
                            topK: 40,
                            topP: 0.95,
                            maxOutputTokens: 1024,
                        },
                    }),
                }
            );

            if (!response.ok) {
                throw new Error(`API error: ${response.status}`);
            }

            const data = await response.json();
            const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

            return {
                answer: text,
                sources: this.extractSources(text),
                confidence: this.calculateConfidence(data),
            };
        } catch (error) {
            console.error('Gemini API error:', error);
            throw error;
        }
    }

    /**
     * Trích xuất nguồn tham chiếu từ câu trả lời
     */
    private extractSources(text: string): string[] {
        const sourcePattern = /\[([^\]]+)\]/g;
        const matches = text.matchAll(sourcePattern);
        return Array.from(matches).map(m => m[1]);
    }

    /**
     * Tính độ tin cậy của câu trả lời
     */
    private calculateConfidence(data: any): number {
        const safetyRatings = data.candidates?.[0]?.safetyRatings || [];
        const avgProbability = safetyRatings.reduce(
            (acc: number, r: any) => acc + (1 - (r.probability === 'LOW' ? 0.1 : r.probability === 'MEDIUM' ? 0.5 : 0.9)),
            0
        ) / Math.max(safetyRatings.length, 1);

        return Math.min(avgProbability, 0.95);
    }

    /**
     * Tạo gợi ý hoàn thành code
     */
    async getCodeCompletion(code: string, language: string): Promise<string> {
        if (!this.isConfigured()) {
            return '';
        }

        const prompt = `Hoàn thành đoạn code ${language} sau cho EdgeNPU:

\`\`\`${language}
${code}
\`\`\`

Chỉ trả về phần code cần hoàn thành, không có giải thích:`;

        try {
            const response = await this.smartSearch({
                query: prompt,
                language: 'vi',
            });

            // Trích xuất code block từ response
            const codeMatch = response.answer.match(/```[\w]*\n?([\s\S]*?)```/);
            return codeMatch ? codeMatch[1].trim() : response.answer;
        } catch {
            return '';
        }
    }

    /**
     * Giải thích khái niệm kỹ thuật
     */
    async explainConcept(concept: string): Promise<string> {
        const prompt = `Giải thích khái niệm "${concept}" trong ngữ cảnh EdgeNPU - bộ xử lý neural network.
    Trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu, có ví dụ nếu cần.`;

        try {
            const response = await this.smartSearch({
                query: prompt,
                language: 'vi',
            });
            return response.answer;
        } catch (error) {
            return `Không thể giải thích khái niệm "${concept}". Vui lòng thử lại sau.`;
        }
    }
}

// Export singleton instance
export const geminiService = new GeminiService();
export default geminiService;
