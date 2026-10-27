# show-tokens

Script de PowerShell que muestra cuántos tokens ha gastado una sesión de Claude Code, mensaje a mensaje.

Lee los registros de conversación que Claude Code guarda en tu equipo (`%USERPROFILE%\.claude\projects`), así que no se conecta a internet ni necesita clave de API.

## Requisitos

- Windows con PowerShell 5.1 o posterior.
- Haber usado Claude Code al menos una vez en ese equipo.

## Uso

Desde la carpeta del repositorio:

```powershell
.\show-tokens.ps1                                   # la sesión más reciente de cualquier proyecto
.\show-tokens.ps1 -Proyecto C--Users-25863-vs-claude # la sesión más reciente de ese proyecto
.\show-tokens.ps1 -Sesion 6faa5c5f-f154-...         # una sesión concreta (id o ruta al .jsonl)
```

El nombre del proyecto es la ruta de la carpeta con los separadores cambiados por guiones. Puedes ver todos los nombres en `%USERPROFILE%\.claude\projects`.

Dentro de Claude Code puedes lanzarlo sin salir de la conversación escribiendo `!` delante:

```
! .\show-tokens.ps1 -Proyecto C--Users-25863-vs-claude
```

Si Windows no te deja ejecutar scripts, lánzalo así:

```powershell
powershell -ExecutionPolicy Bypass -File .\show-tokens.ps1
```

## Qué muestra

Primero, cada mensaje de la sesión en orden:

```
[6] [USER] | 2026-10-27 16:58:59
    vamos a dejar en este codebase solo el ejecutable show-tokens, puedes ...

[7] [CLAUDE] | 2026-10-27 16:59:08 | claude-opus-5-5
    Herramientas: PowerShell
    Entrada: 4 | Caché escrita: 1845 | Caché leída: 58010 | Salida: 793 | Total: 60652
```

- **Entrada**: tokens nuevos que Claude lee sin pasar por la caché.
- **Caché escrita**: tokens que se guardan en caché para reutilizarlos en las siguientes respuestas.
- **Caché leída**: tokens que se reutilizan de la caché. Suelen ser la mayoría y son más baratos.
- **Salida**: tokens que escribe Claude (texto y llamadas a herramientas).

Al final, un resumen:

```
RESUMEN FINAL:
  Mensajes: 2 tuyos, 5 respuestas de Claude, 3 resultados de herramientas
  Tokens entrada (sin caché): 12
  Tokens escritos en caché:   26852
  Tokens leídos de caché:     240960
  Tokens salida:              3132
  TOTAL: 270956 tokens
  Promedio/respuesta: 54191 tokens
  Contexto en la última respuesta: 59859 tokens
  Período: 2026-10-27 16:35:25 a 2026-10-27 16:59:08
```

**Contexto en la última respuesta** indica cuánto ocupa ya la conversación. Si crece mucho, cada respuesta sale más cara; empezar una sesión nueva o usar `/compact` lo reduce.

## Limitaciones

- Solo cuenta la conversación principal. Los subagentes guardan sus propios registros y no se incluyen.
- Muestra tokens, no dinero: el precio depende del modelo y de tu plan.
