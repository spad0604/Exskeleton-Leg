package com.example.leg.identity;

import com.example.leg.shared.ApiException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.UUID;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwtService;
    private final ObjectMapper objectMapper;

    public JwtAuthenticationFilter(JwtService jwtService, ObjectMapper objectMapper) {
        this.jwtService = jwtService;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        var header = request.getHeader("Authorization");
        try {
            if (header != null
                    && header.startsWith("Bearer ")
                    && SecurityContextHolder.getContext().getAuthentication() == null) {
                var userId = jwtService.validateAccessToken(header.substring("Bearer ".length()));
                var principal = new AuthenticatedUser(userId, List.of());
                var auth = new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        } catch (ApiException exception) {
            SecurityContextHolder.clearContext();
            writeApiError(response, exception);
            return;
        }
        filterChain.doFilter(request, response);
    }

    private void writeApiError(HttpServletResponse response, ApiException exception) throws IOException {
        var error = new LinkedHashMap<String, Object>();
        error.put("code", exception.code());
        error.put("message", exception.getMessage());
        error.put("details", exception.details());
        error.put("request_id", UUID.randomUUID());

        response.setStatus(exception.status().value());
        response.setContentType("application/json");
        objectMapper.writeValue(response.getWriter(), java.util.Map.of("error", error));
    }
}
