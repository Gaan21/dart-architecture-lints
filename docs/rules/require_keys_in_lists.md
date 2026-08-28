# require_keys_in_lists

**Keys obligatorias en ListView/GridView dinámicos**

## 🎯 Resumen

Esta regla detecta cuando items en `ListView.builder` o `GridView.builder` no tienen keys y sugiere añadirlas para mejorar el rendimiento.

## 📋 Guideline implementada

**Invariante**: "ValueKey en listas" para performance óptima

## ⚠️ Problema detectado

Widgets en listas dinámicas sin keys pueden causar:
- **Rebuilds innecesarios** cuando la lista cambia
- **Bugs de estado** si widgets mantienen estado interno
- **Performance degradada** en listas grandes
- **Animaciones incorrectas** al reordenar items

## ✅ Código correcto (no alertará)

```dart
// ✅ ListView.builder con keys apropiadas
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) => ListTile(
    key: ValueKey(users[index].id), // ✅ Key única
    title: Text(users[index].name),
    subtitle: Text(users[index].email),
  ),
);

// ✅ GridView.builder con ObjectKey
GridView.builder(
  itemCount: products.length,
  itemBuilder: (context, index) => Card(
    key: ObjectKey(products[index]), // ✅ Key basada en objeto
    child: Column(
      children: [
        Text(products[index].name),
        Text('\$${products[index].price}'),
      ],
    ),
  ),
);

// ✅ Lista estática - no necesita keys
ListView(
  children: [
    Text('Item 1'),
    Text('Item 2'),
    Text('Item 3'),
  ],
);
```

## ❌ Código incorrecto (alertará)

```dart
// ❌ ListView.builder sin keys
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) => ListTile( // ⚠️ FALTA KEY
    title: Text(users[index].name),
    subtitle: Text(users[index].email),
  ),
);

// ❌ GridView.builder sin keys
GridView.builder(
  itemCount: products.length,
  itemBuilder: (context, index) => Card( // ⚠️ FALTA KEY
    child: Column(
      children: [
        Text(products[index].name),
        Text('\$${products[index].price}'),
      ],
    ),
  ),
);

// ❌ Container sin key en lista dinámica
ListView.builder(
  itemBuilder: (context, index) => Container( // ⚠️ FALTA KEY
    padding: EdgeInsets.all(8),
    child: Text(items[index]),
  ),
);
```

## 🔧 Cómo corregir

### 1. Usar ValueKey para IDs únicos
```dart
// Cuando tienes un ID único
ListTile(
  key: ValueKey(user.id), // ✅ ID único como key
  title: Text(user.name),
)
```

### 2. Usar ObjectKey para objetos completos
```dart
// Cuando el objeto completo es único
Card(
  key: ObjectKey(product), // ✅ Objeto completo como key
  child: ProductWidget(product),
)
```

### 3. Usar índice solo si la lista no cambia
```dart
// Solo si la lista NUNCA se reordena/modifica
ListTile(
  key: ValueKey(index), // ⚠️ Solo para listas inmutables
  title: Text(staticItems[index]),
)
```

## 💡 Tipos de Keys recomendadas

| Situación | Key recomendada | Ejemplo |
|-----------|----------------|---------|
| Objeto con ID único | `ValueKey(object.id)` | `ValueKey(user.id)` |
| Objeto sin ID | `ObjectKey(object)` | `ObjectKey(product)` |
| String único | `ValueKey(string)` | `ValueKey(category.name)` |
| Lista inmutable | `ValueKey(index)` | `ValueKey(index)` |

## 🎯 Widgets detectados

La regla detecta estos widgets comúnmente usados en listas:
- `ListTile`
- `Card` 
- `Container`
- `Row`/`Column`
- `Text`
- `Padding`
- `SizedBox`
- `InkWell`/`GestureDetector`
- `Material`
- `Stack`/`Positioned`
- Custom widgets que extienden `Widget`

## 🚫 Excepciones

**No alertará en estos casos:**
- Listas estáticas (`ListView(children: [...])`)
- Widgets que ya tienen key
- Constructores que no crean widgets de Flutter

## 🧪 Testing Guide

### Caso de prueba básico
```dart
// test_project/lib/main.dart
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final List<User> users = [
    User(1, 'Alice'),
    User(2, 'Bob'),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => ListTile( // ❌ Debe alertar
            title: Text(users[index].name),
          ),
        ),
      ),
    );
  }
}

class User {
  final int id;
  final String name;
  User(this.id, this.name);
}
```

### Comando de prueba
```bash
cd test_project
dart run custom_lint

# Output esperado:
# lib/main.dart:17:45 • Items in dynamic lists should have keys for better performance. This prevents unnecessary widget rebuilds when the list changes. • require_keys_in_lists
```

### Verificar corrección
```dart
// Después de añadir key:
itemBuilder: (context, index) => ListTile(
  key: ValueKey(users[index].id), // ✅ Corregido
  title: Text(users[index].name),
),

// Resultado: Sin alertas
```

## 📊 Métricas de impacto

**Performance benefits:**
- Reduce rebuilds hasta 70% en listas que cambian frecuentemente
- Mejora scroll performance en listas de 100+ items
- Previene memory leaks por widgets no liberados correctamente

**Casos críticos:**
- Listas con formularios (TextFields mantienen focus)
- Listas con animaciones (Hero widgets)
- Listas con estado complejo (checkboxes, toggles)

## 🔗 Referencias

- [Flutter Performance Best Practices - Keys](https://docs.flutter.dev/development/ui/widgets-intro#keys)
- [Widget Keys Official Documentation](https://api.flutter.dev/flutter/foundation/Key-class.html)
- [When to Use Keys in Flutter](https://medium.com/flutter/keys-what-are-they-good-for-13cb51742e7d)