package com.steptrack.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Real Gemini-backed implementation of {@link ConsultantAiClient}, replacing the former
 * Anthropic Claude one. Model is the {@code gemini-flash-lite-latest} alias - same
 * cost-conscious reasoning the previous Claude Haiku 4.5 choice used (this is a one-shot,
 * low-stakes advice summary, not a task that benefits from a frontier model). An alias
 * rather than a pinned dated model name deliberately - confirmed live that
 * {@code gemini-2.5-flash} (this file's first choice) had already been deprecated for new
 * API keys by the time this shipped, returning a 404 telling callers to migrate; Google
 * keeps the {@code -latest} aliases pointed at a currently-supported model, so this avoids
 * needing a manual model-name bump every time the pinned one gets retired.
 *
 * <p>Talks to the plain Gemini REST API directly (no Google Gen AI SDK dependency) via
 * Spring's {@code RestClient}, already available through {@code spring-boot-starter-web} -
 * one more HTTP client dependency isn't worth it for a single, simple JSON POST.
 *
 * <p>Excluded from the {@code test} profile - {@code StubConsultantAiClient} (test sources)
 * takes over there, so {@code mvn verify} never calls the real, paid Gemini API.
 */
@Service
@Profile("!test")
public class GeminiConsultantAiClient implements ConsultantAiClient {

    private static final String MODEL = "gemini-flash-lite-latest";
    private static final String ENDPOINT =
            "https://generativelanguage.googleapis.com/v1beta/models/" + MODEL + ":generateContent";

    private final RestClient restClient = RestClient.create();
    private final ObjectMapper mapper = new ObjectMapper();
    private final String apiKey;

    public GeminiConsultantAiClient(@Value("${gemini.api-key}") String apiKey) {
        this.apiKey = apiKey;
    }

    @Override
    public String getAdvice(String systemPrompt, String userPrompt) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("GEMINI_API_KEY is not configured");
        }

        ObjectNode body = mapper.createObjectNode();
        body.putObject("systemInstruction")
                .putArray("parts")
                .addObject()
                .put("text", systemPrompt);

        ArrayNode contents = body.putArray("contents");
        contents.addObject()
                .putArray("parts")
                .addObject()
                .put("text", userPrompt);

        JsonNode response = restClient.post()
                .uri(ENDPOINT + "?key={key}", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(JsonNode.class);

        StringBuilder advice = new StringBuilder();
        if (response != null) {
            for (JsonNode part : response.path("candidates").path(0).path("content").path("parts")) {
                advice.append(part.path("text").asText(""));
            }
        }
        return advice.toString();
    }
}
