package com.steptrack.service;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

/**
 * Real Claude-backed implementation of {@link ConsultantAiClient}. Model is Claude Haiku 4.5
 * - the user's explicit choice for cost, not a default we picked - which does not support
 * the {@code thinking} or {@code effort} parameters, so neither is set here; sending either
 * to this model returns an error.
 *
 * <p>Excluded from the {@code test} profile - {@code StubConsultantAiClient} (test sources)
 * takes over there, so {@code mvn verify} never calls the real, paid Anthropic API.
 */
@Service
@Profile("!test")
public class AnthropicConsultantAiClient implements ConsultantAiClient {

    private static final String MODEL = "claude-haiku-4-5";
    private static final long MAX_TOKENS = 1024L;

    private final AnthropicClient client;

    public AnthropicConsultantAiClient(@Value("${anthropic.api-key}") String apiKey) {
        this.client = (apiKey == null || apiKey.isBlank())
                ? null
                : AnthropicOkHttpClient.builder().apiKey(apiKey).build();
    }

    @Override
    public String getAdvice(String systemPrompt, String userPrompt) {
        if (client == null) {
            throw new IllegalStateException("ANTHROPIC_API_KEY is not configured");
        }

        MessageCreateParams params = MessageCreateParams.builder()
                .model(MODEL)
                .maxTokens(MAX_TOKENS)
                .system(systemPrompt)
                .addUserMessage(userPrompt)
                .build();

        Message response = client.messages().create(params);
        StringBuilder advice = new StringBuilder();
        response.content().forEach(block -> block.text().ifPresent(t -> advice.append(t.text())));
        return advice.toString();
    }
}
