# Exoskeleton Leg backend

Backend authentication is exposed under `/api/v1` and follows the contracts in
`../codex/04-backend-rust.md` and `../codex/06-api-contract.md`.

## Local setup

1. Create a PostgreSQL database.
2. Copy `.env.example` to `.env` and replace `DATABASE_URL` and `JWT_SECRET`.
   The application reads environment variables directly; load `.env` with your
   process manager or shell.
3. Start the API:

```powershell
$env:DATABASE_URL = 'postgres://postgres:postgres@localhost:5432/exoskeleton_leg'
$env:JWT_SECRET = '<at-least-32-random-bytes>'
cargo run
```

Migrations run automatically during bootstrap. Current identity endpoints are:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/me`

Access tokens expire after 15 minutes by default. Refresh tokens are opaque,
stored as SHA-256 hashes, rotated on every refresh, and grouped into a token
family so reuse of an already rotated token revokes the family.

## Quality checks

```powershell
cargo fmt -- --check
cargo test
cargo clippy --all-targets -- -D warnings
```
