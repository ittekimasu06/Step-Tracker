package com.steptrack.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.Body;
import software.amazon.awssdk.services.ses.model.Content;
import software.amazon.awssdk.services.ses.model.Destination;
import software.amazon.awssdk.services.ses.model.Message;
import software.amazon.awssdk.services.ses.model.SendEmailRequest;

/**
 * Real AWS SES-backed implementation of {@link EmailService}. Uses the SDK's default
 * credential provider chain - when running on the EC2 instance this app is deployed to, that
 * resolves to the instance's attached IAM role (see AWS_OPERATIONS.md), so no access keys are
 * ever stored in `.env`. {@code fromAddress} must already be a verified SES identity, or every
 * send fails - see the deployment runbook for the one-time console verification step.
 *
 * <p>Excluded from the {@code test} profile - {@link StubEmailService} takes over there, so
 * {@code mvn verify} never sends a real email.
 */
@Service
@Profile("!test")
public class SesEmailService implements EmailService {

    private final SesClient client;
    private final String fromAddress;

    public SesEmailService(
            @Value("${aws.ses.region}") String region,
            @Value("${app.mail.from-address}") String fromAddress) {
        this.client = SesClient.builder().region(Region.of(region)).build();
        this.fromAddress = fromAddress;
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        SendEmailRequest request = SendEmailRequest.builder()
                .source(fromAddress)
                .destination(Destination.builder().toAddresses(toEmail).build())
                .message(Message.builder()
                        .subject(Content.builder().data("Your Steptrack verification code").build())
                        .body(Body.builder()
                                .text(Content.builder()
                                        .data("Your verification code is: " + code
                                                + "\n\nThis code expires in 15 minutes.")
                                        .build())
                                .build())
                        .build())
                .build();
        client.sendEmail(request);
    }
}
