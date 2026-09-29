# spring-ai-rag

A minimal Retrieval-Augmented Generation (RAG) service built with Spring Boot, Spring AI,
and Postgres/pgvector as the vector store.

## Stack

- Spring Boot 3.5
- Spring AI 1.1 (`ChatClient` + `QuestionAnswerAdvisor` + `PgVectorStore`)
- Postgres 16 with the `pgvector` extension
- Google GenAI (Gemini) for chat + embedding models

## Prerequisites

- Java 21+
- Docker (for Postgres)
- A `GEMINI_API_KEY` environment variable

No local Maven install needed — the project includes the Maven Wrapper
(`mvnw` / `mvnw.cmd`), which downloads and uses the correct Maven version
automatically on first run.

## Run it

1. Start Postgres:

   ```bash
   docker compose up -d
   ```

2. Export your API key:

   ```bash
   export GEMINI_API_KEY=your_key_here
   ```

3. Run the app:

   ```bash
   ./mvnw spring-boot:run       # macOS/Linux
   .\mvnw.cmd spring-boot:run   # Windows
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
  "metadata": [
    { "source": "doc.pdf", "distance": 0.15 }
  ]
}
```

## Tests

```bash
./mvnw test       # macOS/Linux
.\mvnw.cmd test   # Windows
```

The included test mocks `DocumentIngestionService` / `RagQueryService`, so it runs
without a live Postgres or Gemini connection.
