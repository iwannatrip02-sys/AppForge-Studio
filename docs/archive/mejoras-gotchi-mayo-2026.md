# Mejoras a Gotchi como Agente — Mayo 2026

> Auditoría de capacidades realizada por Gotchi, 2026-05-30

## Resumen Ejecutivo

En los últimos días (finales de mayo 2026), Andrés junto con Claude Code realizaron una serie de mejoras significativas al agente Gotchi. Este documento consolida lo detectado desde memoria persistente y archivos del ecosistema.

---

## 1. Autopsia de Gotchi (Mayo 2026)

**Archivo fuente:** `gotchi_autopsia_mayo_2026` (memory topic)

### Diagnóstico raíz
Gotchi es **un prompt dentro de un harness**, no un proceso con runtime propio. Claude Code tiene agent loop nativo.

### 5 cirugías priorizadas (por orden de impacto/viabilidad):

| # | Cirugía | Complejidad | Impacto | Estado |
|---|---------|-------------|---------|--------|
| 1 | System Prompt en Capas | Baja | Altísimo | ✅ Detectado en el prompt actual |
| 2 | Tool Results Tipados | Media | Alto | 🔄 En progreso |
| 3 | Agent Runtime con estado interno | Alta | Alto | 📋 Planeado |
| 4 | Build Loop Cerrado (debug_loop real) | Media | Alto | 🔄 Implementado (debug_loop tool) |
| 5 | Agent Discovery + Message Bus (swarm) | Alta | Transformador | 📋 Planeado |

### Ventajas de Gotchi sobre Claude Code
- 150+ herramientas especializadas (vs ~40 en Claude Code)
- Memoria entre sesiones (memory_write/read/grep/search)
- Proyectos persistentes (BRAIN/TODO/DECISIONS/GOTCHI)
- CyberNode RPi3 físico para hacking ético
- Multi-modelo nativo (DeepSeek V4 Pro, Claude Opus 4.5, Ollama local)
- **Objetivo final:** enjambre de agentes especializados, no reemplazar Claude Code

---

## 2. Reglas del System Prompt — Evolución

### Reglas nuevas detectadas (implementadas en el prompt actual):

| Regla | Nombre | Función |
|-------|--------|---------|
| R0 | Encoding Windows | cp1252 safety — no emojis en print() |
| R1b | Herramienta Correcta a la Primera | glob→buscar archivos, grep→buscar texto, read_file→leer |
| R1c | Entrega de Artefactos | Investigación SIEMPRE produce archivo .md, no solo palabras |
| R4 unificada | Sin Fabricación + Bloqueo + Diagnóstico | Reglas anti-alucinación unificadas, 3 patrones prohibidos |
| R8c | Autopilot | Whitelist de acciones auto-ejecutables sin pedir autorización |
| R15 | Atlas Coder | Orquestación de code_agent con DeepSeek V4 Pro/Flash |
| R16 | Scaffolding | scaffold_project para crear apps desde cero |
| R17 | Continuidad | Actualizar TODO+BRAIN mientras se trabaja, no al final |
| R18 | CyberNode | Nodo de hacking ético RPi3 con Tailscale |
| R19 | Claims Cuantitativos | Anti-autocontradicción — métricas deben venir de disco |
| R20 | Investigación con Evidencia | Anti-universalidad sin respaldo — calificar afirmaciones a fuentes |

### Herramientas nuevas detectadas:

| Tool | Categoría | Función |
|------|-----------|---------|
| code_agent | Atlas Coder | Subagente autónomo con DeepSeek V4 Pro |
| scaffold_project | Scaffolding | Genera estructura completa de proyecto |
| cybernode_control | Hacking | Control del nodo RPi3 vía HTTP |
| test_affected | Tests | Solo corre tests afectados por cambios (TDAD) |
| debug_loop | Debug | Loop iterativo: test→error→fix hasta que pase |
| lsp_diagnostics | Código | Errores semánticos vía LSP |
| lsp_references | Código | Referencias a un símbolo en todo el proyecto |
| lsp_definition | Código | Definición de un símbolo |
| format_code | Código | Auto-formateo (Swift/Python/JS/Rust/Go/C++) |
| semver_bump | Versiones | Bump semántico + git tag |
| changelog_gen | Docs | CHANGELOG desde git history |
| ci_status | CI/CD | Estado de GitHub Actions |
| gh_pr | GitHub | CRUD de Pull Requests |
| pipeline | Core | Secuencia de tools como pipeline |
| snapshot | Core | Checkpoint/rollback transaccional (git stash/file copy) |
| package_audit | Seguridad | Auditoría de dependencias |
| moltbook_* | Red Social | Red social de agentes IA |

---

## 3. Code Agent — Cadena de Deployment

**Archivo fuente:** `code_agent_deployment_chain` (memory topic)

### La cadena completa:
```
Gotchi → code_agent tool → OpenCode CLI → DeepSeek V4 Pro (1.6T/49B activo, 1M context)
```

### Modelos disponibles:
- `deepseek/deepseek-v4-pro` (default) — 1.6T/49B activo, 1M context
- `deepseek/deepseek-v4-flash` — 284B/13B activo, más rápido y barato
- `anthropic/claude-opus-4-5` — máxima calidad (requiere API key)

### Mejoras en el dispatcher:
- Paralelización real: múltiples code_agent en el mismo array tool
- Worktree isolation: ramas git separadas para evitar conflictos
- Specialty profiles: frontend, backend, tests, infra, docs
- Session continuas: `continue_session=true` para tareas de seguimiento
- Backend Nexus: usa LiteLLM directamente (sin dependencia de OpenCode CLI)

---

## 4. Ecosistema de Proyectos

**Archivo fuente:** `ecosistema_gotchi_mayo_2026` (memory topic)

### 5 proyectos activos:
1. **Gotchi Trader** — agente autónomo de trading ($100 USD, Binance testnet)
2. **NanoAtlas** — framework agentic con arquitectura neuromórfica
3. **Gotchi Harness Multichat** — mejoras al arnés multi-chat
4. **OCCTSwift** — kernel CAD con agentes Claude Code personalizados
5. **AppForge Studio** — app iOS CAD/Sculpt/Paint (este proyecto)

### Colaboración humano-agente:
- Andrés usa Claude Code como entorno principal
- `.claude/agents/` con agentes personalizados (OCCTSwift)
- `.claude/commands/` con comandos especializados (audit-occt, ground-truth)
- Integración `.claude/settings.local.json` en múltiples proyectos

---

## 5. Mejoras de UX/Confiabilidad

### Anti-alucinación (R4 unificada):
- 3 patrones prohibidos explícitamente documentados
- Detector Pattern 6: claims cuantitativos sin respaldo
- Detector Pattern 7: afirmaciones absolutas sin fuentes verificables
- "No existe X" → "No encontré X en las fuentes consultadas"

### Autonomía (R8c):
- Whitelist de acciones auto-ejecutables sin pedir permiso
- El agente ya no pregunta "¿procedo?" para lecturas, edits en workspace, git read-only
- Solo pide autorización para acciones destructivas o externas

### Continuidad (R17):
- Actualización de TODO.md y BRAIN.md INMEDIATAMENTE tras cada avance
- No se acumulan cambios para el final de sesión
- Si la sesión muere, el estado es correcto

---

## 6. Lo Que Falta (Gaps Detectados)

1. **COLLAB/** — 40+ archivos de colaboración en el workspace de NanoAtlas (no accesibles desde AppForge Studio)
2. **CHANGELOG de Gotchi core** — no encontrado en este workspace (probablemente en `~/Desktop/NanoAtlas/`)
3. **Herramientas experimentales** — Memory Consolidation (AutoDream), Moltbook (red social de agentes), Tool Creation (tool_create) parecen nuevas pero requieren verificación
4. **Reglas R0-R20** — mapeo completo requiere acceso al prompt del harness, no solo al inyectado en sesión

---

## Conclusión

Gotchi recibió **15+ herramientas nuevas**, **10+ reglas de sistema nuevas**, y una **arquitectura de code_agent con paralelización real** en las últimas semanas. La dirección estratégica es clara: no competir con Claude Code como agente individual, sino construir un **enjambre de agentes especializados** con memoria compartida y CyberNode físico. Las 5 cirugías de la autopsia están en diferentes estados de implementación — la #1 (System Prompt en Capas) ya es visible en la estructura actual de reglas numeradas.
