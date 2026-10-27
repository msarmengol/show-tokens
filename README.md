# show-tokens

Script de PowerShell que muestra cuántos tokens ha gastado una sesión de Claude Code, mensaje a mensaje, y cuánto costaría con los precios de la API.

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
    Coste: 0,0422 $
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

Y después, el coste estimado:

```
COSTE ESTIMADO (precios de la API del 2026-10-27):
  Entrada (sin caché): 0,0001 $
  Escritura en caché:  0,3650 $
  Lectura de caché:    0,4549 $
  Salida:              0,4489 $
  TOTAL: 1,2689 $
  Por modelo:
    claude-sonnet-5: 0,1396 $
    claude-opus-5: 1,1294 $
```

El desglose por modelo solo aparece si en la sesión has usado más de uno.

## Cómo se calcula el coste

Cada respuesta se cobra según el modelo que la generó, con los precios de la API de Anthropic en dólares por millón de tokens. La tabla está al principio del script y se consultó el 27 de octubre de 2026 en la [página oficial de precios](https://platform.claude.com/docs/en/about-claude/pricing).

- **Escribir en caché** cuesta 1,25 veces el precio de entrada si la caché dura 5 minutos y 2 veces si dura 1 hora. El script lo distingue con los datos del transcript.
- **Leer de caché** cuesta una fracción del precio de entrada: 0,025 veces en Fable 5.1, 0,05 en Opus 5.5 y Sonnet 5.5, y 0,1 en el resto.
- **El modo rápido** de Opus usa sus propios precios. **Haiku 5.5** cobra cinco veces más cuando el prompt pasa de 100.000 tokens.
- **Las búsquedas web** se suman a 10 $ cada 1.000.

**Si usas Claude Code con una suscripción (Pro, Max, Team o Enterprise), no pagas esta cantidad.** Es lo que costaría la misma sesión pagando por uso con la API. Sirve para comparar sesiones y ver qué es lo que más gasta.

## Limitaciones

- Solo cuenta la conversación principal. Los subagentes guardan sus propios registros y no se incluyen.
- Los precios están escritos en el script y no se descargan al ejecutarlo, así que funciona sin internet. La fecha de la cabecera «COSTE ESTIMADO» indica de cuándo son. Si Anthropic los cambia o sale un modelo nuevo, hay que actualizar la tabla y la variable `$fechaPrecios` del script (o pedírselo a Claude Code). Las respuestas de un modelo que no está en la tabla aparecen como «precio desconocido» y no se suman.
- No tiene en cuenta los recargos por elegir dónde se procesan los datos (por ejemplo, solo en EE. UU.) ni los precios de Bedrock o Vertex AI.
