# viewmodels_no_buildcontext

**Nivel**: MEDIO | **Tipo**: Architectural | **Área**: MVVM Separation

## Descripción

Esta regla enforza la separación estricta entre UI y lógica de negocio prohibiendo que ViewModels contengan referencias a `BuildContext`. Mantiene los ViewModels agnósticos de la UI y testeable independientemente.

## ¿Por qué es importante?

- **Clean Architecture**: Separación clara entre capas UI y lógica
- **Testability**: ViewModels testeables sin dependencias de UI
- **Reusability**: ViewModels reutilizables en diferentes contextos UI
- **Maintainability**: Cambios de UI no afectan lógica de negocio
- **MVVM pattern**: Mantiene el patrón Model-View-ViewModel correctamente

## Ejemplos

### ✅ Código correcto (no debe alertar)

```dart
// ViewModel sin BuildContext - correcto
class UserViewModel extends ChangeNotifier {
  final GetUsersUseCase _getUsersUseCase;
  final ValidationService _validator;
  
  UiState<List<User>> _state = UiState.idle();
  UiState<List<User>> get state => _state;
  
  UserViewModel(this._getUsersUseCase, this._validator);
  
  Future<void> loadUsers() async {
    _state = UiState.loading();
    notifyListeners();
    
    final result = await _getUsersUseCase.execute();
    _state = result.fold(
      onSuccess: (users) => UiState.success(users),
      onError: (error) => UiState.error(error),
    );
    notifyListeners();
  }
  
  // ✅ Comunicación via callbacks o state
  void onUserTapped(User user) {
    // Actualiza estado, widget reacciona
    _selectedUser = user;
    notifyListeners();
  }
}

// Widget maneja BuildContext - correcto
class UserListWidget extends StatelessWidget {
  final UserViewModel viewModel;
  
  const UserListWidget({required this.viewModel});
  
  @override
  Widget build(BuildContext context) { // ✅ BuildContext en widget
    return ChangeNotifierBuilder<UserViewModel>(
      notifier: viewModel,
      builder: (context, viewModel, child) {
        return viewModel.state.when(
          idle: () => Text('Press button to load'),
          loading: () => CircularProgressIndicator(),
          success: (users) => ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) => UserTile(users[index]),
          ),
          error: (error) => _showErrorDialog(context, error), // ✅ UI logic en widget
        );
      },
    );
  }
  
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(error),
      ),
    );
  }
}

// Otros ViewModels válidos
class AuthViewModel extends Cubit<AuthState> {
  final AuthRepository repository;
  
  AuthViewModel(this.repository) : super(AuthState.initial());
  
  Future<void> login(String email, String password) async {
    emit(AuthState.loading());
    // Business logic sin UI dependencies
  }
}

class CounterViewModel extends ValueNotifier<int> {
  CounterViewModel() : super(0);
  
  void increment() => value++;
  void decrement() => value--;
}
```

### ❌ Código incorrecto (debe alertar)

```dart
// ❌ ViewModel con BuildContext - incorrecto
class BadUserViewModel extends ChangeNotifier {
  final BuildContext _context; // ❌ ALERTA: BuildContext en ViewModel
  final GetUsersUseCase _getUsersUseCase;
  
  List<User> _users = [];
  
  BadUserViewModel(this._context, this._getUsersUseCase); // ❌ ALERTA: BuildContext como parámetro
  
  Future<void> loadUsers() async {
    try {
      final users = await _getUsersUseCase.execute();
      _users = users;
      notifyListeners();
    } catch (e) {
      // ❌ UI logic en ViewModel
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  void navigateToDetails(User user) {
    // ❌ Navigation logic en ViewModel
    Navigator.of(_context).push(
      MaterialPageRoute(builder: (_) => UserDetailsPage(user)),
    );
  }
}

// ❌ ViewModel con campo BuildContext
class NavigationViewModel extends ChangeNotifier {
  BuildContext? context; // ❌ ALERTA: Campo BuildContext
  
  void setContext(BuildContext ctx) {
    context = ctx;
  }
  
  void goBack() {
    if (context != null) {
      Navigator.of(context!).pop(); // ❌ UI logic en ViewModel
    }
  }
}

// ❌ ViewModel heredando con BuildContext
class DialogViewModel extends BaseViewModel {
  final BuildContext appContext; // ❌ ALERTA: BuildContext en constructor
  
  DialogViewModel(this.appContext);
  
  void showSuccess(String message) {
    showDialog(
      context: appContext,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
      ),
    );
  }
}
```

## Patrón correcto: Comunicación UI ↔ ViewModel

### ✅ Comunicación via State Management

```dart
// ViewModel expone estado, UI reacciona
class ProductViewModel extends ChangeNotifier {
  ProductState _state = ProductState.initial();
  ProductState get state => _state;
  
  Future<void> addToCart(Product product) async {
    _state = _state.copyWith(isAddingToCart: true);
    notifyListeners();
    
    final result = await cartService.addProduct(product);
    _state = result.fold(
      onSuccess: (_) => _state.copyWith(
        isAddingToCart: false,
        showSuccessMessage: true,
      ),
      onError: (error) => _state.copyWith(
        isAddingToCart: false,
        errorMessage: error,
      ),
    );
    notifyListeners();
  }
}

// Widget reacciona a cambios de estado
class ProductWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductViewModel>(
      builder: (context, viewModel, child) {
        // ✅ UI logic en widget basada en estado del ViewModel
        if (viewModel.state.showSuccessMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added to cart!')),
            );
          });
        }
        
        if (viewModel.state.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (context) => ErrorDialog(viewModel.state.errorMessage!),
            );
          });
        }
        
        return ProductDisplay(
          isLoading: viewModel.state.isAddingToCart,
          onAddToCart: () => viewModel.addToCart(product),
        );
      },
    );
  }
}
```

### ✅ Comunicación via Callbacks

```dart
// ViewModel con callbacks para UI actions
class SearchViewModel extends ChangeNotifier {
  List<Product> _results = [];
  List<Product> get results => _results;
  
  // Callbacks para UI actions
  Function(Product)? onProductSelected;
  Function(String)? onShowError;
  Function()? onNavigateToCart;
  
  void searchProducts(String query) async {
    try {
      _results = await searchService.search(query);
      notifyListeners();
    } catch (e) {
      onShowError?.call(e.toString()); // ✅ Delega UI action al widget
    }
  }
  
  void selectProduct(Product product) {
    onProductSelected?.call(product); // ✅ Delega navigation al widget
  }
}

// Widget maneja callbacks
class SearchWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchViewModel()
        ..onProductSelected = (product) {
          Navigator.push(context, ProductRoute(product)); // ✅ UI logic en widget
        }
        ..onShowError = (error) {
          showErrorSnackBar(context, error); // ✅ UI logic en widget
        },
      child: Consumer<SearchViewModel>(
        builder: (context, viewModel, child) {
          return SearchDisplay(
            results: viewModel.results,
            onSearch: viewModel.searchProducts,
            onProductTap: viewModel.selectProduct,
          );
        },
      ),
    );
  }
}
```

## Casos detectados

La regla identifica ViewModels que contienen:

1. **Campos BuildContext** - Variables de instancia tipo BuildContext
2. **Parámetros BuildContext** - Constructor parameters tipo BuildContext
3. **Referencias indirectas** - Campos que guardan BuildContext

## Clases monitoreadas

La regla aplica a clases que:

- **Terminan en "ViewModel"** - `UserViewModel`, `AuthViewModel`, etc.
- **Extienden ViewModel bases** - `ChangeNotifier`, `Cubit`, `Bloc`, `ValueNotifier`
- **Implementan interfaces ViewModel** - `BaseViewModel`, etc.

## Testing guide

### Setup de testing

```bash
flutter create test_viewmodel_separation
cd test_viewmodel_separation
```

### Configuración

En `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - viewmodels_no_buildcontext
```

### Casos de prueba

Crea `lib/test_bad_viewmodels.dart`:

```dart
// ESTE ARCHIVO DEBE GENERAR 4 WARNINGS

import 'package:flutter/material.dart';

// ❌ WARNING 1: Campo BuildContext
class UserViewModel extends ChangeNotifier {
  final BuildContext _context; // ❌ Debe alertar
  
  UserViewModel(this._context);
}

// ❌ WARNING 2: Parámetro BuildContext en constructor
class AuthViewModel extends Cubit<AuthState> {
  AuthViewModel(BuildContext context) : super(AuthState.initial()); // ❌ Debe alertar
}

// ❌ WARNING 3: Múltiples referencias BuildContext
class NavigationViewModel extends ChangeNotifier {
  BuildContext? appContext; // ❌ Debe alertar
  final BuildContext? _dialogContext; // ❌ Debe alertar
  
  NavigationViewModel(this._dialogContext);
}

// ❌ WARNING 4: BuildContext en ViewModel con sufijo correcto
class ProductListViewModel extends ValueNotifier<List<Product>> {
  final BuildContext context; // ❌ Debe alertar
  
  ProductListViewModel(this.context) : super([]);
}
```

Crea `lib/test_good_separation.dart`:

```dart
// ESTE ARCHIVO NO DEBE GENERAR WARNINGS

import 'package:flutter/material.dart';

// ✅ ViewModel sin BuildContext - correcto
class CleanUserViewModel extends ChangeNotifier {
  final UserRepository repository;
  final ValidationService validator;
  
  UiState<User> _state = UiState.idle();
  UiState<User> get state => _state;
  
  CleanUserViewModel(this.repository, this.validator);
  
  Future<void> loadUser() async {
    // Business logic sin UI dependencies
  }
}

// ✅ Widget con BuildContext - permitido
class UserWidget extends StatelessWidget {
  final BuildContext context; // ✅ Widgets pueden tener BuildContext
  
  const UserWidget({required this.context});
  
  @override
  Widget build(BuildContext context) => Container();
}

// ✅ Service con BuildContext - permitido (no es ViewModel)
class NavigationService {
  final BuildContext context; // ✅ Services pueden tener BuildContext
  
  NavigationService(this.context);
}

// ✅ Repository con BuildContext - permitido (no es ViewModel)
class DatabaseRepository {
  final BuildContext appContext; // ✅ No es ViewModel
  
  DatabaseRepository(this.appContext);
}

// ✅ Abstract ViewModel - permitido
abstract class BaseViewModel<T> extends ChangeNotifier {
  T get state;
}
```

### Verificación

```bash
dart run custom_lint
```

**Resultado esperado**:
- `test_bad_viewmodels.dart`: 4 warnings
- `test_good_separation.dart`: 0 warnings

## Configuración

Esta regla no requiere configuración. Aplica automáticamente a:

- **ViewModels**: Clases con "ViewModel" en el nombre
- **State management classes**: ChangeNotifier, Cubit, Bloc, ValueNotifier
- **Custom base classes**: BaseViewModel, ViewModel, etc.

## Alternativas recomendadas

En lugar de BuildContext en ViewModels, usa:

### 1. **State-based communication**
```dart
// ViewModel expone estado
class UserViewModel extends ChangeNotifier {
  UiState<User> get state => _state;
  String? get errorMessage => _errorMessage;
  bool get shouldShowDialog => _shouldShowDialog;
}
```

### 2. **Callback-based communication**
```dart
// ViewModel usa callbacks
class ProductViewModel {
  Function(Product)? onProductAdded;
  Function(String)? onErrorOccurred;
  Function()? onNavigateToCart;
}
```

### 3. **Event-based communication**
```dart
// ViewModel emite eventos
class OrderViewModel {
  final StreamController<UiEvent> _events = StreamController();
  Stream<UiEvent> get events => _events.stream;
  
  void submitOrder() {
    _events.add(ShowSuccessDialog());
  }
}
```

## Impacto en performance

- **Análisis**: Ligero - solo examina ViewModels
- **Aplicación**: Alto beneficio - mejora testability y maintainability
- **Falsos positivos**: Muy bajos - detección específica y precisa

## Relación con otras reglas

- Complementa `viewmodels_call_super_dispose`
- Refuerza separation of concerns
- Trabaja junto con dependency injection patterns

## Referencias

- [MVVM Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)
- [Flutter State Management](https://docs.flutter.dev/development/data-and-backend/state-mgmt)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)