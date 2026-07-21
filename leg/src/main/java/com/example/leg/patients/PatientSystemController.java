package com.example.leg.patients;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Read models consumed by the current patient mobile shell. */
@RestController
@RequestMapping("/api/v1")
public class PatientSystemController {
    private static final UUID DEVICE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID EXERCISE_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");
    private final AuthService authService;

    public PatientSystemController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping("/patients/{patientId}")
    public ApiResponse<Map<String, Object>> patient(@PathVariable UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        var user = requireSelf(patientId, principal);
        return ApiResponse.of(Map.of(
                "id", user.getId(), "display_name", user.getDisplayName(), "email", user.getEmailNormalized(),
                "locale", user.getLocale(), "timezone", user.getTimezone(), "version", 1));
    }

    @GetMapping("/patients/{patientId}/plan-items/today")
    public ApiResponse<List<Map<String, Object>>> today(@PathVariable UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(List.of(
                plan("30000000-0000-0000-0000-000000000001", "Đứng lên và ngồi xuống", "strength", 2, 8, 600, "planned"),
                plan("30000000-0000-0000-0000-000000000002", "Nâng gối có hỗ trợ", "mobility", 3, 6, 480, "planned")));
    }

    @GetMapping("/patients/{patientId}/progress/overview")
    public ApiResponse<Map<String, Object>> progress(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "week") String period,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(Map.of("period", period, "planned_count", 8, "completed_count", 6,
                "active_seconds", 3240, "correctness_ratio", .81, "warning_count", 3,
                "critical_count", 0, "streak_days", 4));
    }

    @GetMapping("/devices")
    public ApiResponse<List<Map<String, Object>>> devices(@RequestParam("patient_id") UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(List.of(device()));
    }

    @GetMapping("/devices/{deviceId}")
    public ApiResponse<Map<String, Object>> device(@PathVariable UUID deviceId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null || !DEVICE_ID.equals(deviceId)) throw denied();
        return ApiResponse.of(device());
    }

    private Map<String, Object> plan(String id, String name, String category, int sets, int reps, int seconds, String status) {
        return Map.of("id", UUID.fromString(id), "plan_id", UUID.randomUUID(),
                "exercise", Map.of("id", EXERCISE_ID, "code", "sit_to_stand", "name", name, "category", category),
                "target", Map.of("kind", "repetitions", "sets", sets, "repetitions_per_set", reps, "rest_seconds", 60),
                "safe_config", Map.of("assistance_level", "low", "limit_profile_id", UUID.randomUUID()),
                "status", status, "estimated_duration_seconds", seconds);
    }     

    private Map<String, Object> device() {
        return Map.ofEntries(Map.entry("id", DEVICE_ID), Map.entry("serial_number", "EXO-2026-000123"),
                Map.entry("model", "exo-leg-v1"), Map.entry("firmware_version", "1.2.0"),
                Map.entry("protocol_version", 1), Map.entry("online", true), Map.entry("last_seen_at", Instant.now()),
                Map.entry("battery_percent", 78), Map.entry("readiness", Map.of("state", "ready", "blocking_reasons", List.of())),
                Map.entry("health", Map.of("sensors", "ok", "motors", "ok", "controller", "ok", "estop", "ok")),
                Map.entry("calibration", Map.of("status", "valid", "expires_at", LocalDate.now().plusDays(31).toString())));
    }

    private com.example.leg.identity.UserEntity requireSelf(UUID patientId, AuthenticatedUser principal) {
        if (principal == null) throw denied();
        var user = authService.requireUser(principal.id());
        if (!user.getId().equals(patientId)) throw denied();
        return user;
    }

    private ApiException denied() {
        return new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền xem dữ liệu này.");
    }
}
