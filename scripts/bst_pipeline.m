function bst_pipeline()
% BST_PIPELINE: Example Brainstorm pipeline script for containerized execution
% 
% This script demonstrates basic Brainstorm scripting patterns following the
% "Generate .m script" tutorial: https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting
%
% Usage: docker run --rm -v $PWD/data:/data -v $PWD/scripts:/scripts \
%               brainstorm-compiled:2023a -script /scripts/bst_pipeline.m
%
% Prerequisites:
% - Brainstorm database must be available in mounted /data directory
% - Follow Brainstorm's Process1/Process2 patterns for pipeline steps
%
% Author: Generated for brainstorm-container project
% Date: 2025

fprintf('=== Brainstorm Container Pipeline Started ===\n');

try
    % Initialize Brainstorm database
    % This follows the standard Brainstorm scripting initialization pattern
    if ~brainstorm('status')
        brainstorm nogui
    end
    
    fprintf('Brainstorm initialized successfully\n');
    
    % Example: List available protocols in the database
    % Replace this section with your actual processing pipeline
    ProtocolInfo = bst_get('ProtocolInfo');
    if ~isempty(ProtocolInfo)
        fprintf('Available protocols:\n');
        for i = 1:length(ProtocolInfo)
            fprintf('  %d: %s\n', i, ProtocolInfo(i).Comment);
        end
    else
        fprintf('No protocols found in database\n');
        fprintf('Ensure your Brainstorm database is properly mounted at /data\n');
    end
    
    % Example processing step - customize based on your needs
    % This is where you would add your actual Brainstorm processing commands
    % following the patterns from "Generate .m script":
    %
    % 1. Select input files
    % 2. Configure process parameters  
    % 3. Run process (Process1/Process2 pattern)
    % 4. Save results
    
    fprintf('Pipeline processing would occur here...\n');
    fprintf('Add your Brainstorm processing commands following the scripting tutorial\n');
    
    fprintf('=== Pipeline Completed Successfully ===\n');
    
catch ME
    fprintf('ERROR in pipeline execution:\n');
    fprintf('  Message: %s\n', ME.message);
    fprintf('  File: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    
    % Exit with error code for container orchestration
    exit(1);
end

% Clean exit
exit(0);

end