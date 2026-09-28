package com.example.ragdemo.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.QuestionAnswerAdvisor;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ChatClientConfig {

    /**
     * Wraps the chat model with a QuestionAnswerAdvisor, which:
     *  1. Embeds the incoming user question
     *  2. Runs a similarity search against the VectorStore (pgvector)
     *  3. Stuffs the retrieved chunks into the system prompt as context
     *  4. Sends the augmented prompt to the chat model
     */
    @Bean
    public ChatClient chatClient(ChatClient.Builder builder, VectorStore vectorStore) {
        SearchRequest searchRequest = SearchRequest.builder()
                .topK(5)
                .similarityThreshold(0.75)
                .build();

        return builder
                .defaultAdvisors(new QuestionAnswerAdvisor(vectorStore, searchRequest))
                .build();
    }
}
