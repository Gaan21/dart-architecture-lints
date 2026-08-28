# avoid_hardcoded_strings

## Descripción
Esta regla detecta strings literales hardcoded en widgets de UI y sugiere el uso de internacionalización (i18n).

## ¿Por qué es importante?
- **Mantenibilidad**: Facilita traducciones y cambios de texto
- **Consistencia**: Centraliza todos los textos de usuario
- **Guidelines**: Cumple las invariantes del proyecto sobre i18n obligatorio

## Detecta
```dart
// ❌ Casos que generan error
Text('Guardar')
AppBar(title: Text('Mi App'))
AlertDialog(title: Text('Error'))
ElevatedButton(child: Text('Continuar'))
```

## No detecta (casos permitidos)
```dart
// ✅ Strings con i18n
Text('common.save'.tr())
AppBar(title: Text('app.title'.tr()))

// ✅ Strings técnicos
const String apiUrl = 'https://api.example.com';
Widget(key: ValueKey('user_list_item'));
const String path = '/api/users';

// ✅ Archivos de test
// (la regla no se aplica en archivos test/)
```

## Configuración
```yaml
custom_lint:
  rules:
    avoid_hardcoded_strings: true
```

## Widgets afectados
La regla detecta strings hardcoded en estos widgets de Flutter:

- `Text`
- `AppBar`
- `AlertDialog` 
- `SnackBar`
- `FloatingActionButton`
- `ElevatedButton`, `TextButton`, `OutlinedButton`
- `Tooltip`
- `ListTile`
- `Card`
- `Chip`
- `Tab`
- `NavigationDestination`
- `BottomNavigationBarItem`

## Propiedades afectadas
En widgets UI, detecta strings hardcoded en estas propiedades:

- `title`, `label`, `text`, `content`
- `message`, `tooltip`
- `hintText`, `labelText`, `helperText`
- `errorText`, `prefixText`, `suffixText`
- `counterText`, `semanticsLabel`

## Excepciones técnicas
La regla NO alerta para strings que sean:

- **URLs**: `'https://api.example.com'`
- **Paths API**: `'/api/users'`
- **Keys/IDs**: `'user_id'`, `'app.config'`
- **Strings muy cortos**: `'/'`, `'+'`
- **Colores hex**: `'#FF0000'`
- **Ya con i18n**: `'key'.tr()`
- **En archivos test**

## Solución recomendada
```dart
// ❌ Antes
Text('Guardar')

// ✅ Después
Text('common.save'.tr())
```

## Testing
Para probar esta regla, crear archivos de prueba con casos correctos e incorrectos y ejecutar:

```bash
dart run custom_lint
```
