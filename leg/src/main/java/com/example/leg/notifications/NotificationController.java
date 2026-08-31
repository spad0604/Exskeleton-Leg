package com.example.leg.notifications;

import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.patients.PatientDataService;
import com.example.leg.shared.ApiResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class NotificationController {
    private static final Logger log = LoggerFactory.getLogger(NotificationController.class);

    private final FirebaseMessaging firebaseMessaging;
    private final PatientDataService patientData;

    public NotificationController(ObjectProvider<FirebaseMessaging> firebaseMessaging, PatientDataService patientData) {
        this.firebaseMessaging = firebaseMessaging.getIfAvailable();
        this.patientData = patientData;
    }

    @PostMapping("/me/fcm-token")
    ApiResponse<Map<String, Boolean>> registerFcmToken(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody FcmTokenRequest request) {
        if (principal == null) {
            throw new com.example.leg.shared.ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        patientData.registerToken(principal.id(), request.token(), request.platform());
        log.info("Registered FCM token for user {} on {}", principal.id(), request.platform());
        return ApiResponse.of(Map.of("registered", firebaseMessaging != null));
    }

    public record FcmTokenRequest(@NotBlank String token, @NotBlank String platform) {
    }

    @GetMapping("/me/notifications")
    ApiResponse<java.util.List<java.util.Map<String, Object>>> notifications(
            @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) {
            throw new com.example.leg.shared.ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        return ApiResponse.of(patientData.notifications(principal.id()));
    }
}
