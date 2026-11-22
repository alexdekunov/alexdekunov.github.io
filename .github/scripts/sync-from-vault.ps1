$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$docs = [Environment]::GetFolderPath('MyDocuments')
$projects = Join-Path $docs 'Obsidian\obsidian_dx_2026\01-projects'

$source = Get-ChildItem -LiteralPath $projects -Directory |
  Where-Object {
    (Test-Path -LiteralPath (Join-Path $_.FullName 'index.html')) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName 'blog.css'))
  } |
  Select-Object -First 1

if (-not $source) {
  throw 'Site source folder not found in vault/01-projects'
}

$src = $source.FullName

$dirty = git -C $repo status --porcelain
if ($LASTEXITCODE -ne 0) {
  throw 'Cannot read git status in site repo'
}
if ($dirty) {
  throw 'Site repo has local changes. Commit or discard them before sync.'
}

$rootWeb = Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Extension -in @('.html', '.css') }
$rootNames = @($rootWeb | ForEach-Object { $_.Name })

Get-ChildItem -LiteralPath $repo -File |
  Where-Object { $_.Extension -in @('.html', '.css') -and $rootNames -notcontains $_.Name } |
  Remove-Item -Force

foreach ($file in $rootWeb) {
  Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $repo $file.Name) -Force
}

$srcArticles = Join-Path $src 'articles'
$dstArticles = Join-Path $repo 'articles'
New-Item -ItemType Directory -Force -Path $dstArticles | Out-Null

$articleNames = @()
if (Test-Path -LiteralPath $srcArticles) {
  $articleNames = @(Get-ChildItem -LiteralPath $srcArticles -Filter '*.html' -File | ForEach-Object { $_.Name })
}

if (Test-Path -LiteralPath $dstArticles) {
  Get-ChildItem -LiteralPath $dstArticles -Filter '*.html' -File |
    Where-Object { $articleNames -notcontains $_.Name } |
    Remove-Item -Force
}

foreach ($name in $articleNames) {
  Copy-Item -LiteralPath (Join-Path $srcArticles $name) -Destination (Join-Path $dstArticles $name) -Force
}

git -C $repo add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

$changes = git -C $repo status --porcelain
if (-not $changes) {
  'No changes to publish.'
  'Source: ' + $src
  exit 0
}

$message = 'Sync site from vault ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
git -C $repo -c user.name='dek_home' -c user.email='wresda@gmail.com' commit -m $message
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

git -C $repo push origin HEAD
if ($LASTEXITCODE -ne 0) { throw 'git push failed' }

'Published: ' + ($changes | Measure-Object).Count + ' file(s)'
'Source: ' + $src
'Site: https://alexdekunov.github.io/'
