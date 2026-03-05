# Forgot Password (Email Link) — Design

**Date:** 2026-03-04

## Goal

Allow locked-out users to reset their password via a "Forgot password?" link on the sign-in page. The flow is email-link only: user requests a reset, receives an email with a link; clicking the link opens a page where they set a new password. No OTP or code entry.

## UX Flow

1. **Sign-in page** — Add a "Forgot password?" link (e.g. next to or below "Sign up").
2. **Forgot password page** — Single field "Email" and submit "Send reset link". No indication of whether the email exists; same success message either way: "If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam."
3. **Email** — One prominent link: "Reset your password" → reset URL. Mention expiry (e.g. "This link expires in 1 hour").
4. **Reset password page** — Reached only via the link. URL contains the token (e.g. `/password_reset/:token`). Form: "New password", "Confirm password", submit "Update password". After success: clear token and `password_reset_sent_at`, redirect to sign-in with "Password updated. Sign in with your new password."

## Security

- **Token:** `SecureRandom.urlsafe_base64(32)`; store only the digest (e.g. `BCrypt` or `Digest::SHA256.hexdigest`). Never store the raw token in the DB.
- **Expiry:** Set `password_reset_sent_at` when sending; reject if older than 1 hour (configurable).
- **One-time use:** After successful password update, set `password_reset_token_digest` and `password_reset_sent_at` to `nil`.
- **Constant-time comparison:** Use `ActiveSupport::SecurityUtils.secure_compare(digest, stored_digest)` when verifying the token.
- **No email enumeration:** Same response and messaging whether the email exists or not.

## Data and Mailer

- **Users table:** Add `password_reset_token_digest` (string, nullable) and `password_reset_sent_at` (datetime, nullable).
- **Mailer:** e.g. `UserMailer#password_reset(user, raw_token)`. Build reset URL with `password_reset_url(token: raw_token)`. Rely on `default_url_options` for host.

## Routes and Controllers

- `GET /forgot_password` → Forgot-password form.
- `POST /forgot_password` → Accept email; if user exists, generate token, set digest + `password_reset_sent_at`, send mail; always show same success message (or redirect to login with it).
- `GET /password_reset/:token` → Verify token and expiry; if valid, show "new password" form; if invalid/expired, redirect to login with "That link is invalid or has expired."
- `PATCH /password_reset/:token` → Verify token and expiry again; if valid, update password, clear token and sent_at, redirect to sign-in with success notice.

## Error Handling

- **Forgot password:** Validate only "email present and format valid"; no "user not found" distinction in the UI.
- **Reset page:** Invalid or expired token → redirect to login (or forgot password) with a single generic message.
- **Reset form:** Normal password validation (length, confirmation); re-render form with errors if invalid.
