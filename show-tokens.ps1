# Script detallado para mostrar gasto de tokens por entrada
# Lee los transcripts (.jsonl) que Claude Code guarda en ~/.claude/projects
#
# Uso:
#   .\show-tokens.ps1                                # sesión más reciente de cualquier proyecto
#   .\show-tokens.ps1 -Proyecto C--Users-25863       # sesión más reciente de ese proyecto
#   .\show-tokens.ps1 -Sesion 18dc5a42-2e92-...      # sesión concreta (id o ruta al .jsonl)

param(
    [string]$Proyecto,
    [string]$Sesion
)

$projectsRoot = "$env:USERPROFILE\.claude\projects"

# Si la salida va a otro programa (p. ej. el "!" de Claude Code), se escribe en UTF-8
# para que los acentos no salgan como " ". En una consola normal no hace falta.
if ([Console]::IsOutputRedirected) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
}

# Localiza el transcript
if ($Sesion -and (Test-Path $Sesion -PathType Leaf)) {
    $transcriptFile = Get-Item $Sesion
} else {
    $filter = if ($Sesion) { "$Sesion.jsonl" } else { "*.jsonl" }

    if ($Proyecto) {
        $projectDirs = @(Join-Path $projectsRoot $Proyecto)
        if (-not (Test-Path $projectDirs[0])) {
            Write-Host "No existe el proyecto: $($projectDirs[0])" -ForegroundColor Red
            exit 1
        }
    } else {
        $projectDirs = Get-ChildItem $projectsRoot -Directory -Force | ForEach-Object { $_.FullName }
    }

    # Solo transcripts principales (projects\<proyecto>\<sesion>.jsonl), no los de subagentes
    $transcriptFile = $projectDirs |
        ForEach-Object { Get-ChildItem $_ -Filter $filter -File -Force } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if (-not $transcriptFile) {
    Write-Host "No se encontraron transcripts"
    exit 1
}

Write-Host "=== TOKEN USAGE ANALYSIS ===" -ForegroundColor Yellow
Write-Host "Proyecto: $($transcriptFile.Directory.Name)" -ForegroundColor Gray
Write-Host "Archivo: $($transcriptFile.Name)" -ForegroundColor Gray
Write-Host "Actualizado: $($transcriptFile.LastWriteTime)" -ForegroundColor Gray
Write-Host ""

function Format-Hora($ts) {
    if (-not $ts) { return "" }
    try { ([datetime]$ts).ToString("yyyy-MM-dd HH:mm:ss") } catch { "$ts" }
}

# Precios de la API en $ por millón de tokens: entrada, salida y multiplicador de la lectura de caché.
# Fuente: https://platform.claude.com/docs/en/about-claude/pricing (consultado en $fechaPrecios).
# Escribir en caché cuesta 1,25 veces la entrada (caché de 5 minutos) o 2 veces (caché de 1 hora).
# Al actualizar la tabla, cambia también la fecha: se muestra al final del informe.
$fechaPrecios = "2026-10-27"
$precios = @{
    "claude-fable-5-1"  = @(10, 50, 0.025)
    "claude-mythos-5-1" = @(10, 50, 0.025)
    "claude-fable-5"    = @(10, 50, 0.1)
    "claude-mythos-5"   = @(10, 50, 0.1)
    "claude-opus-5-5"   = @(4, 20, 0.05)
    "claude-opus-5"     = @(5, 25, 0.1)
    "claude-opus-4-8"   = @(5, 25, 0.1)
    "claude-opus-4-7"   = @(5, 25, 0.1)
    "claude-opus-4-6"   = @(5, 25, 0.1)
    "claude-opus-4-5"   = @(5, 25, 0.1)
    "claude-opus-4-1"   = @(15, 75, 0.1)
    "claude-opus-4"     = @(15, 75, 0.1)
    "claude-sonnet-5-5" = @(2, 10, 0.05)
    "claude-sonnet-5"   = @(2, 10, 0.1)
    "claude-sonnet-4-6" = @(3, 15, 0.1)
    "claude-sonnet-4-5" = @(3, 15, 0.1)
    "claude-sonnet-4"   = @(3, 15, 0.1)
    "claude-haiku-5-5"  = @(0.10, 0.50, 0.1)
    "claude-haiku-4-5"  = @(1, 5, 0.1)
    "claude-3-5-haiku"  = @(0.80, 4, 0.1)
}
# Modo rápido (fast mode): sustituye los precios de entrada y salida
$preciosRapido = @{
    "claude-opus-5-5" = @(8, 40)
    "claude-opus-5"   = @(10, 50)
    "claude-opus-4-8" = @(10, 50)
}

# Devuelve el coste en $ de una respuesta, separado por tipo de token, o $null si no se conoce el precio
function Get-Coste($modelo, $u) {
    if (-not $modelo -or -not $u) { return $null }
    $id = $modelo -replace '-\d{8}$', ''   # quita la fecha de ids como claude-haiku-4-5-20251001
    $p = $precios[$id]
    if (-not $p) { return $null }
    $pEntrada, $pSalida, $multLectura = $p
    if ($u.speed -eq "fast" -and $preciosRapido[$id]) { $pEntrada, $pSalida = $preciosRapido[$id] }

    $entrada = [int64]$u.input_tokens
    $escrita = [int64]$u.cache_creation_input_tokens
    $leida = [int64]$u.cache_read_input_tokens

    # Haiku 5.5 cobra 5 veces más si el prompt (incluida la caché) pasa de 100.000 tokens
    if ($id -eq "claude-haiku-5-5" -and ($entrada + $escrita + $leida) -gt 100000) { $pEntrada *= 5; $pSalida *= 5 }

    # Si el transcript separa la caché de 1 hora se usa; si no, todo cuenta como caché de 5 minutos
    $escrita1h = if ($u.cache_creation) { [int64]$u.cache_creation.ephemeral_1h_input_tokens } else { 0 }
    $escrita5m = $escrita - $escrita1h
    $busquedas = if ($u.server_tool_use) { [int64]$u.server_tool_use.web_search_requests } else { 0 }

    [pscustomobject]@{
        Entrada   = $entrada * $pEntrada / 1e6
        Escrita   = ($escrita5m * 1.25 + $escrita1h * 2) * $pEntrada / 1e6
        Leida     = $leida * $pEntrada * $multLectura / 1e6
        Salida    = [int64]$u.output_tokens * $pSalida / 1e6
        Busquedas = $busquedas * 0.01   # 10 $ por cada 1.000 búsquedas web
    }
}

function Format-Dolares($n) { "{0:N4} $" -f $n }

function Get-Preview($texto) {
    if (-not $texto) { return $null }
    # Comandos lanzados con "!" en Claude Code
    if ($texto -match '^\s*<bash-input>(.*?)</bash-input>') { $texto = "! " + $Matches[1] }
    elseif ($texto -match '^\s*<bash-stdout>') { return "(salida del comando)" }
    $t = ($texto -replace '\s+', ' ').Trim()
    if ($t.Length -gt 70) { $t.Substring(0, 70) + "..." } else { $t }
}

# Agrupa las líneas del transcript en mensajes.
# Claude Code escribe una línea por bloque de contenido (texto, thinking, tool_use), todas con
# el mismo message.id y el mismo usage, así que se agrupan por id para no contar varias veces.
$mensajes = [System.Collections.Generic.List[object]]::new()
$porId = @{}
$toolResults = 0

# ReadLines lee en UTF-8 (Get-Content en PowerShell 5.1 estropearía los acentos)
foreach ($raw in [System.IO.File]::ReadLines($transcriptFile.FullName)) {
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    try { $line = $raw | ConvertFrom-Json } catch { continue }   # Ignora líneas que no sean JSON válido

    # Hay otras líneas (resúmenes, snapshots, metadatos) que no son mensajes
    if ($line.type -ne "user" -and $line.type -ne "assistant") { continue }
    if ($line.isMeta) { continue }
    $msg = $line.message
    if (-not $msg) { continue }

    if ($line.type -eq "assistant") {
        $id = if ($msg.id) { $msg.id } else { $line.uuid }
        $entry = $porId[$id]
        if (-not $entry) {
            $entry = [pscustomobject]@{
                Rol          = "assistant"
                Timestamp    = $line.timestamp
                Modelo       = $msg.model
                Texto        = $null
                Herramientas = [System.Collections.Generic.List[string]]::new()
                Usage        = $null
            }
            $porId[$id] = $entry
            $mensajes.Add($entry)
        }
        # Cada línea repite el usage; la última es la definitiva
        if ($msg.usage) { $entry.Usage = $msg.usage }
        foreach ($block in @($msg.content)) {
            if ($block.type -eq "text" -and -not $entry.Texto) { $entry.Texto = $block.text }
            elseif ($block.type -eq "tool_use") { $entry.Herramientas.Add($block.name) }
        }
    } else {
        # Los resultados de herramientas llegan como mensajes "user", pero no son prompts tuyos
        $content = $msg.content
        if ($content -is [string]) {
            $texto = $content
        } else {
            $blocks = @($content)
            if ($blocks | Where-Object { $_.type -eq "tool_result" }) { $toolResults++; continue }
            $texto = ($blocks | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
        }
        $mensajes.Add([pscustomobject]@{
            Rol       = "user"
            Timestamp = $line.timestamp
            Texto     = $texto
        })
    }
}

$totalInput = 0
$totalCacheWrite = 0
$totalCacheRead = 0
$totalOutput = 0
$userCount = 0
$assistantCount = 0
$ultimoContexto = 0
$n = 0
$coste = [pscustomobject]@{ Entrada = 0.0; Escrita = 0.0; Leida = 0.0; Salida = 0.0; Busquedas = 0.0 }
$costePorModelo = [ordered]@{}
$sinPrecio = [ordered]@{}

foreach ($m in $mensajes) {
    $n++
    $hora = Format-Hora $m.Timestamp

    if ($m.Rol -eq "user") {
        $userCount++
        Write-Host "[$n] [USER]" -ForegroundColor Cyan -NoNewline
        if ($hora) { Write-Host " | $hora" -ForegroundColor Gray -NoNewline }
        Write-Host ""
        $preview = Get-Preview $m.Texto
        Write-Host "    $(if ($preview) { $preview } else { '(sin contenido)' })" -ForegroundColor White
        Write-Host ""
        continue
    }

    $assistantCount++
    $u = $m.Usage
    $inputTokens = [int64]$u.input_tokens
    $cacheWrite = [int64]$u.cache_creation_input_tokens
    $cacheRead = [int64]$u.cache_read_input_tokens
    $outputTokens = [int64]$u.output_tokens
    $tokens = $inputTokens + $cacheWrite + $cacheRead + $outputTokens

    $totalInput += $inputTokens
    $totalCacheWrite += $cacheWrite
    $totalCacheRead += $cacheRead
    $totalOutput += $outputTokens
    if ($u) { $ultimoContexto = $inputTokens + $cacheWrite + $cacheRead }

    Write-Host "[$n] [CLAUDE]" -ForegroundColor Green -NoNewline
    if ($hora) { Write-Host " | $hora" -ForegroundColor Gray -NoNewline }
    if ($m.Modelo) { Write-Host " | $($m.Modelo)" -ForegroundColor Gray -NoNewline }
    Write-Host ""

    $preview = Get-Preview $m.Texto
    if ($preview) { Write-Host "    $preview" -ForegroundColor White }
    if ($m.Herramientas.Count -gt 0) {
        Write-Host "    Herramientas: $($m.Herramientas -join ', ')" -ForegroundColor DarkYellow
    }
    if (-not $preview -and $m.Herramientas.Count -eq 0) { Write-Host "    (sin contenido)" -ForegroundColor White }

    Write-Host "    Entrada: $inputTokens | Caché escrita: $cacheWrite | Caché leída: $cacheRead | Salida: $outputTokens | Total: $tokens" -ForegroundColor Gray

    $c = Get-Coste $m.Modelo $u
    if ($c) {
        $costeMensaje = $c.Entrada + $c.Escrita + $c.Leida + $c.Salida + $c.Busquedas
        foreach ($campo in "Entrada", "Escrita", "Leida", "Salida", "Busquedas") { $coste.$campo += $c.$campo }
        $costePorModelo[$m.Modelo] = [double]$costePorModelo[$m.Modelo] + $costeMensaje
        Write-Host "    Coste: $(Format-Dolares $costeMensaje)" -ForegroundColor DarkCyan
    } elseif ($tokens -gt 0) {
        $nombre = if ($m.Modelo) { $m.Modelo } else { "(sin modelo)" }
        $sinPrecio[$nombre] = [int]$sinPrecio[$nombre] + 1
        Write-Host "    Coste: precio desconocido para este modelo" -ForegroundColor DarkCyan
    }
    Write-Host ""
}

$totalTokens = $totalInput + $totalCacheWrite + $totalCacheRead + $totalOutput

Write-Host "================================" -ForegroundColor Yellow
Write-Host "RESUMEN FINAL:" -ForegroundColor Yellow
Write-Host "  Mensajes: $userCount tuyos, $assistantCount respuestas de Claude, $toolResults resultados de herramientas" -ForegroundColor Gray
Write-Host "  Tokens entrada (sin caché): $totalInput" -ForegroundColor Gray
Write-Host "  Tokens escritos en caché:   $totalCacheWrite" -ForegroundColor Gray
Write-Host "  Tokens leídos de caché:     $totalCacheRead" -ForegroundColor Gray
Write-Host "  Tokens salida:              $totalOutput" -ForegroundColor Gray
Write-Host "  TOTAL: $totalTokens tokens" -ForegroundColor Green
Write-Host "  Promedio/respuesta: $([Math]::Round($totalTokens / [Math]::Max(1, $assistantCount), 0)) tokens" -ForegroundColor Green
Write-Host "  Contexto en la última respuesta: $ultimoContexto tokens" -ForegroundColor Green

if ($mensajes.Count -gt 0) {
    Write-Host "  Período: $(Format-Hora $mensajes[0].Timestamp) a $(Format-Hora $mensajes[$mensajes.Count - 1].Timestamp)" -ForegroundColor Gray
}

$costeTotal = $coste.Entrada + $coste.Escrita + $coste.Leida + $coste.Salida + $coste.Busquedas
Write-Host ""
Write-Host "COSTE ESTIMADO (precios de la API del $fechaPrecios):" -ForegroundColor Yellow
Write-Host "  Entrada (sin caché): $(Format-Dolares $coste.Entrada)" -ForegroundColor Gray
Write-Host "  Escritura en caché:  $(Format-Dolares $coste.Escrita)" -ForegroundColor Gray
Write-Host "  Lectura de caché:    $(Format-Dolares $coste.Leida)" -ForegroundColor Gray
Write-Host "  Salida:              $(Format-Dolares $coste.Salida)" -ForegroundColor Gray
if ($coste.Busquedas -gt 0) { Write-Host "  Búsquedas web:       $(Format-Dolares $coste.Busquedas)" -ForegroundColor Gray }
Write-Host "  TOTAL: $(Format-Dolares $costeTotal)" -ForegroundColor Green
if ($costePorModelo.Count -gt 1) {
    Write-Host "  Por modelo:" -ForegroundColor Gray
    foreach ($modelo in $costePorModelo.Keys) { Write-Host "    $($modelo): $(Format-Dolares $costePorModelo[$modelo])" -ForegroundColor Gray }
}
foreach ($modelo in $sinPrecio.Keys) {
    Write-Host "  Sin contar: $($sinPrecio[$modelo]) respuestas de $modelo (precio desconocido)" -ForegroundColor DarkYellow
}
Write-Host "  Con una suscripción (Pro, Max, Team o Enterprise) no pagas esto: es lo que costaría usando la API." -ForegroundColor DarkGray

Write-Host ""
