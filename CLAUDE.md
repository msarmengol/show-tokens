# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este repo

`show-tokens.ps1`: un script de PowerShell que muestra el gasto de tokens de una sesión de Claude Code leyendo los transcripts `.jsonl` de `%USERPROFILE%\.claude\projects`. Quien lo usa está empezando: explica los pasos en lenguaje sencillo y responde en español.

No hay build, dependencias ni tests. Para probarlo, ejecútalo: `.\show-tokens.ps1 -Proyecto C--Users-25863-vs-claude`.

Remoto: `https://github.com/msarmengol/show-tokens` (público, rama `main`).

## Convenciones del script

- Debe funcionar en Windows PowerShell 5.1. Guarda el archivo en UTF-8 **con BOM**; sin él, 5.1 estropea los acentos.
- Lee el transcript con `[System.IO.File]::ReadLines` (UTF-8), no con `Get-Content`.
- Claude Code escribe una línea por bloque de contenido, todas con el mismo `message.id` y el mismo `usage`. Agrupa por id para no contar los tokens varias veces.
- Los `tool_result` llegan como mensajes `user`: se cuentan aparte, no como prompts.
- Mensajes y comentarios en español.
