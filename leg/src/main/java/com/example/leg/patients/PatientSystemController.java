package com.example.leg.patients;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
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
    private final AuthService authService;
    private final PatientDataService patientData;

    public PatientSystemController(AuthService authService, PatientDataService patientData) {
        this.authService = authService;
        this.patientData = patientData;
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
        return ApiResponse.of(patientData.plans(patientId, "today"));

    }

    @GetMapping("/exercises")
    public ApiResponse<List<Map<String, Object>>> exercises(@AuthenticationPrincipal AuthenticatedUser principal) {
        requireAuthenticated(principal);
        return ApiResponse.of(patientData.exercises());
    }

    @GetMapping("/exercises/{exerciseId}")
    public ApiResponse<Map<String, Object>> exercise(@PathVariable UUID exerciseId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireAuthenticated(principal);
        try {
            return ApiResponse.of(patientData.exercise(exerciseId));
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            throw new ApiException(HttpStatus.NOT_FOUND, "exercise.not_found", "Không tìm thấy bài tập.");
        }
    }

    @GetMapping("/patients/{patientId}/plan-items")
    public ApiResponse<List<Map<String, Object>>> allPlans(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "all") String scope,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        if (!scope.equals("all") && !scope.equals("today")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "validation.invalid_scope", "Scope không hợp lệ.");
        }
        return ApiResponse.of(patientData.plans(patientId, scope));
    }

    @GetMapping("/patients/{patientId}/progress/overview")
    public ApiResponse<Map<String, Object>> progress(@PathVariable UUID patientId,
            @RequestParam(defaultValue = "week") String period,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        if (!period.equals("week") && !period.equals("month")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "validation.invalid_period", "Period không hợp lệ.");
        }
        return ApiResponse.of(patientData.progress(patientId, period));
    }

    @GetMapping("/devices")
    public ApiResponse<List<Map<String, Object>>> devices(@RequestParam("patient_id") UUID patientId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        requireSelf(patientId, principal);
        return ApiResponse.of(patientData.devices(patientId));
    }

    @GetMapping("/devices/{deviceId}")
    public ApiResponse<Map<String, Object>> device(@PathVariable UUID deviceId,
            @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) throw denied();
        var devices = patientData.devices(principal.id());
        return devices.stream().filter(device -> deviceId.equals(device.get("id"))).findFirst()
                .map(ApiResponse::of).orElseThrow(this::denied);
    }

    private com.example.leg.identity.UserEntity requireSelf(UUID patientId, AuthenticatedUser principal) {
        if (principal == null) throw denied();
        var user = authService.requireUser(principal.id());
        if (!user.getId().equals(patientId)) throw denied();
        return user;
    }

    private void requireAuthenticated(AuthenticatedUser principal) {
        if (principal == null) throw denied();
    }

    private ApiException denied() {
        return new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền xem dữ liệu này.");
    }
}
