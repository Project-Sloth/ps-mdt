# Security Audit — ps-mdt v3.1.0

---

## HIGH

### 1. Privilege Escalation via `updatePermissionRole`
`server/backend/management.lua:221` — Any officer can modify role permissions for any job/grade. Missing `CheckPermission('management_permissions')`.

### 2. Unauthenticated Profile Picture Upload via `uploadSuspectPhoto`
`server/fivemanage.lua:143` — No `CheckAuth()` at all. Any civilian can change any citizen's profile picture.

---

## MEDIUM

### 3. Missing `warrants_issue` on `issueWarrant`
`server/backend/warrants.lua:85` — Any officer can issue warrants.

### 4. Missing `warrants_close` on `closeWarrant`
`server/backend/warrants.lua:123` — Any officer can close warrants.

### 5. Missing `charges_edit` on `giveCitation`
`server/backend/sentencing.lua:55` — Any officer can deduct money via citation.

### 6. Missing `management_awards` on `saveAward`
`server/backend/management.lua:460` — Any officer can create/modify awards.

### 7. Missing `vehicles_edit_dmv` on `impoundVehicle` / `releaseImpound`
`server/backend/impound.lua:4` and `server/backend/impound.lua:53` — Any officer can impound/release vehicles.

### 8. Missing permission + sentence cap on `sendToJail`
`server/backend/sentencing.lua:6` — Any officer can jail any player with unlimited sentence.

---

## LOW

### 9. Global anti-spam blocks all officers on `processFine`
`server/backend/charges.lua:35` — `fineAntiSpam` is a global boolean. One officer's fine blocks everyone for 30s.

---

## What's Secure

- All SQL parameterized — no injection
- Report access control properly validates restrictions
- API keys in convars, not committed
- Dependencies current, no known critical advisories
