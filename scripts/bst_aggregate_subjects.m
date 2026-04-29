function bst_aggregate_subjects(ZipDir, ProtocolName, varargin)
% BST_AGGREGATE_SUBJECTS  Combine per-subject protocol exports into a group protocol.
%
% Usage:
%   bst_aggregate_subjects(ZipDir, ProtocolName)
%   bst_aggregate_subjects(ZipDir, ProtocolName, 'Key', Value, ...)
%
% Required arguments:
%   ZipDir       - Directory containing per-subject .zip exports
%                  (e.g., sub-0002_brainstorm.zip, sub-0003_brainstorm.zip)
%   ProtocolName - Name for the group protocol to create
%
% Optional key-value pairs:
%   'BstDir'     - Path to brainstorm3 source tree (default: auto-detect)
%   'BstDbDir'   - Path for protocol database (default: ~/brainstorm_db)
%   'OutputZip'  - If set, export final group protocol to this .zip path
%
% This function:
%   1. Starts Brainstorm in server mode
%   2. Creates an empty group protocol
%   3. Uses import_subject() to load each per-subject .zip into the protocol
%      (import_subject extracts anat/<subject> and data/<subject> folders)
%   4. Reloads the database for consistency
%   5. Optionally exports the final group protocol as a .zip
%
% The per-subject .zip files must come from bst_single_subject.m's
% export_protocol() output. They contain:
%   anat/@default_subject/  (ICBM152 defaults — same across subjects)
%   anat/sub-XXXX/          (individual FreeSurfer anatomy)
%   data/@default_study/    (protocol-level default study)
%   data/@inter/            (inter-subject analysis folder)
%   data/sub-XXXX/          (subject recordings, results, source maps)
%   data/protocol.mat       (protocol metadata)
%
% import_subject() skips @default_subject, copies only the real subject
% folders, and checks that UseDefaultAnat == 0 (individual anatomy).
%
% Examples:
%   % Aggregate all subjects from a derivatives directory
%   bst_aggregate_subjects('/scratch/omega/derivatives/brainstorm-timefreq', 'OMEGA_Group')
%
%   % Aggregate with custom paths and export
%   bst_aggregate_subjects('/scratch/results', 'OMEGA_Group', ...
%       'BstDir', '~/workspace/software/brainstorm3', ...
%       'BstDbDir', '/scratch/brainstorm_db', ...
%       'OutputZip', '/scratch/OMEGA_Group.zip')
%
% Authors: Diellor Basha, 2026

%% ===== Parse inputs =====
p = inputParser;
addRequired(p, 'ZipDir', @ischar);
addRequired(p, 'ProtocolName', @ischar);
addParameter(p, 'BstDir', '', @ischar);
addParameter(p, 'BstDbDir', '', @ischar);
addParameter(p, 'OutputZip', '', @ischar);
parse(p, ZipDir, ProtocolName, varargin{:});
opts = p.Results;

% Expand tilde in paths
ZipDir = expand_tilde(ZipDir);
ProtocolName = opts.ProtocolName;
if ~isempty(opts.BstDir)
    opts.BstDir = expand_tilde(opts.BstDir);
end
if ~isempty(opts.BstDbDir)
    opts.BstDbDir = expand_tilde(opts.BstDbDir);
end
if ~isempty(opts.OutputZip)
    opts.OutputZip = expand_tilde(opts.OutputZip);
end

%% ===== Find .zip files =====
zipFiles = dir(fullfile(ZipDir, '**', '*_brainstorm.zip'));
if isempty(zipFiles)
    % Also check for .zip files without the _brainstorm suffix
    zipFiles = dir(fullfile(ZipDir, '**', 'sub-*_brainstorm.zip'));
end
if isempty(zipFiles)
    error('No per-subject .zip files found in: %s', ZipDir);
end
fprintf('Found %d subject .zip files in %s\n', length(zipFiles), ZipDir);

%% ===== Start Brainstorm =====
% Add Brainstorm to path (skip in compiled mode — toolbox is in CTF)
if ~isempty(opts.BstDir)
    if ~isdeployed
        addpath(opts.BstDir);
    else
        fprintf('Compiled mode — skipping addpath. BstDir: %s\n', opts.BstDir);
    end
else
    % Try to auto-detect from current path
    if exist('brainstorm', 'file') ~= 2
        error('Brainstorm not on path. Provide ''BstDir'' argument.');
    end
end

% Set database directory
if ~isempty(opts.BstDbDir)
    BstDbDir = opts.BstDbDir;
else
    BstDbDir = fullfile(expand_tilde('~'), 'brainstorm_db');
end
if ~exist(BstDbDir, 'dir')
    mkdir(BstDbDir);
end

% Configure Brainstorm for headless operation
BrainstormHomeDir = expand_tilde('~/.brainstorm');
if ~exist(BrainstormHomeDir, 'dir')
    mkdir(BrainstormHomeDir);
end
configFile = fullfile(BrainstormHomeDir, 'brainstorm.mat');
if ~exist(configFile, 'file')
    BrainStormSetup.BrainStormDbDir = BstDbDir;
    BrainStormSetup.isLearn = 0;
    save(configFile, '-struct', 'BrainStormSetup');
end

% Start Brainstorm in server mode
brainstorm server;

% Ensure the database directory is set
bst_set('BrainstormDbDir', BstDbDir);

%% ===== Create group protocol =====
fprintf('\n=== Creating group protocol: %s ===\n', ProtocolName);

% Check if protocol already exists
iExisting = bst_get('Protocol', ProtocolName);
if ~isempty(iExisting)
    fprintf('Protocol "%s" already exists — switching to it.\n', ProtocolName);
    gui_brainstorm('SetCurrentProtocol', iExisting);
else
    % Create new protocol (UseDefaultAnat=0, UseDefaultChannel=0)
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
end

%% ===== Import subjects =====
fprintf('\n=== Importing %d subjects ===\n', length(zipFiles));
nSuccess = 0;
nFailed = 0;

for i = 1:length(zipFiles)
    zipPath = fullfile(zipFiles(i).folder, zipFiles(i).name);
    fprintf('\n--- [%d/%d] Importing: %s ---\n', i, length(zipFiles), zipFiles(i).name);

    try
        import_subject(zipPath);
        nSuccess = nSuccess + 1;
        fprintf('  OK\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('  FAILED: %s\n', e.message);
    end
end

fprintf('\n=== Import complete: %d success, %d failed ===\n', nSuccess, nFailed);

%% ===== Verify protocol =====
% List all subjects in the protocol
sProtocolSubjects = bst_get('ProtocolSubjects');
nSubjects = length(sProtocolSubjects.Subject);
fprintf('Protocol "%s" now contains %d subjects:\n', ProtocolName, nSubjects);
for i = 1:nSubjects
    fprintf('  %s\n', sProtocolSubjects.Subject(i).Name);
end

%% ===== Optional: Export group protocol =====
if ~isempty(opts.OutputZip)
    fprintf('\n=== Exporting group protocol to: %s ===\n', opts.OutputZip);
    iProtocol = bst_get('iProtocol');
    export_protocol(iProtocol, [], opts.OutputZip);
    fprintf('Export complete.\n');
end

%% ===== Cleanup =====
brainstorm stop;
fprintf('\nDone.\n');

end


%% ===== HELPER: Expand tilde =====
function p = expand_tilde(p)
    if startsWith(p, '~')
        home = char(java.lang.System.getProperty('user.home'));
        p = fullfile(home, p(2:end));
    end
end
