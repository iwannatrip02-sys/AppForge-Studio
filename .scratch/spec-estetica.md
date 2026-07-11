## Problem Statement

La estética del workspace CAD se siente amateur e inmadura: los modelos no se
ven tan bien como Shapr3D (aristas como "tubos" oscuros, sin puntos de vértice,
superficie plana sin volumen), el fondo es plano, el grid y los números no
tienen el acabado de Shapr3D, y la distribución de la interfaz no está pulida.
El objetivo es que se vea y se sienta **igual o superior a Shapr3D**, fusionando
su precisión CAD con el estilo premium cálido (glow radial ember→steel, paneles
de vidrio) de la referencia tipo toolhive que le gusta al usuario.

## Solution

Fusionar toda la estética hacia una identidad coherente: aristas finas y claras,
puntos de vértice visibles, superficie PBR con luz suave, fondo carbón con glow
radial ember→steel muy sutil, grid fino con ejes de color, chrome de vidrio bien
distribuido y una barra de estado con medidas vivas estilo Shapr3D. La paleta ya
existe en AppTheme (ember #FF7A45, steel #6FA3D0, accentGlow #FFA06B); el render
debe honrarla.

## Implementation Decisions

- La identidad de color vive en AppTheme y es la fuente de verdad; el render la consume.
- Aristas como líneas claras (steel casi-blanco), no tubos oscuros.
- Fondo carbón unificado + glow radial sutil (shader/skybox), no color plano.
- Superficie de modelo con material PBR + IBL, no BasicColorMaterial.
- Puntos de vértice como sprites/discos sobre formas y primitivas.
- Grid fino con ejes rojo/verde/azul coherentes con los ejes del mundo.
- Chrome de vidrio (glassPanel) coherente, tipografía y espaciado maduros,
  barra de estado inferior con medidas vivas.

## Testing Decisions

- La estética se verifica **en device** (capturas), no por test unitario.
- Sí testeable: que AppTheme siga siendo la única fuente de color (sin literales
  de color sueltos nuevos en el render fuera del tema).

## Out of Scope

- Lógica de interacción del sketch (spec #10).
- Render final path-traced (entrega 1b posterior).

## Further Notes

Referencias del usuario: screenshot de Shapr3D (precisión de aristas/grid/gizmo)
+ mockup tipo toolhive (glow ember→azul premium). Fusionar ambos.
