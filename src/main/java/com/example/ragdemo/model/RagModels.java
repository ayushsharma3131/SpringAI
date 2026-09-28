package com.example.ragdemo.model;

import java.util.List;
import java.util.Map;

public class RagModels {

    public record IngestResponse(int chunksIndexed, String message) {}

    public record AskRequest(String question) {}

    public record AskResponse(String answer, List<SourceChunk> sources) {}

    public record SourceChunk(String content, Map<String, Object> metadata) {}
}
