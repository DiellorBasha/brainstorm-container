% run_omega_tutorial.m - Wrapper script to run tutorial_omega with container paths
%
% This wrapper script calls tutorial_omega.m with the correct dataset path
% for the containerized environment. The dataset should be mounted at /data
%
% Usage inside container: 
%   xvfb-run -a brainstorm3.command /opt/mcr/R2023a -script /scripts/run_omega_tutorial.m

function run_omega_tutorial()
    % Dataset path inside container (mounted from host)
    BidsDir = '/data';
    
    % Set up Brainstorm database directory (required for headless operation)
    BrainstormDbDir = '/home/brainstorm/.brainstorm';
    if ~exist(BrainstormDbDir, 'dir')
        mkdir(BrainstormDbDir);
        fprintf('Created Brainstorm database directory: %s\n', BrainstormDbDir);
    end
    
    % Verify the dataset directory exists and contains expected files
    if ~exist(BidsDir, 'dir')
        error('Dataset directory not found at %s. Please check volume mounting.', BidsDir);
    end
    
    % Check if this looks like a BIDS dataset
    fprintf('Checking dataset at: %s\n', BidsDir);
    dirContents = dir(BidsDir);
    fprintf('Dataset contains %d items:\n', length(dirContents));
    for i = 1:min(10, length(dirContents))  % Show first 10 items
        if ~strcmp(dirContents(i).name, '.') && ~strcmp(dirContents(i).name, '..')
            fprintf('  - %s\n', dirContents(i).name);
        end
    end
    
    % Look for typical BIDS files
    bidsFiles = dir(fullfile(BidsDir, '*.json'));
    if isempty(bidsFiles)
        fprintf('Warning: No .json files found. This may not be a proper BIDS dataset.\n');
    else
        fprintf('Found %d BIDS .json files\n', length(bidsFiles));
    end
    
    % Initialize Brainstorm with proper database directory
    fprintf('Initializing Brainstorm...\n');
    
    % Start Brainstorm in nogui mode with local database
    if ~brainstorm('status')
        brainstorm('nogui', 'local', BrainstormDbDir);
    end
    
    % Call the main tutorial function with the container dataset path
    fprintf('Starting OMEGA tutorial with dataset: %s\n', BidsDir);
    try
        tutorial_omega(BidsDir);
        fprintf('Tutorial completed successfully!\n');
    catch ME
        fprintf('Error running tutorial: %s\n', ME.message);
        % Stop Brainstorm before rethrowing
        brainstorm stop
        rethrow(ME);
    end
    
    % Stop Brainstorm cleanly
    fprintf('Stopping Brainstorm...\n');
    brainstorm stop
end

% Execute the wrapper function
run_omega_tutorial();