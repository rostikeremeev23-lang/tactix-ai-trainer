# Backend authentication setup

Cloud authentication is enabled by setting `DATABASE_URL` and a high-entropy
`JWT_SECRET_KEY` (at least 32 UTF-8 bytes). Generate a secret outside the source
tree, for example with Python's `secrets.token_urlsafe(48)`. Keep both values
in the deployment secret manager; never commit them or print them in logs.

Apply migrations from this directory:

```powershell
uv run --with-requirements requirements.txt alembic upgrade head
```

Create the first organization and administrator interactively. The password is
prompted twice and is never supplied as a command-line argument:

```powershell
uv run --with-requirements requirements.txt python -m app.create_admin --email admin@example.org --first-name Admin --callsign ADMIN --organization "Training Organization"
```

Authentication routes are under `/v1/auth`: registration requires a one-time
invite code; login returns a 15-minute JWT and a 30-day opaque refresh token;
refresh rotates the refresh token; logout revokes the session; and `/me`
returns the authenticated user, organization and membership role. Store refresh
tokens securely on clients.

Admins can issue trainee or instructor invites. Instructors can issue trainee
invites only. The invite plaintext is returned only in the create response;
only its SHA-256 hash is stored. Registration locks and consumes the invite in
the same transaction that creates the user, membership and auth session.

Access tokens use HS256 and are accepted only while their backing auth session
is active. Role and organization are resolved from the current database
membership. Passwords use Argon2id via argon2-cffi.

Rate limiting for login, registration and invite creation remains a deployment
follow-up. Use HTTPS for all non-local deployments.
