package com.steptrack.service;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

/**
 * Replaces {@link AnthropicConsultantAiClient} under the {@code test} profile so integration
 * tests never call the real, paid Anthropic API. Lives in test sources but is picked up by
 * the same {@code com.steptrack} component scan as any other bean, since the test classpath
 * includes both source roots.
 */
@Service
@Profile("test")
public class StubConsultantAiClient implements ConsultantAiClient {

    public static final String CANNED_ADVICE =
            "Great progress this week - keep up the consistent walking!";

    @Override
    public String getAdvice(String systemPrompt, String userPrompt) {
        return CANNED_ADVICE;
    }
}
