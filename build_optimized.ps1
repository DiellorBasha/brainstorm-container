# build_optimized.ps1 - Test different Docker optimization strategies

Write-Host "🔧 Building optimized Brainstorm containers..." -ForegroundColor Cyan
$currentSize = docker images brainstorm-compiled:2023a --format "{{.Size}}" | Select-Object -First 1
Write-Host "Current image size: $currentSize" -ForegroundColor Yellow
Write-Host ""

# Check required files
if (-not (Test-Path "MATLAB_Runtime_R2023a_glnxa64.zip") -or -not (Test-Path "brainstorm3_standalone_x86_64.zip")) {
    Write-Host "❌ Required installer files not found!" -ForegroundColor Red
    Write-Host "Please ensure these files are in the current directory:" -ForegroundColor Yellow
    Write-Host "- MATLAB_Runtime_R2023a_glnxa64.zip"
    Write-Host "- brainstorm3_standalone_x86_64.zip"
    exit 1
}

try {
    Write-Host "🏗️  Building multi-stage optimized version..." -ForegroundColor Green
    docker build `
        --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip `
        --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip `
        -f Dockerfile.optimized `
        -t brainstorm-compiled:optimized .

    Write-Host "🧹 Building minimal cleanup version..." -ForegroundColor Green
    docker build `
        --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip `
        --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip `
        -f Dockerfile.minimal `
        -t brainstorm-compiled:minimal .

    Write-Host "⚡ Building ultra-minimal version (Signal + Parallel toolboxes only)..." -ForegroundColor Magenta
    docker build `
        --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip `
        --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip `
        -f Dockerfile.ultra-minimal `
        -t brainstorm-compiled:ultra-minimal .

    Write-Host "🏔️  Building Alpine version (experimental)..." -ForegroundColor Green
    try {
        docker build `
            --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip `
            --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip `
            -f Dockerfile.alpine `
            -t brainstorm-compiled:alpine .
    } catch {
        Write-Host "⚠️  Alpine build failed (expected)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "📊 Size comparison:" -ForegroundColor Cyan
    docker images brainstorm-compiled --format "table {{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | Select-Object -First 5

    Write-Host ""
    Write-Host "🧪 Testing optimized containers..." -ForegroundColor Cyan

    Write-Host "Testing multi-stage optimized version..."
    docker run --rm brainstorm-compiled:optimized --help 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Optimized version works!" -ForegroundColor Green
    } else {
        Write-Host "❌ Optimized version failed" -ForegroundColor Red
    }

    Write-Host "Testing minimal cleanup version..."
    docker run --rm brainstorm-compiled:minimal --help 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Minimal version works!" -ForegroundColor Green
    } else {
        Write-Host "❌ Minimal version failed" -ForegroundColor Red
    }

    Write-Host "Testing ultra-minimal version (Signal + Parallel only)..."
    docker run --rm brainstorm-compiled:ultra-minimal --help 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Ultra-minimal version works!" -ForegroundColor Green
    } else {
        Write-Host "❌ Ultra-minimal version failed" -ForegroundColor Red
    }

    $alpineExists = docker images brainstorm-compiled:alpine --quiet
    if ($alpineExists) {
        Write-Host "Testing Alpine version..."
        docker run --rm brainstorm-compiled:alpine --help 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Alpine version works!" -ForegroundColor Green
        } else {
            Write-Host "❌ Alpine version failed" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "🎯 Recommended next steps:" -ForegroundColor Cyan
    Write-Host "1. Test the optimized versions with your actual Brainstorm scripts"
    Write-Host "2. Choose the smallest working version"
    Write-Host "3. Update your docker-compose.yaml to use the optimized tag"
    Write-Host "4. Push the optimized version to Docker Hub"

} catch {
    Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}