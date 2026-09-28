# spring-ai-rag

A minimal Retrieval-Augmented Generation (RAG) service built with Spring Boot, Spring AI,
and Postgres/pgvector as the vector store.

## Stack

- Spring Boot 3.3
- Spring AI 1.0 (`ChatClient` + `QuestionAnswerAdvisor` + `PgVectorStore`)
- Postgres 16 with the `pgvector` extension
- OpenAI for chat + embedding models (swap for Ollama/Azure/Bedrock by changing the starter)

## Prerequisites

- Java 17+
- Maven 3.9+
- Docker (for Postgres)
- An `OPENAI_API_KEY` environment variable

## Run it

1. Start Postgres:

   ```bash
   docker compose up -d
   ```

2. Export your API key:

   ```bash
   export OPENAI_API_KEY=sk-...
   ```

3. Run the app:

   ```bash
   ./mvnw spring-boot:run
   ```

   The app starts on `http://localhost:8080`. On first boot, Spring AI's
   `initialize-schema: true` setting creates the `vector_store` table and the
   `vector` extension in Postgres automatically.

## API

### Ingest a document

```bash
curl -X POST http://localhost:8080/api/rag/ingest \
  -F "file=@/path/to/doc.pdf"
```

Response:

```json
{ "chunksIndexed": 12, "message": "Indexed doc.pdf" }
```

### Ask a question

```bash
curl -X POST http://localhost:8080/api/rag/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What does this document say about refund policy?"}'
```

Response:

```json
{
  "answer": "...",
  "sources": [
    { "content": "...chunk text...", "metadata": { "source": "doc.pdf" } }
  ]
}
```

## Tests

```bash
./mvnw test
```

The included test mocks `DocumentIngestionService` / `RagQueryService`, so it runs
without a live Postgres or OpenAI connection.

## Notes / things to tune for production

- **Chunking**: `TokenTextSplitter` params in `DocumentIngestionService` (chunk size,
  overlap) should be tuned to your document types — smaller chunks with overlap
  generally help retrieval precision on technical docs.
- **Embedding model / dimensions**: `text-embedding-3-small` = 1536 dims. If you
  switch models, update `spring.ai.vectorstore.pgvector.dimensions` to match, or
  the table schema will be wrong.
- **Index type**: HNSW is a good default for approximate nearest-neighbor search
  at scale; `IVFFLAT` is the other pgvector option if you need faster index builds
  at the cost of recall.
- **Multi-tenancy**: attach a `tenantId` (or similar) to document metadata at
  ingestion time and use `SearchRequest.filterExpression(...)` to scope retrieval.
- **Auth**: no security is configured here — add Spring Security before exposing
  `/api/rag/ingest` beyond local dev.
