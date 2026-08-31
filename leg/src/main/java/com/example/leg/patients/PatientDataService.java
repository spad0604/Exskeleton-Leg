package com.example.leg.patients;

import java.sql.ResultSet;
import java.time.Instant;
import java.time.LocalDate;
import java.sql.Timestamp;
import java.sql.Date;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Database-backed patient read models and notification registration. */
@Service
public class PatientDataService {
    private static final UUID SIT_TO_STAND = UUID.fromString("20000000-0000-0000-0000-000000000001");
    private static final UUID KNEE_RAISE = UUID.fromString("20000000-0000-0000-0000-000000000002");
    private static final UUID SEATED_KNEE_EXTENSION = UUID.fromString("20000000-0000-0000-0000-000000000003");
    private static final UUID HEEL_RAISES = UUID.fromString("20000000-0000-0000-0000-000000000004");
    private static final UUID STRAIGHT_LEG_RAISE = UUID.fromString("20000000-0000-0000-0000-000000000005");
    private static final UUID HEEL_SLIDES = UUID.fromString("20000000-0000-0000-0000-000000000006");
    private static final UUID QUAD_SET = UUID.fromString("20000000-0000-0000-0000-000000000007");
    private static final UUID HIP_EXTENSION = UUID.fromString("20000000-0000-0000-0000-000000000008");
    private final JdbcTemplate jdbc;

    public PatientDataService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @Transactional
    public void ensurePatient(UUID patientId) {
        if (jdbc.queryForObject("select count(*) from patient_devices where patient_id = ?", Integer.class, patientId) == 0) {
            jdbc.update("insert into patient_devices (id, patient_id, serial_number, model, firmware_version, online, last_seen_at, battery_percent, readiness_state, sensors_state, motors_state, controller_state, estop_state, calibration_status, calibration_expires_at) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    UUID.randomUUID(), patientId, "EXO-" + patientId.toString().substring(0, 8).toUpperCase(), "exo-leg-v1", "1.2.0", true, Timestamp.from(Instant.now()), 78, "ready", "ok", "ok", "ok", "ok", "valid", Date.valueOf(LocalDate.now().plusDays(31)));
        }
        addPlanIfMissing(patientId, SIT_TO_STAND, 2, 8, 600);
        addPlanIfMissing(patientId, KNEE_RAISE, 2, 8, 480);
        addPlanIfMissing(patientId, SEATED_KNEE_EXTENSION, 2, 10, 420);
        addPlanIfMissing(patientId, HEEL_RAISES, 2, 8, 360);
        addPlanIfMissing(patientId, STRAIGHT_LEG_RAISE, 2, 8, 420);
        addPlanIfMissing(patientId, HEEL_SLIDES, 2, 10, 420);
        addPlanIfMissing(patientId, QUAD_SET, 2, 10, 300);
        addPlanIfMissing(patientId, HIP_EXTENSION, 2, 8, 360);
    }

    private void addPlanIfMissing(UUID patientId, UUID exerciseId, int sets, int reps, int seconds) {
        var planDate = Date.valueOf(LocalDate.now());
        if (jdbc.queryForObject("select count(*) from patient_plan_items where patient_id = ? and exercise_id = ? and plan_date = ?", Integer.class, patientId, exerciseId, planDate) > 0) {
            return;
        }
        jdbc.update("insert into patient_plan_items (id, patient_id, exercise_id, plan_date, sets, repetitions_per_set, rest_seconds, assistance_level, estimated_duration_seconds) values (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), patientId, exerciseId, planDate, sets, reps, 60, "low", seconds);
    }

    public Map<String, Object> home(UUID patientId, String displayName, String timezone) {
        ensurePatient(patientId);
        var device = jdbc.queryForMap("select * from patient_devices where patient_id = ? order by serial_number limit 1", patientId);
        var plans = jdbc.queryForList("select p.*, e.name exercise_name from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? and p.plan_date=? order by p.id", patientId, Date.valueOf(LocalDate.now()));
        var next = plans.stream().filter(p -> !"completed".equals(p.get("status"))).findFirst().map(this::homePlanOutput).orElse(null);
        var metrics = jdbc.queryForMap("select count(*) planned_count, coalesce(sum(case when status='completed' then 1 else 0 end),0) completed_count from patient_plan_items where patient_id=? and plan_date=?", patientId, Date.valueOf(LocalDate.now()));
        var sessions = jdbc.queryForMap("select coalesce(sum(active_seconds),0) active_seconds, avg(correctness_ratio) correctness_ratio from training_sessions where patient_id=? and started_at >= ?", patientId, Timestamp.from(LocalDate.now().atStartOfDay().toInstant(java.time.ZoneOffset.UTC)));
        var alerts = jdbc.queryForList("select * from patient_alerts where patient_id=? and resolved_at is null order by occurred_at desc", patientId).stream().map(this::alertOutput).toList();
        var output = new LinkedHashMap<String, Object>();
        output.put("patient", Map.of("id", patientId, "display_name", displayName, "timezone", timezone));
        output.put("device", deviceOutput(device));
        output.put("next_plan_item", next);
        output.put("today_metrics", Map.of("planned_count", metrics.get("planned_count"), "completed_count", metrics.get("completed_count"), "active_seconds", sessions.get("active_seconds"), "correctness_ratio", sessions.get("correctness_ratio") == null ? 0 : sessions.get("correctness_ratio")));
        output.put("open_alerts", alerts);
        output.put("recent_session", null);
        return output;
    }

    public List<Map<String, Object>> plans(UUID patientId, String scope) { ensurePatient(patientId); var sql = "all".equals(scope) ? "select p.*, e.id exercise_id, e.code exercise_code, e.name exercise_name, e.category exercise_category, e.name_key, e.description_key, e.instructions_key, e.safety_key, e.difficulty, e.requires_support from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? order by p.plan_date desc, p.id" : "select p.*, e.id exercise_id, e.code exercise_code, e.name exercise_name, e.category exercise_category, e.name_key, e.description_key, e.instructions_key, e.safety_key, e.difficulty, e.requires_support from patient_plan_items p join exercises e on e.id=p.exercise_id where p.patient_id=? and p.plan_date=? order by p.id"; var args = "all".equals(scope) ? new Object[] {patientId} : new Object[] {patientId, Date.valueOf(LocalDate.now())}; return jdbc.queryForList(sql, args).stream().map(this::planOutput).toList(); }
    public Map<String, Object> progress(UUID patientId, String period) { ensurePatient(patientId); var days = "month".equals(period) ? 30 : 7; var start = LocalDate.now().minusDays(days - 1L); var row=jdbc.queryForMap("select count(*) planned_count, coalesce(sum(case when status='completed' then 1 else 0 end),0) completed_count from patient_plan_items where patient_id=? and plan_date >= ?", patientId, Date.valueOf(start)); var startTimestamp = Timestamp.from(start.atStartOfDay().toInstant(java.time.ZoneOffset.UTC)); var s=jdbc.queryForMap("select coalesce(sum(active_seconds),0) active_seconds, avg(correctness_ratio) correctness_ratio from training_sessions where patient_id=? and started_at >= ?", patientId, startTimestamp); var history=jdbc.queryForList("select id, started_at, completed_at, active_seconds, correctness_ratio, status from training_sessions where patient_id=? and started_at >= ? order by started_at desc limit 20", patientId, startTimestamp); return Map.of("period", period, "planned_count", row.get("planned_count"), "completed_count", row.get("completed_count"), "active_seconds", s.get("active_seconds"), "correctness_ratio", s.get("correctness_ratio") == null ? 0 : s.get("correctness_ratio"), "warning_count", 0, "critical_count", 0, "streak_days", 0, "recent_sessions", history); }
    public List<Map<String, Object>> devices(UUID patientId) { ensurePatient(patientId); return jdbc.queryForList("select * from patient_devices where patient_id=?", patientId).stream().map(this::deviceOutput).toList(); }
    public List<Map<String, Object>> exercises() { return jdbc.queryForList("select * from exercises where active=true order by category, code").stream().map(this::exerciseOutput).toList(); }
    public Map<String, Object> exercise(UUID exerciseId) { return exerciseOutput(jdbc.queryForMap("select * from exercises where id=? and active=true", exerciseId)); }
    public List<Map<String, Object>> notifications(UUID patientId) { return jdbc.queryForList("select id, severity, title, occurred_at, resolved_at from patient_alerts where patient_id=? order by occurred_at desc", patientId).stream().map(this::alertOutput).toList(); }
    public void registerToken(UUID userId, String token, String platform) {
        var updated = jdbc.update("update fcm_tokens set platform=?, last_seen_at=? where user_id=? and token=?", platform, Timestamp.from(Instant.now()), userId, token);
        if (updated == 0) jdbc.update("insert into fcm_tokens (id,user_id,token,platform,last_seen_at) values (?,?,?,?,?)", UUID.randomUUID(), userId, token, platform, Timestamp.from(Instant.now()));
    }

    private Map<String,Object> homePlanOutput(Map<String,Object> p) {
        return Map.of("id", p.get("id"), "exercise_id", p.get("exercise_id"), "exercise_name", p.get("exercise_name"),
                "target", Map.of("kind", "repetitions", "sets", p.get("sets"), "repetitions_per_set", p.get("repetitions_per_set")),
                "assistance_level", p.get("assistance_level"), "estimated_duration_seconds", p.get("estimated_duration_seconds"));
    }

    private Map<String,Object> planOutput(Map<String,Object> p) { return Map.of("id", p.get("id"), "plan_id", p.getOrDefault("plan_id", p.get("id")), "exercise", Map.of("id", p.get("exercise_id"), "code", p.getOrDefault("exercise_code", ""), "name", p.get("exercise_name"), "category", p.getOrDefault("exercise_category", ""), "name_key", p.getOrDefault("name_key", ""), "description_key", p.getOrDefault("description_key", ""), "instructions_key", p.getOrDefault("instructions_key", ""), "safety_key", p.getOrDefault("safety_key", ""), "difficulty", p.getOrDefault("difficulty", "beginner"), "requires_support", p.getOrDefault("requires_support", false)), "target", Map.of("kind", "repetitions", "sets", p.get("sets"), "repetitions_per_set", p.get("repetitions_per_set"), "rest_seconds", p.get("rest_seconds")), "safe_config", Map.of("assistance_level", p.get("assistance_level")), "status", p.get("status"), "estimated_duration_seconds", p.get("estimated_duration_seconds")); }
    private Map<String,Object> exerciseOutput(Map<String,Object> e) { return Map.of("id", e.get("id"), "code", e.get("code"), "name", e.get("name"), "category", e.get("category"), "name_key", e.getOrDefault("name_key", ""), "description_key", e.getOrDefault("description_key", ""), "instructions_key", e.getOrDefault("instructions_key", ""), "safety_key", e.getOrDefault("safety_key", ""), "difficulty", e.getOrDefault("difficulty", "beginner"), "requires_support", e.getOrDefault("requires_support", false)); }
    private Map<String,Object> deviceOutput(Map<String,Object> d) { var readiness=new LinkedHashMap<String,Object>(); readiness.put("state",d.get("readiness_state")); readiness.put("blocking_reasons", d.get("blocking_reasons")==null||d.get("blocking_reasons").toString().isBlank()?List.of():List.of(d.get("blocking_reasons"))); var output=new LinkedHashMap<String,Object>(); output.put("id",d.get("id")); output.put("serial_number",d.get("serial_number")); output.put("model",d.get("model")); output.put("firmware_version",d.get("firmware_version")); output.put("protocol_version",d.get("protocol_version")); output.put("online",d.get("online")); output.put("last_seen_at",d.get("last_seen_at")); output.put("battery_percent",d.get("battery_percent")); output.put("readiness",readiness); output.put("health",Map.of("sensors",d.get("sensors_state"),"motors",d.get("motors_state"),"controller",d.get("controller_state"),"estop",d.get("estop_state"))); output.put("calibration",Map.of("status",d.get("calibration_status"),"expires_at",d.get("calibration_expires_at"))); return output; }
    private Map<String,Object> alertOutput(Map<String,Object> a) { return Map.of("id",a.get("id"),"severity",a.get("severity"),"title",a.get("title"),"occurred_at",a.get("occurred_at")); }
}
