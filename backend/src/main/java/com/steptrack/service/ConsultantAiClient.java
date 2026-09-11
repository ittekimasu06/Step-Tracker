package com.steptrack.service;

/**
 * Wraps whatever LLM actually generates the consultant's advice text. The only interface in
 * this codebase - every other dependency (DB, JWT) is free and already fakeable via H2/test
 * config, but a real, per-call-billed external API is a genuinely new category: this exists
 * so the test suite can swap in a stub instead of spending real money in {@code mvn verify}.
 */
public interface ConsultantAiClient {
    String getAdvice(String systemPrompt, String userPrompt);
}
