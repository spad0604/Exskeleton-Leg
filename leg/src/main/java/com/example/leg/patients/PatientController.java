package com.example.leg.patients;

import com.example.leg.identity.AuthService;
import com.example.leg.identity.AuthenticatedUser;
import com.example.leg.shared.ApiException;
import com.example.leg.shared.ApiResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {
    private final AuthService authService;

    public PatientController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping("/{patientId}/home")
    public ApiResponse<PatientHomeOutput> patientHome(
            @PathVariable UUID patientId, @AuthenticationPrincipal AuthenticatedUser principal) {
        if (principal == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "auth.invalid_token", "Phiên đăng nhập không hợp lệ.");
        }
        var me = authService.requireUser(principal.id());
        if (!me.getId().equals(patientId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "authorization.denied", "Bạn không có quyền xem hồ sơ này.");
        }
        return ApiResponse.of(PatientHomeOutput.forPatient(me.getId(), me.getDisplayName(), me.getTimezone()));
    }

    public record PatientHomeOutput(
            PatientSummary patient,
            HomeDevice device,
            NextPlanItem nextPlanItem,
            TodayMetrics todayMetrics,
            List<HomeAlert> openAlerts,
            RecentSession recentSession) {
        static PatientHomeOutput forPatient(UUID id, String displayName, String timezone) {
            return new PatientHomeOutput(
                    new PatientSummary(id, displayName, timezone),
                    new HomeDevice(
                            UUID.randomUUID(),
                            "EXO-2026-000123",
                            true,
                            78,
                            Instant.now(),
                            new Readiness("ready", List.of())),
                    new NextPlanItem(
                            UUID.randomUUID(),
                            UUID.randomUUID(),
                            "Đứng lên và ngồi xuống",
                            new ExerciseTarget("repetitions", 2, 8),
                            "low",
                            600),
                    new TodayMetrics(2, 1, 420, 0.82f),
                    List.of(new HomeAlert(UUID.randomUUID(), "warning", "Hiệu chỉnh sẽ hết hạn trong 3 ngày.", Instant.now())),
                    null);
        }
    }

    public record PatientSummary(UUID id, String displayName, String timezone) {
    }

    public record HomeDevice(
            UUID id, String serialNumber, boolean online, int batteryPercent, Instant lastSeenAt, Readiness readiness) {
    }

    public record Readiness(String state, List<String> blockingReasons) {
    }

    public record NextPlanItem(
            UUID id,
            UUID exerciseId,
            String exerciseName,
            ExerciseTarget target,
            String assistanceLevel,
            int estimatedDurationSeconds) {
    }

    public record ExerciseTarget(String kind, int sets, int repetitionsPerSet) {
    }

    public record TodayMetrics(int plannedCount, int completedCount, int activeSeconds, Float correctnessRatio) {
    }

    public record HomeAlert(UUID id, String severity, String title, Instant occurredAt) {
    }

    public record RecentSession() {
    }
}
