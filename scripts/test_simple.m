function test_simple()
% TEST_SIMPLE: Minimal Brainstorm script for container testing
% 
% This is the simplest possible Brainstorm script to verify the container works.
% It just initializes Brainstorm, prints some info, and exits cleanly.
%
% Usage: docker run --rm -v $PWD/scripts:/scripts brainstorm-compiled:2023a -script /scripts/test_simple.m
%
% Author: Generated for brainstorm-container testing
% Date: 2025

fprintf('=== Brainstorm Container Test - Simple Script ===\n');

try
    % Initialize Brainstorm in server mode (no GUI)
    fprintf('Initializing Brainstorm...\n');
    if ~brainstorm('status')
        brainstorm nogui
    end
    
    fprintf('✅ Brainstorm initialized successfully!\n');
    
    % Get and display Brainstorm version info
    bst_ver = bst_get('Version');
    fprintf('📋 Brainstorm version: %s\n', bst_ver.Version);
    fprintf('📅 Release date: %s\n', bst_ver.Date);
    
    % Get MATLAB Runtime info
    fprintf('🔧 MATLAB Runtime: %s\n', version);
    
    % Simple test - create a temporary variable
    test_data = [1, 2, 3, 4, 5];
    fprintf('🧪 Test calculation: sum([1,2,3,4,5]) = %d\n', sum(test_data));
    
    fprintf('✅ All tests passed! Container is working correctly.\n');
    fprintf('=== Test Completed Successfully ===\n');
    
    % Clean exit
    exit(0);
    
catch ME
    fprintf('❌ ERROR during testing:\n');
    fprintf('   Message: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('   File: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    end
    
    % Exit with error code
    exit(1);
end

end