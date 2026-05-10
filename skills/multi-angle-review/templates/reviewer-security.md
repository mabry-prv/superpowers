# Reviewer Template: Security

Use this template when dispatching a security reviewer subagent.

**Purpose:** Catch exploitable security defects before they ship — injection, broken authentication, credential exposure, access control gaps, webhook integrity failures, and cryptography misuse — in a single focused pass.

```
Task tool (general-purpose):
  description: "Security review"
  prompt: |
    You are reviewing code for security defects in a FastAPI + SQLAlchemy
    backend. Your concerns are: secret handling, input validation, injection,
    authentication & credential storage, webhook integrity. Do NOT comment on
    multi-tenant isolation (separate reviewer), migration safety (separate
    reviewer), or general code quality. Stay focused on security.

    ## What Was Implemented

    {DESCRIPTION}

    ## Requirements / Plan

    {PLAN_OR_REQUIREMENTS}

    ## Files to Review

    {FILES_TO_REVIEW}

    ## OWASP-Aligned Security Checklist (FastAPI-Flavored)

    Understand each category before reviewing — every finding should be
    expressed in terms of a specific deviation from secure practice.

    **Injection**
    SQL injection via string concatenation or unsafe SQLAlchemy `text()` with
    user-controlled input. Look for f-strings or `.format()` calls that
    compose SQL fragments. Also look for OS command injection via
    `subprocess.run(..., shell=True)` or `os.system()` where any part of the
    command is user-supplied. Parameterized queries (`select(Model).where(...)`)
    and `subprocess.run([...])` with a list (no `shell=True`) are safe.

    **Broken authentication & credential storage**
    Passwords stored as plaintext or using a weak/fast hash (MD5, SHA-1,
    SHA-256 without a work factor). Missing rate limit on login or signup
    endpoints. Weak session token generation (using `random` instead of
    `secrets.token_urlsafe`). Session fixation (session ID not rotated after
    successful login).

    **Sensitive data exposure**
    Passwords, tokens, or PII logged in plaintext (e.g., `logger.info(f"...
    {password}")`). Secrets hardcoded in source code (API keys, JWT secrets,
    webhook signing secrets committed as string literals). Secrets or stack
    traces inadvertently serialized in error responses or HTTP 500 bodies.
    ORM responses that return whole user objects including password hashes.

    **Broken access control**
    Endpoints that should require authentication are missing the auth
    dependency (`Depends(get_current_user)` or equivalent). Admin-only
    endpoints with no role check. CORS policy too permissive — especially
    `allow_origins=["*"]` combined with `allow_credentials=True`, which is a
    browser-enforced error in theory but signals a misunderstanding of CORS
    security intent.

    **Security misconfiguration**
    `debug=True` in any path that could reach production. Auth cookies missing
    `secure=True`, `httponly=True`, or `samesite="lax"` (or `"strict"`) flags.
    `TrustedHostMiddleware` not configured, leaving the app open to Host header
    injection. CORS `allow_origins=["*"]` with credentials enabled.

    **Webhook integrity**
    Inbound webhooks (Stripe, GitHub, etc.) processed without verifying the
    provider's HMAC signature. Stateful webhook handlers (billing, fulfillment,
    provisioning) that process the same event multiple times because there is
    no deduplication by event ID — replay attacks or provider retries can
    cause double-charges or double-provisioning.

    **Cryptography misuse**
    Custom hashing schemes instead of an established password hashing library
    (passlib with bcrypt or argon2). Predictable token generation using
    `random.random()` or `random.randint()` instead of
    `secrets.token_urlsafe()` or `secrets.token_hex()`. Rolling custom HMAC
    verification instead of using the provider's official SDK method.

    ## Severity Rules

    ### Critical (any of the following — flag every instance)

    - **SQL injection via string concat or unsafe `text()`.** Any f-string,
      `.format()`, or `%`-interpolated SQL query where user input is embedded
      directly. `text(f"SELECT ... WHERE email = '{email}'")` is Critical.

    - **OS command injection via `shell=True` with user input.** Any
      `subprocess` or `os.system` call using `shell=True` where the command
      string contains user-controlled data.

    - **Plaintext password storage.** Storing a password field directly without
      hashing, or hashing with a fast, unsalted algorithm (MD5, SHA-1,
      SHA-256 without bcrypt/argon2).

    - **Webhook handler with no signature verification.** An inbound webhook
      endpoint that parses the request body and acts on it without first
      verifying the provider's HMAC signature (e.g., `stripe.Webhook.construct_event`
      with the signing secret).

    - **Auth bypass — endpoint missing `Depends(get_current_user)` for a
      protected route.** Any endpoint that performs authenticated actions (reads
      user data, modifies state, triggers billing) but has no auth dependency
      in its signature.

    - **Hardcoded secret committed to code.** API keys, passwords, JWT signing
      secrets, or webhook signing secrets written as string literals in source
      files (not read from env or config).

    ### Important (any of the following)

    - **Credentials or PII in log statements.** `logger.info(...)` or any log
      call that interpolates a password, token, secret, or unredacted PII. Logs
      are written to files and log aggregators; credential exposure in logs is
      a persistent breach.

    - **Stateful webhook handler without idempotency.** A billing, fulfillment,
      or provisioning webhook handler that takes state-changing action (marks
      org paid, sends email, provisions resource) without first deduplicating
      by the provider's event ID. Provider retries or replay attacks cause
      duplicate effects.

    - **Cookie auth without `samesite` and `secure` flags.** Auth cookies set
      without `samesite="lax"` (or `"strict"`) and `secure=True` are
      vulnerable to CSRF and transmission over plain HTTP.

    - **Custom password hashing where bcrypt or argon2 should be used.**
      Using `hashlib.sha256` or `hashlib.md5` (even with a salt) instead of
      a password-hashing library with a configurable work factor.

    - **CORS `allow_origins=["*"]` combined with `allow_credentials=True`.**
      This combination is rejected by browsers and signals a misunderstanding
      of the security boundary; any credential-carrying CORS request will fail
      for legitimate clients.

    ### Suggestion (any of the following)

    - Missing rate limiting on login or signup endpoints. Without rate
      limiting, credential stuffing and brute-force attacks proceed
      unchecked.

    - No security-headers middleware (HSTS, CSP, X-Frame-Options). These
      mitigate a class of browser-based attacks at negligible cost.

    - Stack traces or internal error details returned to clients in HTTP 500
      responses. Leaks implementation details that aid attackers.

    ## Output Format

    ### Critical (Must Fix)
    [Exploitable security defects — ship-blocking]

    ### Important (Should Fix)
    [Significant weaknesses that increase attack surface or breach impact]

    ### Suggestion
    [Defense-in-depth improvements]

    For each finding:
    - `file:line` — exact location
    - What's wrong — describe the specific code
    - Why it matters — concrete attack or breach scenario
    - How to fix — the correct approach with example

    End with exactly one of:

    **Verdict: BLOCKED — N Critical finding(s)**
    **Verdict: APPROVED WITH SUGGESTIONS** (Important and/or Suggestion only)
    **Verdict: APPROVED** (no findings)

    ## Anti-Patterns — What NOT to Do

    **DO:**
    - Read every line of every file listed before forming a verdict
    - Give exact `file:line` for every finding
    - Flag Critical for every SQL injection, plaintext password, unsigned
      webhook, hardcoded secret, and auth bypass — even when the bug is
      in an obvious comment
    - Describe the concrete attack scenario, not just "this is insecure"
    - Flag credentials-in-logs as Important even if the password is also
      stored in plaintext (both findings are real)
    - Flag non-idempotent webhooks as Important even when signature
      verification is also absent (both are independent defects)

    **DON'T:**
    - Comment on multi-tenant isolation — separate reviewer
    - Comment on migration safety — separate reviewer
    - Comment on code style, naming conventions, or performance
    - Approve a PR you haven't read every diff in
    - Be vague — every finding needs a `file:line`
    - Skip a finding because "the developer probably knows"
    - Treat "uses an ORM" as equivalent to "safe from SQL injection" —
      raw `text()` with string interpolation is still injectable
```

**Placeholders:**
- `{DESCRIPTION}` — brief summary of what was built
- `{PLAN_OR_REQUIREMENTS}` — what it should do (plan file path, task text, or requirements)
- `{FILES_TO_REVIEW}` — list of files (paths or git diff range)

**Reviewer returns:** Critical / Important / Suggestion findings, each with file:line + fix, and a Verdict.

## Example Output

```
### Critical (Must Fix)

1. **SQL injection via string concatenation**
   - `app/auth.py:14` — `f"SELECT * FROM users WHERE email = '{email}' AND password = '{password}'"` embeds user input directly into SQL
   - Why it matters: an attacker passes `' OR '1'='1` as the email to bypass authentication or dump the entire users table
   - Fix: use SQLAlchemy ORM — `select(User).where(User.email == email)` — and compare the password hash separately with bcrypt

2. **Plaintext password storage**
   - `app/auth.py:7` — `user = {"email": email, "password": password}` stores the raw password in the database
   - Why it matters: any database breach immediately exposes all user passwords; no cracking required
   - Fix: hash with bcrypt before storage — `password_hash = bcrypt.hash(password)` — store only the hash

3. **Webhook handler with no signature verification**
   - `app/billing.py:8` — `payload = await request.json()` processes the body with no HMAC signature check
   - Why it matters: anyone can POST a fake `invoice.paid` event and mark any org as paid without paying
   - Fix: verify with `stripe.Webhook.construct_event(await request.body(), request.headers["stripe-signature"], settings.STRIPE_WEBHOOK_SECRET)`

### Important (Should Fix)

4. **Credentials in log statement**
   - `app/auth.py:9` — `logger.info(f"Creating user {email} with password {password}")` writes the plaintext password to logs
   - Why it matters: logs are shipped to aggregators and retained; password exposure in logs is a persistent breach for every user who ever signed up
   - Fix: log only `email` — `logger.info("User created", extra={"user_email": email})`

5. **Non-idempotent billing webhook handler**
   - `app/billing.py:13` — `await mark_org_paid(org_id)` is called on every delivery with no deduplication by event ID
   - Why it matters: Stripe retries on network error; a transient failure causes the org to be marked paid multiple times (or a billing counter to be incremented N times)
   - Fix: insert the event ID into a `StripeEventSeen` table and skip processing if already seen

**Verdict: BLOCKED — 3 Critical finding(s)**
```
