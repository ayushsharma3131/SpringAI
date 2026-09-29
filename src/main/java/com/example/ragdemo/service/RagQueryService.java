package com.example.ragdemo.service;

import com.example.ragdemo.model.RagModels.AskResponse;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.document.Document;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class RagQueryService {

    private final ChatClient chatClient;
    private final VectorStore vectorStore;

    public RagQueryService(ChatClient chatClient, VectorStore vectorStore) {
        this.chatClient = chatClient;
        this.vectorStore = vectorStore;
    }

    /**
     * Answers a question using RAG. The QuestionAnswerAdvisor configured on the
     * ChatClient bean handles retrieval + prompt augmentation automatically.
     * We separately re-run the similarity search here purely to surface the
     * source chunk metadata back to the caller for citation/auditability.
     */
    public AskResponse ask(String question) {
        String answer = chatClient.prompt()
                .user(question)
                .call()
                .content();

        List<Document> retrieved = vectorStore.similaritySearch(
                SearchRequest.builder()
                        .query(question)
                        .topK(5)
                        .similarityThreshold(0.0)
                        .build()
        );

        List<Map<String, Object>> metadata = retrieved.stream()
                .map(Document::getMetadata)
                .toList();

        return new AskResponse(answer, metadata);
    }
}
