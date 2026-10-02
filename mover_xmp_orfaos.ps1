# ─────────────────────────────────────────────────────────────────
# mover_xmp_orfaos.ps1  (originalmente: mover xmp orfaos.txt)
#
# Move XMPs órfãos para uma subpasta _xmp dentro de cada pasta.
#
# CONTEXTO:
#   Arquivos XMP são sidecars — ficam ao lado do arquivo de imagem
#   e guardam edições, ratings, metadados do Capture One / Lightroom.
#   Um XMP "órfão" é aquele cujo arquivo de imagem correspondente
#   foi apagado ou movido, deixando o XMP sem par.
#
#   Exemplos de XMP com par:
#     DSC_0001.nef  +  DSC_0001.xmp   → par encontrado, não é órfão
#     DSC_0001.nef  +  DSC_0001.nef.xmp → também reconhecido como par
#
#   Exemplos de XMP órfão:
#     DSC_0001.xmp  (sem DSC_0001.nef, .jpg, .raf etc.) → órfão
#     DSC_0001.nef.xmp (sem DSC_0001.nef) → órfão
#
# O QUE O SCRIPT FAZ:
#   Para cada pasta (recursivamente a partir da pasta atual):
#     1. Lista todos os arquivos não-XMP e indexa seus nomes base
#     2. Para cada XMP, verifica se existe um arquivo com o mesmo nome base
#        — testa tanto "nome.xmp" quanto "nome.ext.xmp" (XMP duplo)
#     3. XMPs sem par são considerados órfãos
#     4. Órfãos são movidos para uma subpasta "_xmp" dentro da mesma pasta
#
# COMO USAR (cole no terminal PowerShell aberto na pasta):
#   1. Edite $DryRun = $true para simular (ver o que seria movido)
#   2. Cole o script e verifique o output
#   3. Se OK, mude para $DryRun = $false e cole novamente
#
# VARIÁVEIS:
#   $Root          pasta raiz (padrão: pasta atual)
#   $OrphansDirName nome da subpasta para onde os órfãos vão (padrão: "_xmp")
#   $DryRun        $true = só mostra | $false = move de verdade
#
# NOTA:
#   O script mostra no máximo os primeiros 10 órfãos por pasta no terminal,
#   mas move TODOS se $DryRun = $false.
# ─────────────────────────────────────────────────────────────────

# ── CONFIGURAÇÃO ──────────────────────────────────────────────────
$Root           = (Get-Location).Path   # pasta atual
$OrphansDirName = "_xmp"                # nome da subpasta de destino
$DryRun         = $true                 # $true = simula | $false = move
# ──────────────────────────────────────────────────────────────────

# Coleta todas as subpastas + a pasta raiz
$dirs  = Get-ChildItem -LiteralPath $Root -Directory -Recurse -Force
$dirs  = @((Get-Item -LiteralPath $Root)) + $dirs

$totalXmp     = 0
$totalOrphans = 0

foreach ($dir in $dirs) {
    # Indexa todos os nomes base de arquivos não-XMP da pasta atual
    # Usa HashSet para busca O(1) — rápido mesmo com muitos arquivos
    $existing = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase   # case-insensitive
    )

    Get-ChildItem -LiteralPath $dir.FullName -File -Force |
        Where-Object { $_.Extension -ne ".xmp" } |
        ForEach-Object { [void]$existing.Add($_.BaseName) }

    # Lista todos os XMPs da pasta
    $xmpFiles = Get-ChildItem -LiteralPath $dir.FullName -Filter *.xmp -File -Force
    if ($xmpFiles.Count -eq 0) { continue }

    $totalXmp += $xmpFiles.Count
    $orphans   = @()

    foreach ($xmp in $xmpFiles) {
        $b1 = $xmp.BaseName                                          # ex: DSC_0001
        $b2 = [System.IO.Path]::GetFileNameWithoutExtension($b1)    # ex: DSC_0001 (de DSC_0001.nef.xmp)

        # É órfão se não existe nenhum arquivo com o nome base $b1 nem $b2
        if (-not ($existing.Contains($b1) -or $existing.Contains($b2))) {
            $orphans += $xmp
        }
    }

    if ($orphans.Count -gt 0) {
        $totalOrphans += $orphans.Count

        # Mostra resumo da pasta (primeiros 10 órfãos no terminal)
        "{0} -> orfãos: {1}" -f $dir.FullName, $orphans.Count
        $orphans | Select-Object -First 10 -ExpandProperty Name

        if (-not $DryRun) {
            # Cria subpasta _xmp se não existir
            $orphDir = Join-Path $dir.FullName $OrphansDirName
            if (-not (Test-Path -LiteralPath $orphDir)) {
                New-Item -Path $orphDir -ItemType Directory | Out-Null
            }

            # Move todos os órfãos para _xmp
            $orphans | ForEach-Object {
                Move-Item -LiteralPath $_.FullName -Destination $orphDir -Force
            }
        }
    }
}

# Resumo final
"TOTAL XMP: {0} | TOTAL orfãos: {1}" -f $totalXmp, $totalOrphans

if ($DryRun) {
    "Dry run ligado: nada foi movido. Mude `$DryRun = `$false para mover."
}
