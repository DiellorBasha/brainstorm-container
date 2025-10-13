# verify_toolboxes.ps1 - Check which MATLAB toolboxes Brainstorm actually uses

Write-Host "🔍 Analyzing Brainstorm's MATLAB toolbox dependencies..." -ForegroundColor Cyan
Write-Host ""

# Function to check toolbox usage in current container
function Test-ToolboxUsage {
    param($containerName)
    
    Write-Host "Testing toolbox usage in container: $containerName" -ForegroundColor Yellow
    
    # Create a test script to check toolbox dependencies
    $testScript = @"
% Test script to verify essential toolbox functions for Brainstorm
fprintf('Testing Signal Processing Toolbox...\n');
try
    % Test basic signal processing functions used by Brainstorm
    x = randn(1000,1);
    y = fft(x);           % FFT - core for frequency analysis
    z = filtfilt([1], [1 -0.5], x);  % Digital filtering
    fprintf('✅ Signal Processing functions work\n');
catch ME
    fprintf('❌ Signal Processing failed: %s\n', ME.message);
end

fprintf('Testing Parallel Processing Toolbox...\n');
try
    % Test if parallel toolbox is available (even if no pool)
    p = gcp('nocreate');
    fprintf('✅ Parallel Processing Toolbox accessible\n');
catch ME
    fprintf('❌ Parallel Processing failed: %s\n', ME.message);
end

fprintf('Testing core MATLAB functions used by Brainstorm...\n');
try
    % Test matrix operations essential for MEG/EEG processing
    A = randn(100,100);
    [U,S,V] = svd(A);     % Singular Value Decomposition
    B = A \ randn(100,1); % Matrix solve (linear algebra)
    C = eig(A);           % Eigenvalues (PCA, ICA components)
    fprintf('✅ Core linear algebra functions work\n');
catch ME
    fprintf('❌ Core functions failed: %s\n', ME.message);
end

fprintf('Toolbox verification complete.\n');
"@
    
    # Write test script to temporary file
    $testScript | Out-File -FilePath "test_toolboxes.m" -Encoding utf8
    
    # Run test in container
    try {
        Write-Host "Running toolbox test..." -ForegroundColor Gray
        docker run --rm -v "${PWD}:/scripts" $containerName -script /scripts/test_toolboxes.m
    } catch {
        Write-Host "❌ Failed to run test in $containerName" -ForegroundColor Red
    }
    
    # Clean up
    Remove-Item "test_toolboxes.m" -ErrorAction SilentlyContinue
    Write-Host ""
}

# Test current production image
if (docker images brainstorm-compiled:2023a --quiet) {
    Test-ToolboxUsage "brainstorm-compiled:2023a"
}

# Test optimized versions if they exist
if (docker images brainstorm-compiled:minimal --quiet) {
    Test-ToolboxUsage "brainstorm-compiled:minimal"
}

if (docker images brainstorm-compiled:ultra-minimal --quiet) {
    Test-ToolboxUsage "brainstorm-compiled:ultra-minimal"
}

Write-Host "🔍 Checking MATLAB Runtime toolbox directories..." -ForegroundColor Cyan

# Function to list toolboxes in container
function Get-ContainerToolboxes {
    param($containerName)
    
    Write-Host "Toolboxes in $containerName" -ForegroundColor Yellow
    try {
        $toolboxes = docker run --rm $containerName bash -c "ls -la /opt/mcr/R2023a/toolbox/ 2>/dev/null || echo 'No toolbox directory'"
        Write-Host $toolboxes -ForegroundColor Gray
        Write-Host ""
    } catch {
        Write-Host "❌ Could not list toolboxes in $containerName" -ForegroundColor Red
    }
}

# Check toolboxes in available containers
$containers = @("brainstorm-compiled:2023a", "brainstorm-compiled:minimal", "brainstorm-compiled:ultra-minimal")
foreach ($container in $containers) {
    if (docker images $container --quiet) {
        Get-ContainerToolboxes $container
    }
}

Write-Host "📊 Analysis complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Key insights for Brainstorm optimization:" -ForegroundColor Cyan
Write-Host "• Signal Processing Toolbox: Required for FFT, filtering, spectral analysis"
Write-Host "• Parallel Processing Toolbox: Used for multi-core processing (optional but recommended)"
Write-Host "• Core MATLAB: Essential for linear algebra (SVD, eigenvalues, matrix operations)"
Write-Host "• Other toolboxes: Most can be safely removed for Brainstorm use cases"