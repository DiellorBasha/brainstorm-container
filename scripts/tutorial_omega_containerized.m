function tutorial_omega_containerized_main()
% TUTORIAL_OMEGA_CONTAINERIZED: Modified version for container execution
% 
% This version automatically uses /data as the dataset path, eliminating
% the need for function parameters when called from container scripts.
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega

% Automatically set BidsDir to the container mount point
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
% Process: Import BIDS dataset
sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
    'bidsdir',      {BidsDir, 'BIDS'}, ...
    'nvertices',    15000, ...
    'channelalign', 0);

% Continue with the rest of your tutorial_omega.m code here...
% (Copy the remaining content from your original tutorial_omega.m)

fprintf('Tutorial completed successfully!\n');
end

% Execute the function automatically when script is called
tutorial_omega_containerized_main();