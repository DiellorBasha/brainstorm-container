#!/bin/bash
# build_optimized.sh - Test different Docker optimization strategies

set -e

echo "🔧 Building optimized Brainstorm containers..."
echo "Current image size: $(docker images brainstorm-compiled:2023a --format '{{.Size}}' | head -1)"
echo ""

# Ensure required files exist
if [[ ! -f "MATLAB_Runtime_R2023a_glnxa64.zip" ]] || [[ ! -f "brainstorm3_standalone_x86_64.zip" ]]; then
    echo "❌ Required installer files not found!"
    echo "Please ensure these files are in the current directory:"
    echo "- MATLAB_Runtime_R2023a_glnxa64.zip"
    echo "- brainstorm3_standalone_x86_64.zip"
    exit 1
fi

echo "🏗️  Building multi-stage optimized version..."
docker build \
    --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip \
    --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip \
    -f Dockerfile.optimized \
    -t brainstorm-compiled:optimized .

echo "🧹 Building minimal cleanup version..."
docker build \
    --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip \
    --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip \
    -f Dockerfile.minimal \
    -t brainstorm-compiled:minimal .

echo "🏔️  Building Alpine version (experimental)..."
docker build \
    --build-arg MCR_INSTALLER=MATLAB_Runtime_R2023a_glnxa64.zip \
    --build-arg BST_ARCHIVE=brainstorm3_standalone_x86_64.zip \
    -f Dockerfile.alpine \
    -t brainstorm-compiled:alpine . || echo "⚠️  Alpine build failed (expected)"

echo ""
echo "📊 Size comparison:"
docker images brainstorm-compiled --format "table {{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | head -5

echo ""
echo "🧪 Testing optimized containers..."

echo "Testing multi-stage optimized version..."
docker run --rm brainstorm-compiled:optimized --help > /dev/null && echo "✅ Optimized version works!" || echo "❌ Optimized version failed"

echo "Testing minimal cleanup version..."
docker run --rm brainstorm-compiled:minimal --help > /dev/null && echo "✅ Minimal version works!" || echo "❌ Minimal version failed"

if docker images brainstorm-compiled:alpine >/dev/null 2>&1; then
    echo "Testing Alpine version..."
    docker run --rm brainstorm-compiled:alpine --help > /dev/null && echo "✅ Alpine version works!" || echo "❌ Alpine version failed"
fi

echo ""
echo "🎯 Recommended next steps:"
echo "1. Test the optimized versions with your actual Brainstorm scripts"
echo "2. Choose the smallest working version"
echo "3. Update your docker-compose.yaml to use the optimized tag"
echo "4. Push the optimized version to Docker Hub"