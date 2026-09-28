package com.example.ragdemo.controller;

import com.example.ragdemo.model.RagModels.AskRequest;
import com.example.ragdemo.model.RagModels.AskResponse;
import com.example.ragdemo.model.RagModels.IngestResponse;
import com.example.ragdemo.service.DocumentIngestionService;
import com.example.ragdemo.service.RagQueryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/rag")
public class RagController {

    private final DocumentIngestionService ingestionService;
    private final RagQueryService ragQueryService;

    public RagController(DocumentIngestionService ingestionService, RagQueryService ragQueryService) {
        this.ingestionService = ingestionService;
        this.ragQueryService = ragQueryService;
    }

    @PostMapping(value = "/ingest", consumes = "multipart/form-data")
    public ResponseEntity<IngestResponse> ingest(@RequestParam("file") MultipartFile file) {
        int chunks = ingestionService.ingest(file);
        return ResponseEntity.ok(new IngestResponse(chunks, "Indexed " + file.getOriginalFilename()));
    }

    @PostMapping("/ask")
    public ResponseEntity<AskResponse> ask(@RequestBody AskRequest request) {
        return ResponseEntity.ok(ragQueryService.ask(request.question()));
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("OK");
    }
}
