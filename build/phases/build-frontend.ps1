#Requires -Version 5.1
<#
.SYNOPSIS
Phase: build-frontend - installs deps, runs Vite build, copies dist to electron/renderer.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host '==== build-frontend phase ===='

$root        = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontendDir = Join-Path $root 'frontend'
$distDir     = Join-Path $frontendDir 'dist'
$rendererDir = Join-Path $root 'electron\renderer'

# Explicit Node.js installation used by Jenkins
$nodeDir = 'C:\Program Files\nodejs'
$npm     = Join-Path $nodeDir 'npm.cmd'
$node    = Join-Path $nodeDir 'node.exe'

Write-Host "Frontend  : $frontendDir"
Write-Host "Dist      : $distDir"
Write-Host "Renderer  : $rendererDir"
Write-Host "Node      : $node"
Write-Host "NPM       : $npm"

# Verify Node/npm
if (-not (Test-Path $node)) {
    throw "Node.js not found: $node"
}

if (-not (Test-Path $npm)) {
    throw "npm not found: $npm"
}

Write-Host "Node version:"
& $node --version

Write-Host "NPM version:"
& $npm --version

# Make Node/npm available to anything called from this script
$env:Path = "$nodeDir;$env:Path"

$lockfile = Join-Path $frontendDir 'package-lock.json'

Push-Location $frontendDir

try {

    # Install dependencies
    if (Test-Path $lockfile) {
        Write-Host 'Running   : npm ci (lockfile found)'
        & $npm ci
    }
    else {
        Write-Host 'Running   : npm install (no lockfile)'
        & $npm install
    }

    if ($LASTEXITCODE -ne 0) {
        throw "build-frontend: npm install/ci exited with code $LASTEXITCODE"
    }

    # Build frontend
    Write-Host 'Running   : npm run build'
    & $npm run build

    if ($LASTEXITCODE -ne 0) {
        throw "build-frontend: npm run build exited with code $LASTEXITCODE"
    }

}
finally {
    Pop-Location
}

# Verify dist was created
if (-not (Test-Path $distDir)) {
    throw "Frontend build failed: dist directory was not created: $distDir"
}

# Copy dist -> electron/renderer
if (Test-Path $rendererDir) {
    Write-Host "Removing existing renderer dir: $rendererDir"
    Remove-Item -Recurse -Force $rendererDir
}

Write-Host "Copying dist -> renderer"
Copy-Item -Recurse $distDir $rendererDir

Write-Host '==== build-frontend DONE ===='