% tutorial_omega_debug.m - DEBUG version of tutorial_omega with extensive logging
% This is a SCRIPT (not a function) to work with Brainstorm's -script mode

% Set dataset directory (hardcoded for container)
BidsDir = '/data';

fprintf('=== TUTORIAL OMEGA DEBUG ===\n');
fprintf('Dataset directory: %s\n', BidsDir);
fprintf('Current working directory: %s\n', pwd);

% Check Brainstorm status and database
fprintf('\n=== BRAINSTORM STATUS ===\n');
if brainstorm('status')
    fprintf('Brainstorm is running\n');
else
    fprintf('Brainstorm is NOT running, starting...\n');
    brainstorm nogui local
    if brainstorm('status')
        fprintf('Brainstorm started successfully\n');
    else
        error('Failed to start Brainstorm');
    end
end

% Get database info
db_dir = bst_get('BrainstormDbDir');
fprintf('Brainstorm database directory: %s\n', db_dir);

if exist(db_dir, 'dir')
    fprintf('Database directory exists\n');
    db_contents = dir(db_dir);
    fprintf('Database contains %d items:\n', length(db_contents)-2);
    for i = 1:length(db_contents)
        if ~strcmp(db_contents(i).name, '.') && ~strcmp(db_contents(i).name, '..')
            fprintf('  - %s\n', db_contents(i).name);
        end
    end
else
    fprintf('WARNING: Database directory does not exist: %s\n', db_dir);
    fprintf('Creating database directory...\n');
    mkdir(db_dir);
end

% Check dataset
fprintf('\n=== DATASET CHECK ===\n');
if exist(BidsDir, 'dir')
    fprintf('Dataset directory exists: %s\n', BidsDir);
    data_contents = dir(BidsDir);
    fprintf('Dataset contains %d items:\n', length(data_contents)-2);
    for i = 1:min(10, length(data_contents))
        if ~strcmp(data_contents(i).name, '.') && ~strcmp(data_contents(i).name, '..')
            fprintf('  - %s\n', data_contents(i).name);
        end
    end
else
    error('Dataset directory not found: %s', BidsDir);
end

% Protocol creation
fprintf('\n=== PROTOCOL CREATION ===\n');
ProtocolName = 'TutorialOmega';
fprintf('Creating protocol: %s\n', ProtocolName);

% Delete existing protocol
try
    gui_brainstorm('DeleteProtocol', ProtocolName);
    fprintf('Deleted existing protocol (if any)\n');
catch ME
    fprintf('Note: No existing protocol to delete (normal for first run)\n');
end

% Create new protocol
try
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
    fprintf('Protocol created successfully\n');
catch ME
    error('Failed to create protocol: %s', ME.message);
end

% Verify protocol was created
protocols = bst_get('ProtocolsList');
fprintf('Available protocols after creation:\n');
for i = 1:length(protocols)
    fprintf('  - %s\n', protocols(i).Comment);
end

% Check if our protocol is active
current_protocol = bst_get('ProtocolInfo');
if ~isempty(current_protocol)
    fprintf('Current active protocol: %s\n', current_protocol.Comment);
    fprintf('Protocol directory: %s\n', current_protocol.STUDIES);
else
    error('No active protocol found after creation');
end

% Start report
fprintf('\n=== STARTING PROCESSING ===\n');
bst_report('Start');

% BIDS Import
fprintf('Importing BIDS dataset...\n');
try
    sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
        'bidsdir',      {BidsDir, 'BIDS'}, ...
        'nvertices',    15000, ...
        'channelalign', 0);
    
    if isempty(sFilesRaw)
        error('BIDS import returned empty result');
    end
    
    fprintf('BIDS import successful: %d files imported\n', length(sFilesRaw));
    
catch ME
    error('BIDS import failed: %s', ME.message);
end

% Final verification
fprintf('\n=== FINAL VERIFICATION ===\n');
final_db_contents = dir(db_dir);
fprintf('Final database contents:\n');
for i = 1:length(final_db_contents)
    if ~strcmp(final_db_contents(i).name, '.') && ~strcmp(final_db_contents(i).name, '..')
        fprintf('  - %s\n', final_db_contents(i).name);
        
        % If it's our protocol, show its contents
        if strcmp(final_db_contents(i).name, ProtocolName)
            protocol_dir = fullfile(db_dir, ProtocolName);
            protocol_contents = dir(protocol_dir);
            fprintf('    Protocol contents:\n');
            for j = 1:length(protocol_contents)
                if ~strcmp(protocol_contents(j).name, '.') && ~strcmp(protocol_contents(j).name, '..')
                    fprintf('      - %s\n', protocol_contents(j).name);
                end
            end
        end
    end
end

fprintf('\n=== TUTORIAL OMEGA DEBUG COMPLETED ===\n');