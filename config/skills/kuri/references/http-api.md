# Kuri HTTP API Reference

135 endpoints for browser automation. All return JSON. Optional auth via `KURI_SECRET` env var.

## Session Management

Use `X-Kuri-Session: <name>` header to persist tab context server-side.

## Core Endpoints

| Path | Description |
|------|-------------|
| `GET /health` | Server status, tab count, version |
| `GET /tabs` | List all registered tabs |
| `GET /discover` | Auto-discover Chrome tabs via CDP |
| `GET /tab/current` | Get or set current tab for session |
| `GET /page/info` | Live URL/title/ready-state/viewport/scroll |
| `GET /page/state` | Compact observation (48 tokens): url, title, scroll%, counts |
| `POST /batch` | Execute multiple commands in one HTTP call |

## Browser Control

| Path | Params | Description |
|------|--------|-------------|
| `GET /navigate` | `tab_id`, `url` | Navigate to URL |
| `GET /tab/new` | `url`, `activate`, `wait` | Create new tab |
| `GET /tab/close` | `tab_id` | Close tab |
| `GET /window/new` | `url`, `activate`, `wait` | Create new window |
| `GET /snapshot` | `tab_id`, `filter`, `format` | A11y tree with @eN refs |
| `GET /text` | `tab_id` | Extract page text |
| `GET /screenshot` | `tab_id`, `format`, `quality` | Capture screenshot |
| `GET /action` | `tab_id`, `ref`, `action`, `value` | Click/type/fill/select/scroll/hover |
| `GET /evaluate` | `tab_id`, `expression` | Execute JavaScript |
| `GET /close` | `tab_id` | Close tab + cleanup |

## Actions

| Path | Params | Description |
|------|--------|-------------|
| `GET /clear` | `ref` | Clear input field |
| `GET /selectall` | `ref` | Select all text |
| `GET /setvalue` | `ref`, `value` | Set input value directly |
| `GET /dispatch` | `ref`, `type` | Dispatch DOM event |
| `GET /boundingbox` | `ref` | Get element rect |
| `GET /getattribute` | `ref`, `name` | Get attribute |
| `GET /inputvalue` | `ref` | Get input value |
| `GET /element/state` | `ref`, `check` | exists/visible/enabled/checked |
| `GET /find-element` | `text`/`role`/`label` | Semantic locator |
| `GET /highlight` | `ref` or `selector` | Highlight element |

## Mouse & Touch

| Path | Params | Description |
|------|--------|-------------|
| `GET /mouse/move` | `x`, `y` | Move mouse |
| `GET /mouse/down` | `x`, `y`, `button` | Mouse down |
| `GET /mouse/up` | `x`, `y`, `button` | Mouse up |
| `GET /mouse/wheel` | `x`, `y`, `deltaX`, `deltaY` | Scroll |
| `GET /tap` | `x`, `y` | Touch tap |
| `GET /swipe` | `startX`, `startY`, `endX`, `endY` | Swipe gesture |
| `GET /drag` | `src_ref`, `tgt_ref` | Drag element |

## Keyboard

| Path | Params | Description |
|------|--------|-------------|
| `GET /keyboard/type` | `tab_id`, `text` | Type text |
| `GET /keyboard/inserttext` | `tab_id`, `text` | Insert text directly |
| `GET /keydown` | `tab_id`, `key` | Key down |
| `GET /keyup` | `tab_id`, `key` | Key up |

## Content Extraction

| Path | Description |
|------|-------------|
| `GET /markdown` | Convert to Markdown |
| `GET /links` | Extract all links |
| `GET /dom/query` | CSS selector query |
| `GET /dom/html` | Get element HTML |
| `GET /dom/attributes` | Get attributes |
| `GET /pdf` | Print to PDF |
| `GET /find` | In-page text search |

## Waiting

| Path | Params | Description |
|------|--------|-------------|
| `GET /wait` | `selector`, `text`, `url`, `state`, `timeout` | Wait for condition |
| `GET /wait/function` | `expression`, `timeout` | Wait for JS truthy |
| `GET /wait/download` | `timeout` | Wait for download |

## Dialog Handling

| Path | Description |
|------|-------------|
| `GET /dialog/auto` | Auto-handle dialogs |
| `GET /dialog/accept` | Accept dialog |
| `GET /dialog/dismiss` | Dismiss dialog |

## Network & HAR

| Path | Description |
|------|-------------|
| `GET /har/start` | Start recording |
| `GET /har/stop` | Stop + return HAR 1.2 |
| `GET /har/status` | Recording state |
| `GET /cookies` | Get cookies |
| `GET /cookies/set` | Set cookies |
| `GET /cookies/delete` | Delete cookies |
| `GET /cookies/clear` | Clear all |
| `GET /headers` | Set custom headers |
| `GET /intercept/start` | Start interception |
| `GET /intercept/stop` | Stop interception |
| `GET /intercept/requests` | List intercepted |
| `GET /network` | Network stats |

## Navigation & State

| Path | Description |
|------|-------------|
| `GET /back` | Browser back |
| `GET /forward` | Browser forward |
| `GET /reload` | Reload |
| `GET /stop` | Stop loading |
| `GET /pushstate` | SPA navigation |
| `GET /storage/local` | Get/set localStorage |
| `GET /storage/session` | Get/set sessionStorage |
| `GET /session/save` | Save session |
| `GET /session/load` | Restore session |

## Auth Profiles

| Path | Description |
|------|-------------|
| `GET /auth/profile/save` | Save cookies + storage |
| `GET /auth/profile/load` | Restore profile |
| `GET /auth/profile/list` | List profiles |
| `GET /auth/extract` | Extract auth tokens |

## Emulation

| Path | Params | Description |
|------|--------|-------------|
| `GET /emulate` | `device` | Device emulation |
| `GET /set/viewport` | `width`, `height` | Set viewport |
| `GET /set/useragent` | `ua` | Set user agent |
| `GET /set/offline` | `offline` | Toggle offline |
| `GET /geolocation` | `lat`, `lng` | Override geolocation |

## React Inspection

| Path | Description |
|------|-------------|
| `GET /react/tree` | Component tree |
| `GET /react/inspect` | Props and state |
| `GET /react/renders` | Render tracking |

## Recording & Performance

| Path | Description |
|------|-------------|
| `GET /recording/start` | Record actions |
| `GET /recording/stop` | Stop + action log |
| `GET /vitals` | Core Web Vitals |
| `GET /trace/start` | Start trace |
| `GET /trace/stop` | Stop trace |

## Example: Session-Based Agent Loop

```bash
SESSION=my-agent
BASE=http://127.0.0.1:8080

# Create tab
curl -s -H "X-Kuri-Session: $SESSION" "$BASE/tab/new?url=https://example.com"

# Get page info
curl -s -H "X-Kuri-Session: $SESSION" "$BASE/page/info"

# Get snapshot
SNAP=$(curl -s -H "X-Kuri-Session: $SESSION" "$BASE/snapshot?filter=interactive&format=compact")

# Click element
curl -s -H "X-Kuri-Session: $SESSION" "$BASE/action?action=click&ref=e0"
```

## Example: Batch Execution

```bash
curl -s -X POST http://127.0.0.1:8080/batch \
  -H "X-Kuri-Session: my-agent" \
  -d '[
    {"path": "/navigate", "params": {"url": "https://example.com"}},
    {"path": "/snapshot", "params": {"filter": "interactive"}},
    {"path": "/action", "params": {"action": "click", "ref": "e0"}}
  ]'
```
