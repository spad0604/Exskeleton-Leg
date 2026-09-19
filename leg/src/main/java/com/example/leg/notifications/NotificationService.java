package com.example.leg.notifications;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Persists patient alerts and fans them out to active caregiver devices. */
@Service
public class NotificationService {
    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    private final JdbcTemplate jdbc;
    private final FirebaseMessaging firebase;

    public NotificationService(JdbcTemplate jdbc, ObjectProvider<FirebaseMessaging> firebase) {
        this.jdbc = jdbc;
        this.firebase = firebase.getIfAvailable();
    }

    @Transactional
    public Map<String, Object> publishFallAlert(UUID patientId, String message, String sourceEventId) {
        if (sourceEventId != null && !sourceEventId.isBlank()) {
            var existing = jdbc.query(
                    "select id, patient_id, type, severity, occurred_at from patient_alerts where patient_id=? and source_event_id=?",
                    (rs, rowNum) -> Map.<String, Object>of(
                            "id", rs.getObject("id"),
                            "patient_id", rs.getObject("patient_id"),
                            "type", rs.getString("type"),
                            "severity", rs.getString("severity"),
                            "occurred_at", rs.getTimestamp("occurred_at")),
                    patientId, sourceEventId);
            if (!existing.isEmpty()) return existing.get(0);
        }
        var id = UUID.randomUUID();
        var now = Timestamp.from(Instant.now());
        var text = message == null || message.isBlank() ? "Hệ thống phát hiện người tập có thể đã bị ngã." : message.trim();
        jdbc.update("insert into patient_alerts (id, patient_id, severity, title, message, type, occurred_at, source_event_id) values (?, ?, 'critical', ?, ?, 'fall', ?, ?)",
                id, patientId, "Cảnh báo té ngã", text, now, sourceEventId);
        notifyCaregivers(patientId, "Cảnh báo té ngã", text, Map.of("type", "fall", "patient_id", patientId.toString(), "alert_id", id.toString()));
        return Map.of("id", id, "patient_id", patientId, "type", "fall", "severity", "critical", "occurred_at", now);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> forViewer(UUID viewerId) {
        return jdbc.queryForList("""
                select a.id, a.patient_id, a.severity, a.title, a.message, a.type, a.occurred_at, a.resolved_at,
                       u.display_name patient_name
                from patient_alerts a join users u on u.id=a.patient_id
                where a.patient_id=? or exists (
                  select 1 from patient_caregiver_links l
                  where l.patient_id=a.patient_id and l.caregiver_id=? and l.status='active'
                )
                order by a.occurred_at desc""", viewerId, viewerId);
    }

    @Transactional(readOnly = true)
    public void notifyUser(UUID userId, String title, String body, Map<String, String> data) {
        if (firebase == null) {
            log.warn("Firebase Admin is not configured; user notification skipped for {}", userId);
            return;
        }
        var tokens = jdbc.queryForList("select token from fcm_tokens where user_id=?", String.class, userId);
        if (tokens.isEmpty()) {
            log.warn("No FCM token registered for user {}; notification '{}' cannot be delivered", userId, title);
        }
        send(tokens, title, body, data);
    }

    private void notifyCaregivers(UUID patientId, String title, String body, Map<String, String> data) {
        if (firebase == null) {
            log.warn("Firebase Admin is not configured; alert persisted without push notification for patient {}", patientId);
            return;
        }
        var tokens = jdbc.queryForList("""
                select distinct t.token from fcm_tokens t
                join patient_caregiver_links l on l.caregiver_id=t.user_id
                where l.patient_id=? and l.status='active'""", String.class, patientId);
        if (tokens.isEmpty()) {
            log.warn("No caregiver FCM token found for patient {}; notification '{}' cannot be delivered", patientId, title);
        }
        send(tokens, title, body, data);
    }

    private void send(List<String> tokens, String title, String body, Map<String, String> data) {
        if (tokens.isEmpty()) return;
        try {
            var notification = Notification.builder().setTitle(title).setBody(body).build();
            var message = MulticastMessage.builder().addAllTokens(tokens).setNotification(notification).putAllData(data).build();
            var result = firebase.sendEachForMulticast(message);
            log.info("Sent alert {} to {} caregiver devices; failures={}", title, result.getSuccessCount() + result.getFailureCount(), result.getFailureCount());
        } catch (Exception exception) {
            log.error("Could not send caregiver push notification", exception);
        }
    }
}
