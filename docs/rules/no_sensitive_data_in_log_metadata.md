<!-- example-scope: isolated no_sensitive_data_in_log_metadata -->

> **Example contract: `no_sensitive_data_in_log_metadata` only.** Dart fences are isolated sketches. GOOD labels describe a single-rule contrast, not compilation or whole-profile acceptance. Use the [checked runnable sources](../../examples/architecture/README.md) and [coverage matrix](../example_coverage.md).

# no_sensitive_data_in_log_metadata

**Rule name**: `no_sensitive_data_in_log_metadata`
**Severity**: Error

## Propósito

Previene que datos sensibles (tokens, passwords, API keys, cookies) se incluyan en logs. Los sistemas de observabilidad (ELK, CloudWatch, Datadog) almacenan logs en texto plano, accesibles por múltiples personas y sistemas. Loguear credenciales viola OWASP A09 (Security Logging and Monitoring Failures) y normativas de privacidad (GDPR).

## Diagnóstico

La regla detecta dos patrones:

### 1. Claves sensibles en metadata
Detecta claves prohibidas en el parámetro `metadata` de llamadas a AppLoggerService:
- `token`, `password`, `authorization`, `cookie`, `secret`
- `apiKey`, `refreshToken`, `accessToken`
- `passwd`, `credentials`, `bearer`

### 2. Patrones sensibles en mensajes
Detecta literales de string en el mensaje de log que contengan patrones como:
- `password: ...`, `token: ...`, `Bearer <token>`
- `api_key= ...`, `secret= ...`, `authorization: ...`

**Por qué aparece**: Los datos sensibles en logs persisten en texto plano en sistemas de observabilidad, pueden ser accedidos por personal no autorizado, y violan compliance de seguridad.

## Soluciones

### Rápida: Eliminar el dato sensible
```dart
// ❌ MAL
AppLoggerService.error('Auth failed', metadata: {'token': userToken});

// ✅ BIEN
AppLoggerService.error('Auth failed', metadata: {'userId': user.id});
```

### Recomendada: Masking/redacción
```dart
// ✅ BIEN - Solo loguear presencia, no valor
AppLoggerService.info('Token refreshed', metadata: {
  'tokenPresent': true,
  'userId': user.id,
});

// ✅ BIEN - Masking parcial (solo últimos 4 chars)
AppLoggerService.debug('API call', metadata: {
  'tokenSuffix': token.substring(token.length - 4),
});
```

### Alternativa: Identificadores no sensibles
```dart
// ✅ BIEN - Usar IDs de correlación
AppLoggerService.error('Request failed', metadata: {
  'requestId': request.id,
  'statusCode': response.statusCode,
});
```

## Ejemplos

### ❌ MAL (dispara la regla)
```dart
// Clave sensible en metadata
AppLoggerService.error('Auth failed', metadata: {
  'token': refreshToken,       // ← VIOLA: clave "token"
  'password': userPassword,    // ← VIOLA: clave "password"
});

// Clave sensible (case-insensitive)
AppLoggerService.info('Login', metadata: {
  'accessToken': jwt,          // ← VIOLA: contiene "accesstoken"
  'apiKey': key,               // ← VIOLA: contiene "apikey"
});

// Patrón sensible en mensaje
AppLoggerService.debug('Auth: password=${user.password}');  // ← VIOLA
AppLoggerService.info('Header: Bearer $token');              // ← VIOLA
```

### ✅ BIEN (no dispara la regla)
```dart
// Identificadores no sensibles
AppLoggerService.error('Auth failed', metadata: {
  'userId': user.id,
  'requestId': correlationId,
  'statusCode': 401,
});

// Masking
AppLoggerService.info('Token refreshed', metadata: {
  'tokenPresent': refreshToken != null,
  'tokenSuffix': '***${refreshToken?.substring(refreshToken.length - 4)}',
});

// Mensaje sin credenciales
AppLoggerService.info('Login successful for user ${user.id}');
```

## Falsos positivos conocidos

| Caso | Probabilidad | Mitigación |
|------|-------------|------------|
| Clave "token" que no es credencial (ej: CSRF token logging intencional) | Baja | Renombrar clave: `csrfPresent: true` |
| Metadata con clave dinámica que coincide | N/A | Solo se verifican claves literales |
| String con "password" en contexto no sensible | Muy baja | Solo se detecta patrón `password:` o `password=` |
| Variables de tipo opaco pasadas a metadata | N/A | No se verifica el valor, solo la clave |

**Tasa estimada de falsos positivos**: < 5%

## Política de excepciones

**No hay excepciones**. Loguear datos sensibles nunca está justificado en producción. Si necesitas debugging con credenciales:
- Usa un debugger local
- Loguea presencia (`tokenPresent: true`), no valor
- Usa masking (`***${value.substring(value.length - 4)}`)

## Checklist de migración (código legacy)

- [ ] Buscar `metadata:` en llamadas a `AppLoggerService` con claves sensibles
- [ ] Buscar patrones `password`, `token`, `Bearer` en mensajes de log
- [ ] Reemplazar claves sensibles por identificadores no sensibles
- [ ] Aplicar masking donde se necesite trazabilidad parcial
- [ ] Ejecutar `dart run custom_lint` para verificar 0 violaciones
- [ ] Revisar logs existentes en observabilidad para datos ya expuestos

## Claves prohibidas

| Clave | Riesgo |
|-------|--------|
| `token` | Acceso no autorizado a APIs |
| `password` / `passwd` | Compromiso de cuentas |
| `authorization` | Headers de autenticación completos |
| `cookie` | Secuestro de sesión |
| `secret` | Claves de cifrado/firma |
| `apiKey` | Acceso a servicios externos |
| `refreshToken` | Generación de nuevos access tokens |
| `accessToken` | Acceso directo a recursos protegidos |
| `credentials` | Cualquier combinación usuario/password |
| `bearer` | Token de autenticación HTTP |

## Guideline relacionada

- OWASP A09:2021 - Security Logging and Monitoring Failures
