package com.example.leg.notifications;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class NotificationController {
    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);

    private final FirebaseMessaging firebaseMessaging;

    public NotificationController(FirebaseMessaging firebaseMessaging) {
        this.firebaseMessaging = firebaseMessaging;
    }

    @PostMapping("/me/fcm-token")
    ApiResponse<Map<String, Boolean>> registerFcmToken(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody FcmTokenRequest request) {
        log.info(
                "Registered FCM token for user {} on {}",
                principal.id(),
                request.platform());
        return ApiResponse.of(Map.of("registered", firebaseMessaging != null));
    }

    public record FcmTokenRequest(@NotBlank String token, @NotBlank String platform) {
    }
}
