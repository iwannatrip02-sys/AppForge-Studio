# Integracion CAD-8 / CAD-9 y estado de IBL
> Fecha: 2026-05-05

## CAD-8: COMPLETADO (de facto)
CADModeView.swift en `ios-app/AppForgeStudio/Features/CADMode/` ya integra CADSketchEngine como @StateObject, tiene 4 tabs (Model/Parametric/Settings/Export), 4 transform tools + 10 CAD tools + 6 sketch tools. Extrude resultante se agrega a `canvasVM.scene.addModel(model)`.

## CAD-9: COMPLETADO (de facto)
Scene3D.swift ya tiene `var constraintManager = GeometryConstraintManager()` con `setupConstraintClosures()` en init(). El GeometryConstraintManager real usa SolveSpaceSolver con Newton-Raphson + Cholesky, 11 ConstraintTypes, SolverMetrics.

## IBL: Pipeline pendiente
IBLShaders.metal (283 lineas) ya tiene fresnel_schlick, distribution_ggx, geometry_smith, calculate_pbr_ibl con irradianceMap+prefilterMap+brdfLUT como samplers. PBRMaterialUniforms.swift tiene las propiedades MTLTexture? pero falta generateIrradianceMap(), generatePrefilterMap(), generateBRDFLUT() en compute shaders.

## Nota sobre los 8 archivos en raiz
Creacion previa en `Sources/CADCore/` (raiz) es redundante vs `ios-app/.../Sources/CADCore/`. No interfieren por estar en rutas separadas. Los archivos reales son superiores (C API, ObservableObject, 11 constraint types).
