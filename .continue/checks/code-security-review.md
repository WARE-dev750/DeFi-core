---
name: Code Security Review
description: When a PR is opened, this agent performs a comprehensive security
  audit for OWASP Top 10 vulnerabilities and security best practices.
---

## Purpose

Perform a comprehensive security audit of pull request changes, focusing on OWASP Top 10 vulnerabilities, authentication/authorization issues, and security best practices.

## Execution Steps

### 1. Pull Request Analysis

View the changes on the pull request and focus on security-relevant files (authentication, database queries, API endpoints, input handlers, configuration). Read the full content of each changed file to understand context.

### 2. Security Vulnerability Scanning

Scan for the following vulnerability categories:

#### OWASP Top 10 Coverage

**A01: Broken Access Control**

- Missing authentication checks on sensitive endpoints
- Insecure Direct Object References (IDOR)
- Privilege escalation vulnerabilities
- Missing authorization checks (e.g., user can access other users' data)
- Path traversal vulnerabilities

**A02: Cryptographic Failures**

- Hardcoded secrets (API keys, passwords, tokens)
- Weak or outdated encryption algorithms
- Insecure random number generation
- Sensitive data in logs or error messages
- Missing encryption for sensitive data

**A03: Injection**

- SQL injection (string concatenation in queries)
- Command injection (unsanitized input in system commands)
- NoSQL injection
- LDAP injection
- XPath injection
- Template injection

**A04: Insecure Design**

- Missing rate limiting on authentication/API endpoints
- Insecure default configurations
- Missing security headers
- Insufficient anti-automation measures

**A05: Security Misconfiguration**

- Debug mode enabled in production
- Verbose error messages exposing system details
- Default credentials
- Unnecessary features enabled
- Missing security patches

**A06: Vulnerable and Outdated Components**

- Outdated dependencies with known CVEs
- Unmaintained libraries
- Missing security updates

**A07: Identification and Authentication Failures**

- Weak password policies
- Missing multi-factor authentication
- Insecure session management
- Predictable session IDs
- Missing account lockout mechanisms
- Improper credential storage

**A08: Software and Data Integrity Failures**

- Missing integrity checks
- Insecure deserialization
- Unsigned or unverified updates
- Missing CI/CD security

**A09: Security Logging and Monitoring Failures**

- Insufficient logging of security events
- Sensitive data in logs
- Missing audit trails
- No alerting on suspicious activity

**A10: Server-Side Request Forgery (SSRF)**

- Unvalidated URLs
- Missing URL allowlisting
- Internal network exposure

#### Additional Security Patterns

**Cross-Site Scripting (XSS)**

- Unescaped output in templates
- innerHTML usage with user input
- Missing Content-Security-Policy headers
- Unsafe sanitization

**Cross-Site Request Forgery (CSRF)**

- Missing CSRF tokens on state-changing operations
- Missing SameSite cookie attributes
- Incorrect token validation

**Security Headers**

- Missing X-Frame-Options
- Missing X-Content-Type-Options
- Missing Strict-Transport-Security
- Weak Content-Security-Policy

**Input Validation**

- Missing input validation
- Insufficient sanitization
- Type coercion vulnerabilities
- Regex denial of service (ReDoS)

**Cookie Security**

- Missing HttpOnly flag
- Missing Secure flag
- Missing SameSite attribute
- Overly permissive cookie scope

### 3. Severity Classification

Classify each finding by severity:

**🔴 Critical**

- SQL injection vulnerabilities
- XSS in sensitive contexts
- Hardcoded secrets/credentials
- Authentication bypass
- Remote code execution

**🟠 High**

- Missing input validation on sensitive operations
- Weak cryptography
- Authorization issues
- Insecure defaults
- Command injection

**🟡 Medium**

- Missing CSRF protection
- Insecure cookie configuration
- Excessive logging of sensitive data
- Missing rate limiting
- Outdated dependencies

**🟢 Low**

- Best practice violations
- Code quality issues with security implications
- Missing security headers (non-critical)
- Weak password policies

### 4. Automatic Fixes (Critical/High Only)

For **Critical** and **High** severity issues, implement fixes directly:

**SQL Injection Fixes:**

```typescript
// Before (vulnerable)
db.query(`SELECT * FROM users WHERE id = ${userId}`);

// After (fixed)
db.query("SELECT * FROM users WHERE id = ?", [userId]);
// or
db.query("SELECT * FROM users WHERE id = $1", [userId]);
```

**XSS Fixes:**

```typescript
// Before (vulnerable)
element.innerHTML = userInput;

// After (fixed)
element.textContent = userInput;
// or use a proper sanitization library
```

**Hardcoded Secrets Fixes:**

```typescript
// Before (vulnerable)
const API_KEY = "sk-1234567890abcdef";

// After (fixed)
const API_KEY = process.env.API_KEY;
// Add to .env.example: API_KEY=your_key_here
```

**Missing Authentication Fixes:**

```typescript
// Before (vulnerable)
app.get("/admin/users", (req, res) => {
  // no auth check
});

// After (fixed)
app.get("/admin/users", requireAuth, requireAdmin, (req, res) => {
  // protected
});
```

**Input Validation Fixes:**

```typescript
// Before (vulnerable)
const userId = req.params.id;

// After (fixed)
const userId = parseInt(req.params.id, 10);
if (isNaN(userId) || userId <= 0) {
  return res.status(400).json({ error: "Invalid user ID" });
}
```

### 5. PR Comment

Post or update a PR comment with findings. Use HTML comment `<!-- security-audit-bot -->` to identify the comment for updates.

**Comment Template:**

````markdown
<!-- security-audit-bot -->

## 🛡️ Security Review

### Summary

- **Critical:** X issues (Y fixed automatically)
- **High:** X issues (Y fixed automatically)
- **Medium:** X issues (manual review needed)
- **Low:** X issues (recommendations)

### Automatic Fixes Applied

✅ **Fixed SQL injection vulnerabilities**

- File: `src/routes/users.ts:45`
- Changed to parameterized queries

✅ **Removed hardcoded API key**

- File: `src/config/api.ts:12`
- Moved to environment variables

### Issues Requiring Manual Review

#### 🟡 Medium: Missing CSRF Protection

**File:** `src/routes/admin.ts:78`
**Category:** OWASP A01: Broken Access Control

State-changing POST endpoint missing CSRF token validation.

**Recommendation:**

```typescript
app.post("/admin/delete-user", csrfProtection, (req, res) => {
  // Add CSRF middleware
});
```

#### 🟢 Low: Missing Security Headers

**File:** `src/server.ts:15`
**Category:** OWASP A05: Security Misconfiguration

Consider adding security headers using helmet.js:

```typescript
import helmet from "helmet";
app.use(helmet());
```

### Security Checklist

- [x] SQL injection vulnerabilities
- [x] Hardcoded secrets
- [ ] CSRF protection on state-changing operations
- [ ] Security headers configured
- [ ] Input validation on all user inputs
- [ ] Authentication required on sensitive endpoints

---
_Automated by [Code Security Review Agent](https://continue.dev)_
````

## Detection Patterns

### SQL Injection Detection

Look for:

- String concatenation in database queries: `` `SELECT * FROM ${table}` ``
- Template literals with variables: `` `WHERE id = ${id}` ``
- String concatenation with `+`: `"SELECT * FROM users WHERE id = " + userId`

Safe patterns:

- Parameterized queries: `db.query('SELECT * FROM users WHERE id = ?', [id])`
- ORM methods: `User.findById(id)`

### XSS Detection

Look for:

- `innerHTML` with user input
- `dangerouslySetInnerHTML` in React
- Unescaped variables in templates
- `eval()` with user input
- `document.write()` with user input

### Hardcoded Secrets Detection

Look for patterns like:

- `password = "..."`
- `api_key = "sk-..."`
- `secret = "..."`
- `token = "ghp_..."`
- `apiKey: "..."`
- Private keys in code
- AWS access keys

Exceptions (not secrets):

- Example/placeholder values in comments
- Test fixtures with `test_`, `example_`, `fake_` prefixes
- Documentation

### Authentication Bypass Detection

Look for:

- Routes without authentication middleware
- `if (isAdmin)` checks without proper validation
- Direct database queries without user context
- Missing ownership checks on resource access

## Best Practices

1. **Fix critical issues immediately** - don't wait for manual review
2. **Be specific in recommendations** - provide exact code snippets
3. **Update, don't duplicate** - use the HTML comment to update existing comments
4. **Prioritize by severity** - fix critical/high first
5. **Consider false positives** - validate findings before reporting
6. **Check for regressions** - ensure fixes don't break functionality
7. **Test fixes when possible** - run tests after implementing fixes

```

```