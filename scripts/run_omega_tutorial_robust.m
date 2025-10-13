% run_omega_tutorial_robust.m - More robust wrapper for container execution
%
% This version handles Brainstorm initialization more carefully for containerized environments

function run_omega_tutorial_robust_main()
    % Dataset path inside container (mounted from host)
    BidsDir = '/data';
    
    % Set up Brainstorm database directory in a known writable location
    BrainstormDbDir = '/workspace/brainstorm_db';
    
    % Create database directory if it doesn't exist
    if ~exist(BrainstormDbDir, 'dir')
        mkdir(BrainstormDbDir);
        fprintf('Created Brainstorm database directory: %s\n', BrainstormDbDir);
    end
    
    % Also ensure the user home brainstorm directory exists
    UserBstDir = '/home/brainstorm/.brainstorm';
    if ~exist(UserBstDir, 'dir')
        mkdir(UserBstDir);
    end
    
    % Verify the dataset directory exists and contains expected files
    if ~exist(BidsDir, 'dir')
        error('Dataset directory not found at %s. Please check volume mounting.', BidsDir);
    end
    
    % Check if this looks like a BIDS dataset
    fprintf('Checking dataset at: %s\n', BidsDir);
    dirContents = dir(BidsDir);
    validItems = 0;
    for i = 1:length(dirContents)
        if ~strcmp(dirContents(i).name, '.') && ~strcmp(dirContents(i).name, '..')
            validItems = validItems + 1;
            if validItems <= 10  % Show first 10 items
                fprintf('  - %s\n', dirContents(i).name);
            end
        end
    end
    fprintf('Dataset contains %d valid items\n', validItems);
    
    % Look for typical BIDS files
    bidsFiles = dir(fullfile(BidsDir, '*.json'));
    subDirs = dir(fullfile(BidsDir, 'sub-*'));
    if isempty(bidsFiles) && isempty(subDirs)
        fprintf('Warning: No BIDS .json files or sub-* directories found.\n');
        fprintf('This may not be a proper BIDS dataset structure.\n');
    else
        fprintf('Found %d BIDS .json files and %d subject directories\n', ...
                length(bidsFiles), length(subDirs));
    end
    
    % Set environment variable for Brainstorm database (helps with initialization)
    setenv('BRAINSTORM_DB_DIR', BrainstormDbDir);
    
    fprintf('Initializing Brainstorm in nogui mode...\n');
    
    % Try to start Brainstorm with explicit database path
    try
        % First check if already running
        if brainstorm('status')
            fprintf('Brainstorm already running, stopping first...\n');
            brainstorm stop
            pause(2);
        end
        
        % Start with nogui and local database
        brainstorm('nogui', 'local', BrainstormDbDir);
        fprintf('Brainstorm initialized successfully with database: %s\n', BrainstormDbDir);
        
    catch initError
        fprintf('Error initializing Brainstorm: %s\n', initError.message);
        fprintf('Trying alternative initialization...\n');
        
        % Alternative: try without explicit database path
        try
            brainstorm nogui local
        catch altError
            fprintf('Alternative initialization also failed: %s\n', altError.message);
            error('Could not initialize Brainstorm in any mode');
        end
    end
    
    % Verify Brainstorm is running
    if ~brainstorm('status')
        error('Brainstorm failed to start properly');
    end
    
    fprintf('Brainstorm status: Running\n');
    
    % Call the main tutorial function with the container dataset path
    fprintf('Starting OMEGA tutorial with dataset: %s\n', BidsDir);
    
    try
        tutorial_omega(BidsDir);
        fprintf('Tutorial completed successfully!\n');
        
    catch tutorialError
        fprintf('Error running tutorial: %s\n', tutorialError.message);
        fprintf('Stack trace:\n');
        for i = 1:length(tutorialError.stack)
            fprintf('  %s (line %d) in %s\n', ...
                    tutorialError.stack(i).name, ...
                    tutorialError.stack(i).line, ...
                    tutorialError.stack(i).file);
        end
        
        % Stop Brainstorm before rethrowing
        fprintf('Stopping Brainstorm due to error...\n');
        brainstorm stop
        rethrow(tutorialError);
    end
    
    % Stop Brainstorm cleanly
    fprintf('Stopping Brainstorm...\n');
    brainstorm stop
    fprintf('All operations completed.\n');
end

% Execute the wrapper function
run_omega_tutorial_robust_main();