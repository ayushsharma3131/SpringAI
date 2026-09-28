package com.example.ragdemo;

import com.example.ragdemo.controller.RagController;
import com.example.ragdemo.model.RagModels.AskResponse;
import com.example.ragdemo.service.DocumentIngestionService;
import com.example.ragdemo.service.RagQueryService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(RagController.class)
class RagControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private DocumentIngestionService ingestionService;

    @MockBean
    private RagQueryService ragQueryService;

    @Test
    void ask_returnsAnswerFromRagQueryService() throws Exception {
        when(ragQueryService.ask("What is pgvector?"))
                .thenReturn(new AskResponse("pgvector is a Postgres extension for vector similarity search.", List.of()));

        mockMvc.perform(post("/api/rag/ask")
                        .contentType("application/json")
                        .content("{\"question\":\"What is pgvector?\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.answer").value("pgvector is a Postgres extension for vector similarity search."));
    }

    @Test
    void health_returnsOk() throws Exception {
        mockMvc.perform(get("/api/rag/health"))
                .andExpect(status().isOk())
                .andExpect(content().string("OK"));
    }
}
