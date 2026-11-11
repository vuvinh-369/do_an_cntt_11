# ASCII-compatible with Windows PowerShell 5.1.
param(
    [string]$Python = 'D:\Models\medgemma-env\Scripts\python.exe',
    [switch]$Lan,
    [switch]$NoPreload,
    [int]$Port = 8080,
    [string]$TlsCert,
    [string]$TlsKey
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Python)) {
    $venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $venvPython) {
        $Python = $venvPython
    } else {
        throw 'Chon Python co thu vien AI bang -Python.'
    }
}
$serverArguments = @('-X','utf8','-B',(Join-Path $PSScriptRoot 'backend\run_local_server.py'),'--port',"$Port")
if ($Lan) { $serverArguments += '--lan' }
if ($NoPreload) { $serverArguments += '--no-preload' }
if ([bool]$TlsCert -ne [bool]$TlsKey) { throw 'Can cung cap ca -TlsCert va -TlsKey.' }
if ($TlsCert) { $serverArguments += @('--tls-cert', $TlsCert, '--tls-key', $TlsKey) }
& $Python @serverArguments
if ($LASTEXITCODE -ne 0) { throw 'Server da dung do loi. Xem thong bao phia tren.' }
