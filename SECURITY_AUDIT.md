# Security Audit — ps-mdt v3.1.0

**Auditor:** Hermes Agent (automated defensive audit)
**Date:** 2026-06-09
**Scope:** Full project — server Lua, client Lua, SQL schema, web frontend, config, dependencies
**Method:** Source code review following OWASP + FiveM-specific threat model

---

## Executive Summary

- **Overall risk:** Medium-High
- **Biggest risk:** Missing permission checks on sensitive server callbacks allow any authenticated officer to perform admin-level actions (modify permissions, issue warrants, impound vehicles, issue fines)
- **Release recommendation:** Ship after fixes — 2 confirmed High, 5 confirmed Medium findings

---

## Attack Surface Map

| Entry Point | Trust Boundary | Sensitive Action | Auth | Permission Check | Risk |
|---|---|---|---|---|---|
| `updatePermissionRole` | Client→Server | Modify role permissions | ✅ CheckAuth | ❌ MISSING | **HIGH** |
| `uploadSuspectPhoto` | Client→Server | Change citizen profile picture | ❌ NO AUTH | ❌ MISSING | **HIGH** |
| `issueWarrant` | Client→Server | Issue arrest warrant | ✅ CheckAuth | ❌ MISSING `warrants_issue` | **MED** |
| `closeWarrant` | Client→Server | Close active warrant | ✅ CheckAuth | ❌ MISSING `warrants_close` | **MED** |
| `giveCitation` | Client→Server | Deduct money from player | ✅ CheckAuth | ❌ MISSING `charges_edit` | **MED** |
| `saveAward` | Client→Server | Create/modify awards | ✅ CheckAuth | ❌ MISSING `management_awards` | **MED** |
| `impoundVehicle` | Client→Server | Impound player vehicle | ✅ CheckAuth | ❌ MISSING | **MED** |
| `releaseImpound` | Client→Server | Release impounded vehicle | ✅ CheckAuth | ❌ MISSING | **MED** |
| `processFine` | Client→Server | Deduct money (fine) | ✅ CheckAuth | ✅ has `charges_edit`* | LOW |
| `sendToJail` | Client→Server | Send player to jail | ✅ CheckAuth | ❌ MISSING | **MED** |

*`processFine` has its own issue: global anti-spam cooldown shared across all players.

---

## Findings

### [HIGH] F-01: Missing Permission Check on `updatePermissionRole` — Privilege Escalation

**Status:** Confirmed
**Affected file:** `server/backend/management.lua:221-253`
**Affected entry point:** `ps-mdt:server:updatePermissionRole` callback
**Impact:** Any authenticated officer (police/ems/doj) can modify permission roles for ANY job and ANY grade, including granting themselves all management permissions. This is a direct privilege escalation — a grade-0 officer can make themselves a boss with full permissions.
**Why it exists:** The callback checks `CheckAuth(src)` (job-type gate) but does NOT call `CheckPermission(src, 'management_permissions')` before allowing writes to `mdt_permission_roles`.
**Attack path:** Client sends crafted payload `{job: "police", grade: 0, permissions: [all permissions]}` → server writes to DB → officer now has all permissions.
**Fix:** Add permission check after auth:
```lua
if not CheckPermission(src, 'management_permissions') then
    return { success = false, message = 'Insufficient permissions' }
end
```
**Regression test:** Login as grade-0 officer, attempt to call `updatePermissionRole` — should be rejected.

---

### [HIGH] F-02: Missing Auth Check on `uploadSuspectPhoto` — Unauthenticated Profile Picture Change

**Status:** Confirmed
**Affected file:** `server/fivemanage.lua:143-172`
**Affected entry point:** `ps-mdt:server:uploadSuspectPhoto` callback
**Impact:** ANY player (including civilians, non-EMS, non-LEO) can call this callback to upload arbitrary images and set them as any citizen's profile picture. No `CheckAuth()` is called. The only validation is that `citizenid` and `base64Image` are non-nil.
**Why it exists:** The nearby `uploadMugshotBase64` callback (line 79) correctly checks `CheckAuth(source)`, but `uploadSuspectPhoto` was added without the same guard.
**Attack path:** Civilian player calls callback with any citizenid + arbitrary base64 image → image uploaded to FiveManage, stored as profile picture in `mdt_profiles` and `mdt_profiles_gallery`.
**Fix:** Add auth + permission check:
```lua
ps.registerCallback(resourceName .. ':server:uploadSuspectPhoto', function(source, citizenid, base64Image)
    if not CheckAuth(source) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(source, 'evidence_upload') then
        return { success = false, message = 'Insufficient permissions' }
    end
    -- ... rest of function
```
**Regression test:** Login as civilian, attempt to call `uploadSuspectPhoto` — should return Unauthorized.

---

### [MEDIUM] F-03: Missing `warrants_issue` Permission Check on `issueWarrant`

**Status:** Confirmed
**Affected file:** `server/backend/warrants.lua:85-121`
**Affected entry point:** `ps-mdt:server:issueWarrant` callback
**Impact:** Any authenticated officer can issue arrest warrants, bypassing the `warrants_issue` permission defined in `Config.ManagementPermissions`. This allows officers who should only have view access to issue warrants against any citizen.
**Fix:** Add after line 87:
```lua
if not CheckPermission(src, 'warrants_issue') then
    return { success = false, error = 'Insufficient permissions' }
end
```

---

### [MEDIUM] F-04: Missing `warrants_close` Permission Check on `closeWarrant`

**Status:** Confirmed
**Affected file:** `server/backend/warrants.lua:123-150`
**Affected entry point:** `ps-mdt:server:closeWarrant` callback
**Impact:** Any authenticated officer can close active warrants, bypassing the `warrants_close` permission. An officer without warrant management authority could close warrants issued by others.
**Fix:** Add after line 125:
```lua
if not CheckPermission(src, 'warrants_close') then
    return { success = false, error = 'Insufficient permissions' }
end
```

---

### [MEDIUM] F-05: Missing Permission Check on `giveCitation` — Money Deduction Without Authority

**Status:** Confirmed
**Affected file:** `server/backend/sentencing.lua:55-99`
**Affected entry point:** `ps-mdt:server:giveCitation` callback
**Impact:** Any authenticated officer can issue fines and deduct money from any online player's bank account without `charges_edit` permission. The `processFine` callback in `charges.lua` correctly checks `CheckPermission(src, 'charges_edit')` but `giveCitation` does not.
**Fix:** Add after line 57:
```lua
if not CheckPermission(src, 'charges_edit') then
    return { success = false, message = 'Insufficient permissions' }
end
```

---

### [MEDIUM] F-06: Missing Permission Check on `saveAward`

**Status:** Confirmed
**Affected file:** `server/backend/management.lua:460-501`
**Affected entry point:** `ps-mdt:server:saveAward` callback
**Impact:** Any authenticated officer can create or modify award configurations. Awards are shared across the department and could be used to manipulate officer tracking/recognition.
**Fix:** Add after line 462:
```lua
if not CheckPermission(src, 'management_awards') then
    return { success = false, message = 'Insufficient permissions' }
end
```

---

### [MEDIUM] F-07: Missing Permission Checks on `impoundVehicle` and `releaseImpound`

**Status:** Confirmed
**Affected file:** `server/backend/impound.lua:4-50` and `server/backend/impound.lua:53-131`
**Affected entry points:** `ps-mdt:server:impoundVehicle`, `ps-mdt:server:releaseImpound`
**Impact:** Any authenticated officer can impound or release any vehicle by plate number. No granular permission check beyond job-type auth. An officer without vehicle management authority could impound/release vehicles at will.
**Fix:** Add permission check for both callbacks:
```lua
-- For impoundVehicle (after line 6):
if not CheckPermission(src, 'vehicles_edit_dmv') then
    return { success = false, message = 'Insufficient permissions' }
end
```

---

### [MEDIUM] F-08: Missing Permission Check on `sendToJail`

**Status:** Confirmed
**Affected file:** `server/backend/sentencing.lua:6-53`
**Affected entry point:** `ps-mdt:server:sendToJail` callback
**Impact:** Any authenticated officer can send any online player to jail with any sentence length. No permission check beyond basic auth. No server-side validation of sentence reasonableness beyond `sentence > 0`.
**Fix:** Add permission check and sentence cap:
```lua
if not CheckPermission(src, 'charges_edit') then
    return { success = false, message = 'Insufficient permissions' }
end
local maxSentence = 999 -- or from config
if sentence > maxSentence then
    return { success = false, message = 'Sentence exceeds maximum' }
end
```

---

### [LOW] F-09: Global Anti-Spam Cooldown on `processFine` Blocks All Officers

**Status:** Confirmed
**Affected file:** `server/backend/charges.lua:35`
**Affected entry point:** `ps-mdt:server:processFine` callback
**Impact:** `fineAntiSpam` is a module-level boolean shared across ALL players. When one officer processes a fine, ALL other officers are blocked from processing fines for 30 seconds. This is a denial-of-service against the fine system — not exploitable for gain but degrades usability during high-activity periods.
**Fix:** Replace global boolean with per-player cooldown tracking:
```lua
local fineCooldowns = {} -- src -> timestamp
-- In callback:
local now = GetGameTimer and GetGameTimer() or (os.time() * 1000)
if fineCooldowns[src] and (now - fineCooldowns[src]) < cooldown then
    return { success = false, message = 'Fine processing on cooldown' }
end
fineCooldowns[src] = now
```

---

## Items Reviewed But Found Secure

- **SQL queries:** All queries use parameterized `?` placeholders. No SQL injection found. String formatting (`:format()`) is only used for IN-clause placeholders built from already-validated arrays, not user input.
- **NUI security config:** `web/src/config/security.ts` has XSS prevention (forbidden content patterns, name character validation, storage size limits). Client-side only but defense-in-depth is appropriate.
- **Secrets handling:** FiveManage API keys are loaded from server convars (`GetConvar`), not committed to source. Good practice.
- **Dependencies:** Svelte 5, Vite 6, Tailwind 4, tiptap 2.x, chart.js 4.x — all current major versions. No known critical advisories at time of audit.
- **Config defaults:** No hardcoded secrets, no insecure default passwords.
- **Report access control:** `checkReportAccess` in reports.lua properly validates report restrictions by citizenid/job/jobtype before allowing edits.
- **Auth system:** `CheckAuth` correctly gates on `Config.PoliceJobType`, `Config.MedicalJobType`, and DOJ jobs. Session tracking (login/logout) uses transactions to prevent race conditions.
- **Cache:** TTL-based cache with invalidation. No security impact.
- **.gitignore:** Correctly excludes `node_modules` and `dist`.

---

## Fix Plan

### Fix Now (before merge)
- F-01: Add `CheckPermission(src, 'management_permissions')` to `updatePermissionRole`
- F-02: Add `CheckAuth(source)` + permission check to `uploadSuspectPhoto`

### Fix Next (next release)
- F-03: Permission check on `issueWarrant`
- F-04: Permission check on `closeWarrant`
- F-05: Permission check on `giveCitation`
- F-06: Permission check on `saveAward`
- F-07: Permission checks on impound callbacks
- F-08: Permission check + sentence cap on `sendToJail`

### Hardening
- F-09: Per-player cooldown for `processFine`

---

## Regression Tests

1. Login as grade-0 officer → call `updatePermissionRole` → expect rejection
2. Login as civilian → call `uploadSuspectPhoto` → expect Unauthorized
3. Login as officer without `warrants_issue` → call `issueWarrant` → expect rejection
4. Login as officer without `warrants_close` → call `closeWarrant` → expect rejection
5. Login as officer without `charges_edit` → call `giveCitation` → expect rejection
6. Two officers process fines simultaneously → second should succeed (not blocked by first)
7. Officer sends player to jail with sentence=999999 → expect cap enforcement

---

*This is a defensive security audit. No exploits were executed against live servers. All findings are based on source code review.*
