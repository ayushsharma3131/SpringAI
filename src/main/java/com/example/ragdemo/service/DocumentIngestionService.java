package com.example.ragdemo.service;

import org.springframework.ai.document.Document;
import org.springframework.ai.reader.tika.TikaDocumentReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@Service
public class DocumentIngestionService {

    private final VectorStore vectorStore;

    public DocumentIngestionService(VectorStore vectorStore) {
        this.vectorStore = vectorStore;
    }

    /**
     * Reads an uploaded file, splits it into chunks, embeds each chunk
     * and writes it to the pgvector-backed VectorStore.
     *
     * @return number of chunks indexed
     */
    public int ingest(MultipartFile file) {
        try {
            Resource resource = file.getResource();

            TikaDocumentReader reader = new TikaDocumentReader(resource);
            List<Document> rawDocs = reader.get();

            // Tag every chunk with its source filename so it can be cited later
            rawDocs.forEach(doc -> doc.getMetadata().put("source", file.getOriginalFilename()));

            TokenTextSplitter splitter = new TokenTextSplitter();
            List<Document> chunks = splitter.apply(rawDocs);

            vectorStore.add(chunks);
            return chunks.size();
        } catch (Exception e) {
            throw new IngestionException("Failed to ingest file: " + file.getOriginalFilename(), e);
        }
    }

    public int ingestText(String text, String sourceName) {
        Document doc = new Document(text, Map.of("source", sourceName));
        TokenTextSplitter splitter = new TokenTextSplitter();
        List<Document> chunks = splitter.apply(List.of(doc));
        vectorStore.add(chunks);
        return chunks.size();
    }

    public static class IngestionException extends RuntimeException {
        public IngestionException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
