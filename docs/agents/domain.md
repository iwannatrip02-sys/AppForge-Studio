# Domain docs

Layout: **contexto único**.

- `CONTEXT.md` (raíz) — glosario/lenguaje común + deuda arquitectónica conocida.
- `docs/adr/` — Architecture Decision Records (decisiones difíciles, una por archivo).

Reglas para agentes:
- Lee `CONTEXT.md` antes de codear; usa su vocabulario en código, commits y specs.
- Al tomar una decisión de diseño difícil o no obvia, escribe un ADR nuevo en
  `docs/adr/NNNN-titulo.md`.
- Si un término nuevo aparece en el trabajo, agrégalo al glosario de `CONTEXT.md`.
