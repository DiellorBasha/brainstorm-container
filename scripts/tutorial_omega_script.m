% tutorial_omega_script.m - Script version (no function) for direct container execution
%
% This is a script version of tutorial_omega that can be called directly
% without parameters from the container.

% Dataset path is hardcoded to container mount point
BidsDir = '/data';

% Verify the dataset directory exists
if ~exist(BidsDir, 'dir')
    error('Dataset directory not found at %s. Please check volume mounting.', BidsDir);
end

fprintf('Using dataset directory: %s\n', BidsDir);

%% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialOmega';

% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui local
end

% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);

% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);

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

%% ===== CONTINUE WITH REST OF TUTORIAL =====
% Add the rest of your tutorial_omega processing steps here
% Copy from your original tutorial_omega.m starting after the BIDS import

fprintf('Tutorial omega processing completed successfully!\n');

% Stop Brainstorm
brainstorm stop