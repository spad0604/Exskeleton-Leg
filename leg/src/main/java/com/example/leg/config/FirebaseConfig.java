package com.example.leg.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.core.io.Resource;

@Configuration
public class FirebaseConfig {
    @Bean
    @ConditionalOnExpression("T(org.springframework.util.StringUtils).hasText('${app.firebase.service-account:}') or T(org.springframework.util.StringUtils).hasText('${app.firebase.service-account-json:}')")
    FirebaseApp firebaseApp(
            @Value("${app.firebase.service-account:}") Resource serviceAccount,
            @Value("${app.firebase.service-account-json:}") String serviceAccountJson)
            throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        var input = serviceAccountJson != null && !serviceAccountJson.isBlank()
                ? new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8))
                : serviceAccount.getInputStream();
        try (input) {
            var options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(input))
                    .build();
            return FirebaseApp.initializeApp(options);
        }
    }

    @Bean
    @ConditionalOnExpression("T(org.springframework.util.StringUtils).hasText('${app.firebase.service-account:}') or T(org.springframework.util.StringUtils).hasText('${app.firebase.service-account-json:}')")
    FirebaseMessaging firebaseMessaging(FirebaseApp firebaseApp) {
        return FirebaseMessaging.getInstance(firebaseApp);
    }
}
