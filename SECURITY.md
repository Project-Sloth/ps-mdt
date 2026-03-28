# MDT Tab Service Security Measures

This document outlines the security measures implemented to protect against FiveM exploiters and malicious localStorage manipulation.

## Security Threats Addressed

1. **Memory Exhaustion Attacks** - Preventing unlimited instances
2. **Data Injection Attacks** - Filtering malicious content
3. **XSS Prevention** - Sanitizing instance names
4. **Storage Quota Attacks** - Limiting payload sizes
5. **State Corruption** - Validating all stored data
6. **Function Injection** - Preventing code execution via data

## Implemented Protections

### Input Validation

-   **Instance IDs**: Must match pattern `^[a-zA-Z0-9_-]{1,32}$`
-   **Instance Names**: Max 50 chars, no HTML special characters (`<>'"&`)
-   **Tab Names**: Must be from predefined whitelist
-   **Data Size**: Limited to 10KB per instance

### Resource Limits

-   **Max Instances**: 10 instances maximum
-   **Max Total Storage**: 100KB total localStorage limit
-   **Instance State**: Ensures only one active instance at a time

### Data Sanitization

-   **Function Detection**: Blocks data containing 'function', 'eval', 'script'
-   **Serialization Validation**: Ensures all data is safely serializable
-   **Automatic Cleanup**: Removes corrupted data automatically

### Storage Security

-   **Size Checks**: Validates payload size before parsing
-   **Error Recovery**: Automatically cleans up corrupted localStorage
-   **State Validation**: Ensures consistent application state

## Security Configuration

All security limits and validation rules are centralized in `web/src/config/security.ts`:

```typescript
export const SECURITY_CONFIG = {
	// Instance Management
	MAX_INSTANCES: 10,
	MAX_INSTANCE_NAME_LENGTH: 50,

	// Data Storage
	MAX_DATA_SIZE: 10000, // 10KB per instance
	MAX_TOTAL_STORAGE_SIZE: 100000, // 100KB total

	// Input Validation
	ALLOWED_ID_PATTERN: /^[a-zA-Z0-9_-]{1,32}$/,
	FORBIDDEN_NAME_CHARS: ['<', '>', '&', '"', "'"],

	// Content Security
	FORBIDDEN_CONTENT_PATTERNS: [
		'function', 'eval', 'script', 'javascript:', 'data:',
		'<script', '</script>', 'onclick', 'onerror', 'onload'
	],

	// Whitelisted tabs
	ALLOWED_TABS: [...]
};
```

This centralized configuration can be imported and used by any part of the MDT system that needs security validation.

## Error Handling

-   **Silent Sanitization**: Invalid data is cleaned automatically
-   **Warning Logs**: Security violations are logged for debugging
-   **Graceful Degradation**: System continues working even with corrupted data
-   **Automatic Recovery**: Corrupted localStorage is reset automatically

## Best Practices

1. All user inputs are validated before processing
2. Data size limits prevent resource exhaustion
3. Whitelisted values prevent injection attacks
4. Automatic cleanup prevents persistent corruption
5. Security-first design with fail-safe defaults