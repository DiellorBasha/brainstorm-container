% test_minimal.m - Minimal MATLAB script for container testing
% This script doesn't use Brainstorm GUI functions, just basic MATLAB

fprintf('=== Minimal MATLAB Test ===\n');

try
    % Basic MATLAB operations
    fprintf('Testing basic MATLAB functionality...\n');
    
    % Simple math
    result = 2 + 2;
    fprintf('2 + 2 = %d\n', result);
    
    % Array operations
    data = [1, 2, 3, 4, 5];
    total = sum(data);
    fprintf('sum([1,2,3,4,5]) = %d\n', total);
    
    % Display MATLAB version
    fprintf('MATLAB version: %s\n', version);
    
    fprintf('✅ Basic MATLAB test completed successfully!\n');
    
catch ME
    fprintf('❌ ERROR: %s\n', ME.message);
    exit(1);
end

fprintf('=== Test Complete ===\n');