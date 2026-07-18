package com.example.leg.identity;

import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;

public final class AuthModels {
    private AuthModels() {
    }

    public record RegisterRequest(
            @NotBlank String email,
            @NotBlank String password,
            @NotBlank String displayName,
            String locale,
            @NotBlank String timezone,
            @NotBlank String acceptedTermsVersion,
            String deviceLabel) {
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password, String deviceLabel) {
    }

    public record RefreshRequest(@NotBlank String refreshToken, String deviceLabel) {
    }

    public record LogoutRequest(@NotBlank String refreshToken) {
    }

    public record PublicUser(UUID id, String displayName, List<String> roles) {
        static PublicUser from(UserEntity user) {
            return new PublicUser(user.getId(), user.getDisplayName(), user.getRoles().stream().sorted().toList());
        }
    }

    public record MeOutput(UUID id, String email, String displayName, String locale, String timezone, List<String> roles) {
        static MeOutput from(UserEntity user) {
            return new MeOutput(
                    user.getId(),
                    user.getEmailNormalized(),
                    user.getDisplayName(),
                    user.getLocale(),
                    user.getTimezone(),
                    user.getRoles().stream().sorted().toList());
        }
    }

    public record AuthOutput(
            String accessToken,
            long accessTokenExpiresIn,
            String refreshToken,
            long refreshTokenExpiresIn,
            PublicUser user) {
    }
}
