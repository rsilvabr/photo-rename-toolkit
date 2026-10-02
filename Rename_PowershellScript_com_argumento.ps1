# ─────────────────────────────────────────────────────────────────
# Rename_PowershellScript_com_argumento.ps1
#
# Renomeia arquivos de foto (JPG, NEF, RAF, XMP) sequencialmente
# com um prefixo, preservando grupos (arquivos do mesmo disparo).
#
# Contexto de uso: quando você tem fotos com nomes originais da câmera
# (DSC_0001, _DSF0007, etc.) e quer renomear em sequência limpa
# mantendo RAW + JPEG + XMP do mesmo disparo com o mesmo número.
#
# Pré-requisitos: nenhum além do PowerShell (funciona no Windows
# PowerShell 5.1 e no PowerShell 7+).
#
# Como usar (versão .ps1):
#   # Simula na pasta atual com prefixo DSC_
#   powershell -File .\Rename_PowershellScript_com_argumento.ps1
#
#   # Simula em pasta específica, prefixo personalizado, começando do 42
#   powershell -File .\Rename_PowershellScript_com_argumento.ps1 -folder "F:\2024\Sessao" -prefix "IMG_" -startNum 42
#
# Parâmetros:
#   -folder    pasta de entrada (padrão: "." = pasta atual)
#   -prefix    prefixo dos nomes novos (padrão: "DSC_")
#   -startNum  número inicial da sequência (padrão: 1 → DSC_0001)
#   -dryRun    $true (padrão) = simula primeiro e depois oferece o real
#              $false = vai direto para o modo real (com confirmação)
#
# Variáveis internas (edite no topo do script se necessário):
#   $adobeRGB_autoname se $true, arquivos que começam com "_" mantêm o "_"
#                      no novo nome (convenção AdobeRGB do Capture One:
#                      _DSC_0001.jpg = versão AdobeRGB do mesmo disparo)
#
# O que o script faz:
#   - Coleta JPG, NEF, RAF e XMP da pasta (não recursivo)
#   - Agrupa arquivos pelo nome base (sem extensão) — ex: DSC_0007.nef
#     e DSC_0007.jpg ficam no mesmo grupo
#   - Ordena grupos por data de modificação
#   - Renomeia cada grupo sequencialmente: DSC_0001, DSC_0002, etc.
#   - Arquivos XMP acompanham o grupo mas são marcados como [XMP] no log
#   - Move os arquivos renomeados para uma subpasta "renamed/"
#   - Gera log em moveLog.txt na pasta de origem
#
# Segurança:
#   - Sempre simula primeiro (dry-run) e mostra o que faria
#   - Só executa de verdade após você digitar 'y' E a data de hoje
#   - Conflito de destino (arquivo já existe) → pula e loga como CONFLICT
#
# NOTA TÉCNICA (por que mudou em relação à versão anterior):
#   A versão antiga se re-executava como um NOVO processo
#   (powershell -File ... -dryRun $false) para fazer a passagem real.
#   Passar um valor [bool] entre processos pela linha de comando é
#   problemático: via "-File" o argumento chega como texto, e o
#   Windows PowerShell 5.1 recusava converter "False"/"0" em booleano
#   ("Não é possível converter System.String em System.Boolean").
#   Esta versão NÃO reabre processo nenhum: a lógica virou a função
#   Invoke-RenamePass, chamada duas vezes na MESMA sessão (simulação
#   e depois real). Dentro da sessão, $true/$false são booleanos de
#   verdade — o erro deixa de existir por construção.
# ─────────────────────────────────────────────────────────────────

param(
    [string]$folder   = ".",
    [string]$prefix   = "DSC_",
    [int]   $startNum = 1,        # número inicial da sequência (1 → DSC_0001)
    [bool]  $dryRun   = $true
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── CONFIGURAÇÃO INTERNA ──────────────────────────────────────────
$adobeRGB_autoname = $true
# Se $true: arquivos com nome começando em "_" (ex: _DSC_0007.jpg)
# recebem "_" no novo nome também (_DSC_0001.jpg).
# Isso preserva a convenção do Capture One onde _ indica AdobeRGB.
# ──────────────────────────────────────────────────────────────────


# ══════════════════════════════════════════════════════════════════
#  FUNÇÃO: executa UMA passagem completa (simulação OU real)
#  Recebe $DryRun como booleano de verdade — sem ambiguidade de tipo.
# ══════════════════════════════════════════════════════════════════
function Invoke-RenamePass {
    param(
        [Parameter(Mandatory=$true)][string]$Folder,
        [Parameter(Mandatory=$true)][string]$Prefix,
        [Parameter(Mandatory=$true)][int]   $StartNum,
        [Parameter(Mandatory=$true)][bool]  $DryRun,
        [bool]$AdobeRGBAutoname = $true
    )

    $sourceDir = Resolve-Path $Folder
    $destDir   = Join-Path $sourceDir "renamed"   # subpasta de destino
    $logPath   = Join-Path $sourceDir "moveLog.txt"

    # Cria pasta de destino se não existir
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }

    $modo = if ($DryRun) { "SIMULACAO (dry-run)" } else { "REAL" }
    "`r`n===== NOVA PASSAGEM [$modo]: $(Get-Date) (inicio em $StartNum) =====`r`n" | Add-Content -Path $logPath -Encoding utf8

    # Coleta JPG, NEF, RAF, XMP — ordenados por data de modificação
    $files = Get-ChildItem -Path $sourceDir -File | Where-Object {
        $_.Extension -match '\.(jpg|nef|raf|xmp)$'
    } | Sort-Object LastWriteTime

    # Agrupa por nome base (sem extensão)
    # Ex: DSC_0007.nef + DSC_0007.jpg + DSC_0007.xmp → mesmo grupo "DSC_0007"
    $groups = @{}
    foreach ($file in $files) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if (-not $groups.ContainsKey($base)) { $groups[$base] = @() }
        $groups[$base] += $file
    }

    $filesCount  = $files.Count
    $groupsCount = $groups.Count
    "Arquivos encontrados: $filesCount"               | Tee-Object -FilePath $logPath -Append
    "Grupos (nomes base) encontrados: $groupsCount`n" | Tee-Object -FilePath $logPath -Append

    # Ordena os grupos pela data mais antiga do grupo
    # (garante que a ordem de renomeação siga a ordem cronológica dos disparos)
    $orderedGroups = $groups.GetEnumerator() | ForEach-Object {
        $minDate = ($_.Value | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime
        [PSCustomObject]@{
            BaseName = $_.Key
            Files    = $_.Value
            MinDate  = $minDate
        }
    } | Sort-Object MinDate

    $counter = $StartNum

    foreach ($group in $orderedGroups) {
        # Pula grupos que só têm XMP (sem foto real correspondente)
        $hasRealFile = $group.Files | Where-Object { $_.Extension -notmatch "\.xmp" }
        if (-not $hasRealFile) { continue }

        # Formata o número com zeros à esquerda: 1 → 0001
        $newName = "{0}{1:D4}" -f $Prefix, $counter

        foreach ($file in $group.Files) {
            $ext        = $file.Extension
            $sourcePath = $file.FullName

            # Preserva o "_" para arquivos AdobeRGB (se $AdobeRGBAutoname=$true)
            if ($AdobeRGBAutoname -and $file.Name.StartsWith('_')) {
                $fileNewName = "_" + $newName   # ex: _DSC_0001
            } else {
                $fileNewName = $newName          # ex: DSC_0001
            }

            $newFilename = "$fileNewName$ext"
            $destPath    = Join-Path $destDir $newFilename
            $typeNote    = if ($ext -ieq ".xmp") { " [XMP]" } else { "" }

            if ($DryRun) {
                # Simulação: só mostra o que SERIA feito (nada é movido)
                $logEntry = "[SIM]  $sourcePath -> $destPath$typeNote"
            } else {
                # Execução real
                if (Test-Path $destPath) {
                    # Conflito: arquivo de destino já existe — pula
                    $logEntry = "!!! CONFLICT: Destination file already exists -> $destPath. Skipping."
                } else {
                    try {
                        Move-Item -Path $sourcePath -Destination $destPath -ErrorAction Stop
                        $logEntry = "Moved: $sourcePath -> $destPath$typeNote"
                    } catch {
                        $logEntry = "ERROR moving: $sourcePath -> $destPath :: $_"
                    }
                }
            }

            Write-Host $logEntry
            $logEntry | Add-Content -Path $logPath -Encoding utf8
        }

        $counter++
    }

    "`r`nPassagem concluida em $(Get-Date)`r`n" | Add-Content -Path $logPath -Encoding utf8
}


# ══════════════════════════════════════════════════════════════════
#  FLUXO PRINCIPAL
# ══════════════════════════════════════════════════════════════════

# Caso 1: chamada manual com -dryRun $false → vai direto ao real (confirmado)
if (-not $dryRun) {
    Write-Host "`nAVISO: O modo 'dryRun' esta DESATIVADO. Os arquivos serao realmente movidos e renomeados!"
    $confirmation = Read-Host "Digite 'y' para confirmar, 'n' para cancelar, qualquer outra tecla para rodar em modo simulacao"

    if ($confirmation -eq 'y') {
        Write-Host "Confirmado: operacao real sera executada."
        Invoke-RenamePass -Folder $folder -Prefix $prefix -StartNum $startNum -DryRun $false -AdobeRGBAutoname $adobeRGB_autoname
    } elseif ($confirmation -eq 'n') {
        Write-Host "Operacao cancelada pelo usuario."
    } else {
        Write-Host "Rodando apenas em modo simulacao. Nenhum arquivo sera movido."
        Invoke-RenamePass -Folder $folder -Prefix $prefix -StartNum $startNum -DryRun $true -AdobeRGBAutoname $adobeRGB_autoname
    }
    exit
}

# Caso 2 (padrão): simula primeiro, depois oferece o real com dupla confirmação
Write-Host "`n--- SIMULACAO: mostrando o que seria feito (nenhum arquivo sera movido) ---`n"
Invoke-RenamePass -Folder $folder -Prefix $prefix -StartNum $startNum -DryRun $true -AdobeRGBAutoname $adobeRGB_autoname

$response = Read-Host "`r`n`r`nDeseja agora executar de verdade? Digite 'y' para sim, qualquer outra tecla para cancelar"
if ($response -eq 'y') {
    $today   = Get-Date -Format "yyyyMMdd"
    $confirm = Read-Host "Digite a data de hoje ($today) para confirmar"
    if ($confirm -eq $today) {
        Write-Host "`nConfirmado. Executando em modo REAL na mesma sessao (sem reabrir processo)...`n"
        # ── A CORREÇÃO ESTÁ AQUI ──
        # Chamada de função na MESMA sessão. $false é booleano de verdade;
        # não há serialização para string, então o erro de conversão
        # [bool] que acontecia na re-invocação por processo não ocorre.
        Invoke-RenamePass -Folder $folder -Prefix $prefix -StartNum $startNum -DryRun $false -AdobeRGBAutoname $adobeRGB_autoname
        Write-Host "`nRenomeacao real concluida. Veja o log em moveLog.txt.`n"
    } else {
        Write-Host "Data incorreta. Operacao cancelada."
    }
} else {
    Write-Host "Operacao cancelada."
}
