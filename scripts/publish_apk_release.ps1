param(
  [int]$BuildNumber = 4,
  [string]$VersionLabel = "2.2.0"
)

$ErrorActionPreference = "Stop"

# Extrai o token da URL do remote local (sem expor em arquivos versionados)
$remoteUrl = (git remote get-url origin).Trim()
if ($remoteUrl -match "https://[^:]+:([^@]+)@github\.com") {
  $token = $Matches[1]
} else {
  throw "Token nao encontrado na URL do remote origin."
}

$headers = @{
  "Authorization" = "Bearer $token"
  "Accept" = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}

$tagName = "v$VersionLabel-b$BuildNumber"
$releaseName = "v$VersionLabel (Build $BuildNumber)"

# Remove release/tag anterior se ja existir com o mesmo tag_name
try {
  $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/bellaludocess-maker/bellalu-apk/releases/tags/$tagName" -Method Get -Headers $headers
  if ($existing.id) {
    Invoke-RestMethod -Uri "https://api.github.com/repos/bellaludocess-maker/bellalu-apk/releases/$($existing.id)" -Method Delete -Headers $headers | Out-Null
  }
} catch {}

$releaseBody = @{
  tag_name = $tagName
  name = $releaseName
  body = "Atualizacao automatica do Painel Administrativo Bella Lu Doces ($releaseName)."
  draft = $false
  prerelease = $false
} | ConvertTo-Json

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/bellaludocess-maker/bellalu-apk/releases" -Method Post -Headers $headers -Body $releaseBody -ContentType "application/json"

$uploadUrl = $release.upload_url -replace "\{\?name,label\}", "?name=BellaLu_Painel_Admin.apk"
$apkPath = Join-Path (Get-Location) "BellaLu_Painel_Admin.apk"

$uploadHeaders = @{
  "Authorization" = "Bearer $token"
  "Accept" = "application/vnd.github+json"
  "Content-Type" = "application/vnd.android.package-archive"
}

$asset = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -InFile $apkPath
Write-Output "APK publicado com sucesso em: $($asset.browser_download_url)"
