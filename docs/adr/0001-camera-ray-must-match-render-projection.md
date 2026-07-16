# ADR-0001 — El rayo de cámara debe coincidir con la proyección del render

Estado: aceptado · 2026-07-10

## Contexto

Al tocar la pantalla para dibujar o seleccionar, el punto/selección caía
**desfasado** horizontalmente, peor hacia los bordes. Causa: `CameraRay.from`
aplicaba el `aspect` ratio DOS veces (en `ndc.x` y en `halfW` → `aspect²`),
mientras el render (`SatinRenderer.projectionMatrix`, `x = y/aspect`) lo aplica
una sola vez. Rayo y render discrepaban → todo lo que usa raycast (dibujo,
selección de caras, gizmo, push/pull, sculpt) heredaba el error.

## Decisión

El rayo reconstruido desde un toque **debe** ser el inverso exacto de la matriz
de proyección usada para dibujar. `ndc.x` va en `[-1,1]` sin `aspect`; el
`aspect` se aplica una sola vez vía `halfW = halfH * aspect`.

## Consecuencia / regla

Cualquier cambio en `projectionMatrix` (FOV, aspect, near/far) obliga a revisar
`CameraRay.from`, y viceversa. Idealmente un test de ida-y-vuelta:
proyectar un punto mundo→pantalla con las matrices, y unproyectar
pantalla→rayo con `CameraRay`, debe reintersectar el mismo punto.
