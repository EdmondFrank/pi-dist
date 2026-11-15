# kuri-agent Command Reference

## Session Management

### tabs [--port N]
List Chrome tabs available for connection.

```bash
kuri-agent tabs
# → ws://127.0.0.1:9222/devtools/page/ABC123 https://example.com
```

### use <ws_url>
Attach to a specific tab. Saves session to `~/.kuri/session.json`.

```bash
kuri-agent use ws://127.0.0.1:9222/devtools/page/ABC123
```

### open [url] [--port N]
Open a new tab, optionally navigating to URL.

```bash
kuri-agent open https://example.com
```

### status
Show current session state.

```bash
kuri-agent status
```

## Navigation

### go <url>
Navigate to URL.

```bash
kuri-agent go https://example.com
```

### back / forward
Navigate history.

```bash
kuri-agent back
kuri-agent forward
```

### reload
Reload current page.

```bash
kuri-agent reload
```

## Reading Pages

### snap [--interactive] [--json] [--text] [--depth N]
Get accessibility tree snapshot with @eN refs.

```bash
# Interactive elements only (~750 tokens) - best for agent loops
kuri-agent snap --interactive

# Full snapshot (~2,124 tokens)
kuri-agent snap

# JSON format
kuri-agent snap --json

# Limit depth
kuri-agent snap --depth 3
```

### text [selector]
Extract page text.

```bash
kuri-agent text
kuri-agent text .article-content
```

### shot [--out file.png]
Take screenshot. Saves to `~/.kuri/screenshots/<timestamp>.png` by default.

```bash
kuri-agent shot
kuri-agent shot --out screenshot.png
```

### eval <js>
Execute JavaScript.

```bash
kuri-agent eval "document.title"
kuri-agent eval "localStorage.getItem('token')"
kuri-agent eval "fetch('/api/data').then(r=>r.json())"
```

## Interacting with Elements

### click <ref>
Click element by ref (CDP mouse events, React-compatible).

```bash
kuri-agent click e0
kuri-agent click e5
```

### type <ref> <text>
Type into element (per-character key events, React-compatible).

```bash
kuri-agent type e2 "Hello World"
```

### fill <ref> <text>
Clear input and fill with text.

```bash
kuri-agent fill e3 "john@example.com"
```

### select <ref> <value>
Select dropdown option.

```bash
kuri-agent select e4 "option2"
```

### hover <ref>
Hover over element.

```bash
kuri-agent hover e1
```

### focus <ref>
Focus element.

```bash
kuri-agent focus e2
```

### scroll
Scroll the page viewport.

```bash
kuri-agent scroll
```

### viewport [width height]
Get or set viewport dimensions.

```bash
kuri-agent viewport
kuri-agent viewport 1920 1080
```

## Security Testing

### cookies
List cookies with security flags.

```bash
kuri-agent cookies
# cookies (3):
# session_id domain=.example.com path=/ [Secure] [HttpOnly] [SameSite=Strict]
# csrf_token domain=.example.com path=/ [Secure] [!HttpOnly]
# tracking domain=.example.com path=/ [!Secure] [!HttpOnly]
```

### headers
Check security response headers.

```bash
kuri-agent headers
# → {"url":"https://...","status":200,"headers":{
#   "content-security-policy":"default-src 'self'",
#   "strict-transport-security":"max-age=31536000",
#   "x-frame-options":"(missing)", ...}}
```

### audit
Full security audit (HTTPS, missing headers, JS-visible cookies).

```bash
kuri-agent audit
# → {"protocol":"https:","url":"https://...","score":6,
#   "issues":["MISSING:x-frame-options","COOKIES_EXPOSED_TO_JS:2"], ...}
```

### storage [local|session|all]
Dump localStorage / sessionStorage.

```bash
kuri-agent storage local
kuri-agent storage session
kuri-agent storage all
```

### jwt
Extract and decode JWTs from cookies and storage.

```bash
kuri-agent jwt
```

### fetch <method> <url> [--data <json>]
Authenticated fetch using page cookies.

```bash
kuri-agent fetch GET https://api.example.com/data
kuri-agent fetch POST https://api.example.com/submit --data '{"key":"value"}'
```

### probe <url-template> <start> <end>
IDOR probe: iterate numeric IDs in URL.

```bash
kuri-agent probe "https://api.example.com/users/{id}" 1 100
```

## Headers

### set-header <name> <value>
Add a custom header to all requests.

```bash
kuri-agent set-header Authorization "Bearer token123"
```

### show-headers
Show stored extra headers.

```bash
kuri-agent show-headers
```

### clear-headers
Remove all extra headers.

```bash
kuri-agent clear-headers
```

## Advanced

### grab <ref>
Click ref, intercept window.open, follow redirect in-tab.

```bash
kuri-agent grab e0
```

### wait-for-tab [--port N]
Poll for a new tab, auto-switch session.

```bash
kuri-agent wait-for-tab
```

### stealth
Apply anti-detection patches.

```bash
kuri-agent stealth
```

## Common Patterns

### Login Flow

```bash
kuri-agent go https://example.com/login
kuri-agent snap --interactive
kuri-agent fill e2 username
kuri-agent fill e3 password
kuri-agent click e4  # submit button
kuri-agent snap --interactive  # verify login
```

### Form Submission

```bash
kuri-agent go https://example.com/form
kuri-agent snap --interactive
kuri-agent fill e1 "John Doe"
kuri-agent fill e2 "john@example.com"
kuri-agent fill e3 "Message content"
kuri-agent click e4  # submit
```

### Data Extraction

```bash
kuri-agent go https://example.com/data
kuri-agent snap --interactive
kuri-agent text .data-table
kuri-agent eval "document.querySelectorAll('.item').length"
```

### Security Audit Workflow

```bash
kuri-agent go https://target.com
kuri-agent audit
kuri-agent cookies
kuri-agent headers
kuri-agent jwt
```
