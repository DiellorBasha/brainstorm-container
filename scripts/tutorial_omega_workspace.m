% tutorial_omega_workspace.m - Script with custom database in workspace
%
% This version creates the database in /workspace to avoid permission issues

% Dataset path is hardcoded to container mount point
BidsDir = '/data';

% Set custom database location in writable workspace
CustomDbDir = '/workspace/brainstorm_database';

% Verify the dataset directory exists
if ~exist(BidsDir, 'dir')
    error('Dataset directory not found at %s. Please check volume mounting.', BidsDir);
end

fprintf('Using dataset directory: %s\n', BidsDir);
fprintf('Using custom database directory: %s\n', CustomDbDir);

% Create custom database directory
if ~exist(CustomDbDir, 'dir')
    mkdir(CustomDbDir);
    fprintf('Created database directory: %s\n', CustomDbDir);
end

%% ===== START BRAINSTORM WITH CUSTOM DATABASE =====
% Start brainstorm with custom database location
if ~brainstorm('status')
    fprintf('Starting Brainstorm with custom database...\n');
    brainstorm('nogui', 'local', CustomDbDir);
end

% Verify database location
actual_db = bst_get('BrainstormDbDir');
fprintf('Brainstorm database directory: %s\n', actual_db);

%% ===== CREATE PROTOCOL =====
ProtocolName = 'TutorialOmega';
fprintf('Creating protocol: %s\n', ProtocolName);

% Delete existing protocol if any
try
    gui_brainstorm('DeleteProtocol', ProtocolName);
    fprintf('Deleted existing protocol\n');
catch
    fprintf('No existing protocol to delete\n');
end

% Create new protocol
try
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
    fprintf('Protocol created successfully\n');
catch ME
    error('Failed to create protocol: %s', ME.message);
end

% Start a new report
bst_report('Start');

%% ===== IMPORT BIDS DATASET =====
fprintf('Importing BIDS dataset from: %s\n', BidsDir);

% Process: Import BIDS dataset
sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
    'bidsdir',      {BidsDir, 'BIDS'}, ...
    'nvertices',    15000, ...
    'channelalign', 0);

if isempty(sFilesRaw)
    error('Failed to import BIDS dataset. Please check the dataset format.');
end

fprintf('Successfully imported %d raw files\n', length(sFilesRaw));

% List what was created
protocol_info = bst_get('ProtocolInfo');
if ~isempty(protocol_info)
    fprintf('Protocol directory: %s\n', protocol_info.STUDIES);
end

fprintf('Tutorial omega processing completed successfully!\n');

% Stop Brainstorm
brainstorm stop