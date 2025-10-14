% tutorial_omega_fixed.m - Fixed version with permission handling
%
% This version tries multiple database locations and handles permissions

% Dataset path is hardcoded to container mount point
BidsDir = '/data';

fprintf('=== BRAINSTORM OMEGA PROCESSING ===\n');
fprintf('Dataset directory: %s\n', BidsDir);

% Check current user and permissions
[~, user_info] = system('whoami');
fprintf('Running as user: %s', user_info);

% Try different database locations in order of preference
database_locations = {
    '/workspace/brainstorm_database',    % Mounted workspace (preferred)
    '/tmp/brainstorm_database',          % Temporary directory (fallback)
    '/home/brainstorm/brainstorm_db'     % User home directory (last resort)
};

CustomDbDir = '';
for i = 1:length(database_locations)
    test_dir = database_locations{i};
    fprintf('Testing database location: %s\n', test_dir);
    
    try
        % Test if we can create and write to the directory
        if ~exist(test_dir, 'dir')
            mkdir(test_dir);
        end
        
        % Test write permission
        test_file = fullfile(test_dir, 'test_write.txt');
        fid = fopen(test_file, 'w');
        if fid > 0
            fprintf(fid, 'test');
            fclose(fid);
            delete(test_file);
            CustomDbDir = test_dir;
            fprintf('SUCCESS: Using database directory: %s\n', CustomDbDir);
            break;
        end
    catch ME
        fprintf('FAILED: Cannot use %s - %s\n', test_dir, ME.message);
    end
end

if isempty(CustomDbDir)
    error('Could not find a writable directory for Brainstorm database');
end

% Verify dataset exists
if ~exist(BidsDir, 'dir')
    error('Dataset directory not found at %s', BidsDir);
end

%% ===== START BRAINSTORM =====
if ~brainstorm('status')
    fprintf('Starting Brainstorm with database: %s\n', CustomDbDir);
    brainstorm('nogui', 'local', CustomDbDir);
end

%% ===== CREATE PROTOCOL =====
ProtocolName = 'TutorialOmega';
fprintf('Creating protocol: %s\n', ProtocolName);

try
    gui_brainstorm('DeleteProtocol', ProtocolName);
catch
    % Ignore if protocol doesn't exist
end

gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
bst_report('Start');

%% ===== IMPORT BIDS DATASET =====
fprintf('Importing BIDS dataset from: %s\n', BidsDir);

sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
    'bidsdir', {BidsDir, 'BIDS'}, ...
    'nvertices', 15000, ...
    'channelalign', 0);

if isempty(sFilesRaw)
    error('Failed to import BIDS dataset');
end

fprintf('Successfully imported %d raw files\n', length(sFilesRaw));
fprintf('Results saved to: %s\n', CustomDbDir);

% Stop Brainstorm
brainstorm stop

fprintf('Processing completed! Results in: %s\n', CustomDbDir);