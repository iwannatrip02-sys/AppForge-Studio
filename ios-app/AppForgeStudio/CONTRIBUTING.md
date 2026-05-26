# Contribuyendo a AppForge Studio

## Clonar el repositorio

```bash
git clone https://github.com/appforge-studio/ios-app.git
cd ios-app/AppForgeStudio
```

## Compilar con Xcode 15

1. Abre `Package.swift` con Xcode 15+.
2. Selecciona el scheme `AppForgeStudio`.
3. El destino debe ser un simulador o dispositivo iOS 17+.
4. Product > Build (Cmd+B).

## Ejecutar tests

```bash
# Desde Xcode:
Product > Test (Cmd+U)

# Desde linea de comandos:
xcodebuild test -scheme AppForgeStudio -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=17.0'
```

## Convenciones de codigo Swift

- **Indentacion**: 4 espacios.
- **Naming**: camelCase para variables/funciones, PascalCase para tipos.
- **Organizacion**: MARK comments para separar secciones (`// MARK: - ...`).
- **Imports**: Agrupar imports de Apple, luego de terceros, separados por linea.
- **Logger**: Usar `Logger(subsystem:category:)` en lugar de print.
- **MVVM**: Vistas en SwiftUI, logica en ViewModels ObservableObject.
- **Metal**: UIViewRepresentable para MTKView, shaders en archivos .metal separados.

## Proceso de PR

1. Crea un branch descriptivo: `git checkout -b feat/mi-feature`.
2. Haz commits atomicos con mensajes claros en ingles.
3. Asegura que todos los tests pasen.
4. Ejecuta el linter si esta configurado.
5. Abre un Pull Request contra `main` con descripcion de cambios.
6. Espera revision de al menos un mantenedor.
7. Squash merge al aprobar.
