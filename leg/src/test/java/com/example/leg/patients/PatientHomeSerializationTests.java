package com.example.leg.patients;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.leg.shared.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class PatientHomeSerializationTests {
    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void serializesPatientHomeReadModelWithIsoTimestamps() throws Exception {
        var patientId = UUID.fromString("829a87f9-59de-4f39-8872-762203080026");
        var response = ApiResponse.of(
                PatientController.PatientHomeOutput.forPatient(patientId, "Nguyen An", "Asia/Bangkok"));

        var json = objectMapper.writeValueAsString(response);

        assertThat(json).contains("\"last_seen_at\":\"");
        assertThat(json).contains("\"occurred_at\":\"");
        assertThat(json).contains("\"patient\":{\"id\":\"" + patientId + "\"");
        assertThat(json).doesNotContain("[2026");
    }
}
