function bst_single_subject(BidsDir, OutputDir, SubjectLabel, Module, varargin)
% BST_SINGLE_SUBJECT  Single-subject Brainstorm pipeline for HPC/container use.
%
% Usage:
%   bst_single_subject(BidsDir, OutputDir, SubjectLabel, Module)
%   bst_single_subject(BidsDir, OutputDir, SubjectLabel, Module, 'Key', Value, ...)
%
% Required arguments:
%   BidsDir      - Path to BIDS dataset root (must contain sub-<label>/)
%   OutputDir    - Where to write the exported .zip protocol
%   SubjectLabel - Subject label WITHOUT 'sub-' prefix (e.g., '0002')
%   Module       - Pipeline stop position: 'import', 'preprocess', 'source', 'timefreq'
%
% Optional key-value pairs:
%   'BstDir'     - Path to brainstorm3 source tree (default: auto-detect from path)
%   'BstDbDir'   - Path for throwaway protocol database (default: tempdir/brainstorm_db)
%   'NVertices'  - Cortex downsampling target (default: 15000)
%
% The Module argument is a STOP POSITION — the pipeline always starts from
% raw BIDS and runs all stages up to and including the requested module:
%
%   'import'     = import only
%   'preprocess' = import -> preprocess
%   'source'     = import -> preprocess -> source
%   'timefreq'   = import -> preprocess -> source -> timefreq
%
% This follows the same pattern as FreeSurfer's recon-all stages: always
% starts from the same input (BIDS dataset), the flag controls how far
% processing goes. No "resume from protocol" mode — each run is fully
% self-contained with a throwaway protocol on BstDbDir.
%
% Output:
%   <OutputDir>/sub-<SubjectLabel>_brainstorm.zip
%
% Examples:
%   % Full pipeline (import + preprocess + source + timefreq)
%   bst_single_subject('/data/omega', '/output', '0002', 'timefreq')
%
%   % Import only
%   bst_single_subject('/data/omega', '/output', '0002', 'import')
%
%   % Source with custom DB location (for SLURM $SLURM_TMPDIR)
%   bst_single_subject('/data/omega', '/output', '0002', 'source', ...
%       'BstDbDir', fullfile(getenv('SLURM_TMPDIR'), 'brainstorm_db'))
%
% Follows the OMEGA resting-state tutorial processing chain:
%   import     -> process_import_bids (BIDS -> Brainstorm protocol)
%   preprocess -> notch 60Hz, bandpass 0.3Hz+, SSP cardiac
%   source     -> noise cov (emptyroom), head model, dSPM
%   timefreq   -> PSD on sources with frequency bands
%
% Author: Diellor Basha / NSP Pipeline
% Date: 2026

%% ========================================================================
%% Parse inputs
%% ========================================================================
p = inputParser;
addRequired(p, 'BidsDir', @ischar);
addRequired(p, 'OutputDir', @ischar);
addRequired(p, 'SubjectLabel', @ischar);
addRequired(p, 'Module', @(x) ismember(x, {'import','preprocess','source','timefreq'}));
addParameter(p, 'BstDir', '', @ischar);
addParameter(p, 'BstDbDir', '', @ischar);
% In compiled mode (mcc), all CLI arguments arrive as char.
% Relax the validator so inputParser accepts either type, then convert below.
if isdeployed
    addParameter(p, 'NVertices', 15000, @(x) isnumeric(x) || ischar(x));
else
    addParameter(p, 'NVertices', 15000, @isnumeric);
end
parse(p, BidsDir, OutputDir, SubjectLabel, Module, varargin{:});

opts = p.Results;

% Convert char → numeric for compiled-mode string arguments
if ischar(opts.NVertices)
    opts.NVertices = str2double(opts.NVertices);
    if isnan(opts.NVertices)
        error('NVertices must be a valid number, got: %s', p.Results.NVertices);
    end
end
SubjectName = ['sub-' opts.SubjectLabel];
ProtocolName = ['nsp_' SubjectName];

fprintf('\n');
fprintf('================================================================\n');
fprintf(' BST_SINGLE_SUBJECT — Per-subject Brainstorm Pipeline\n');
fprintf('================================================================\n');
fprintf(' Subject:    %s\n', SubjectName);
fprintf(' Module:     %s (stop position)\n', opts.Module);
fprintf(' BIDS dir:   %s\n', opts.BidsDir);
fprintf(' Output dir: %s\n', opts.OutputDir);
fprintf(' NVertices:  %d\n', opts.NVertices);
fprintf('================================================================\n\n');

%% ========================================================================
%% Resolve paths (expand ~ — Java IO does NOT handle tilde)
%% ========================================================================

% Expand tilde in all path arguments (Java's FileInputStream treats ~ as literal)
opts.BidsDir = expand_tilde(opts.BidsDir);
opts.OutputDir = expand_tilde(opts.OutputDir);
opts.BstDir = expand_tilde(opts.BstDir);
opts.BstDbDir = expand_tilde(opts.BstDbDir);

% Brainstorm source tree
BstDir = opts.BstDir;
if isempty(BstDir)
    % Auto-detect: check if brainstorm3 is already on the path
    if exist('brainstorm', 'file') == 2
        BstDir = fileparts(which('brainstorm'));
        fprintf('Auto-detected BstDir from path: %s\n', BstDir);
    else
        error('BstDir not specified and brainstorm3 not on MATLAB path');
    end
else
    % In compiled mode, addpath is forbidden — the toolbox is frozen in
    % the CTF archive. BstDir is only needed for templates/defaults.
    if ~isdeployed
        addpath(BstDir);
        fprintf('Added BstDir to path: %s\n', BstDir);
    else
        fprintf('Compiled mode — skipping addpath. BstDir for templates: %s\n', BstDir);
    end
end

% Brainstorm DB directory (throwaway — destroyed after export)
BstDbDir = opts.BstDbDir;
if isempty(BstDbDir)
    slurm_tmpdir = getenv('SLURM_TMPDIR');
    if ~isempty(slurm_tmpdir)
        BstDbDir = fullfile(slurm_tmpdir, 'brainstorm_db');
        fprintf('Using SLURM_TMPDIR for DB: %s\n', BstDbDir);
    else
        BstDbDir = fullfile(tempdir, 'brainstorm_db');
        fprintf('Using tempdir for DB: %s\n', BstDbDir);
    end
end

if ~exist(BstDbDir, 'dir')
    mkdir(BstDbDir);
end

if ~exist(opts.OutputDir, 'dir')
    mkdir(opts.OutputDir);
end

%% ========================================================================
%% Start logging (diary captures all command window output)
%% ========================================================================
LogFile = fullfile(opts.OutputDir, [SubjectName '_log.txt']);
diary(LogFile);
fprintf('Log file: %s\n', LogFile);
fprintf('Started: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

%% ========================================================================
%% Determine modules to run (module = stop position)
%% ========================================================================
MODULE_ORDER = {'import', 'preprocess', 'source', 'timefreq'};
target_idx = find(strcmp(MODULE_ORDER, opts.Module));
modules_to_run = MODULE_ORDER(1:target_idx);

fprintf('Pipeline: %s\n', strjoin(modules_to_run, ' -> '));

%% ========================================================================
%% Initialize Brainstorm (headless server mode)
%% ========================================================================
fprintf('\n--- Initializing Brainstorm ---\n');

% Ensure brainstorm setpath is called (needed for db_template)
brainstorm setpath;

% Pre-create ~/.brainstorm/brainstorm.mat to bypass first-run wizard.
% On first run, bst_startup checks for required fields:
%   iProtocol, ProtocolsListInfo, ProtocolsListSubjects,
%   ProtocolsListStudies, BrainStormDbDir (legacy camelCase)
% If missing, it launches an interactive wizard that hangs in batch mode.
bst_user_dir = fullfile(char(java.lang.System.getProperty('user.home')), '.brainstorm');
if ~exist(bst_user_dir, 'dir')
    mkdir(bst_user_dir);
end
bst_cfg_file = fullfile(bst_user_dir, 'brainstorm.mat');

% Always reset config to THIS job's DB dir — avoids stale protocol references
% from prior SLURM jobs that used a different $SLURM_TMPDIR.
iProtocol = 0;
ProtocolsListInfo     = repmat(db_template('ProtocolInfo'), 0);
ProtocolsListSubjects = repmat(db_template('ProtocolSubjects'), 0);
ProtocolsListStudies  = repmat(db_template('ProtocolStudies'), 0);
BrainStormDbDir = BstDbDir;
DbVersion = 5.03;
save(bst_cfg_file, 'iProtocol', 'ProtocolsListInfo', ...
     'ProtocolsListSubjects', 'ProtocolsListStudies', ...
     'BrainStormDbDir', 'DbVersion');
fprintf('Brainstorm config set: DB = %s\n', BstDbDir);

% Start server mode (no display required)
if ~brainstorm('status')
    brainstorm server;
end
fprintf('Brainstorm server started.\n');

%% ========================================================================
%% Create throwaway protocol
%% ========================================================================
fprintf('\n--- Creating protocol: %s ---\n', ProtocolName);

% Delete if registered in current Brainstorm session
iExisting = bst_get('Protocol', ProtocolName);
if ~isempty(iExisting)
    gui_brainstorm('DeleteProtocol', ProtocolName);
end

% Also nuke the directory on disk if leftover from a prior run
% (happens when Brainstorm was stopped and restarted — protocol is
% no longer registered but folder persists)
protocolDir = fullfile(BstDbDir, ProtocolName);
if exist(protocolDir, 'dir')
    fprintf('Removing leftover protocol directory: %s\n', protocolDir);
    rmdir(protocolDir, 's');
end

gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
bst_report('Start');
fprintf('Protocol created: %s\n', ProtocolName);

%% ========================================================================
%% Run pipeline modules
%% ========================================================================
try
    for iMod = 1:length(modules_to_run)
        mod_name = modules_to_run{iMod};
        fprintf('\n========================================\n');
        fprintf(' Module: %s (%d/%d)\n', upper(mod_name), iMod, length(modules_to_run));
        fprintf('========================================\n');

        switch mod_name
            case 'import'
                [sFilesRaw] = run_import(opts.BidsDir, SubjectName, opts.NVertices);
            case 'preprocess'
                [sFilesRest, sFilesBand] = run_preprocess(SubjectName, sFilesRaw);
            case 'source'
                [sFilesSrc] = run_source(SubjectName, sFilesRest, sFilesBand);
            case 'timefreq'
                run_timefreq(SubjectName, sFilesSrc);
        end
    end

    fprintf('\n--- All modules completed successfully ---\n');

catch ME
    fprintf('\nERROR in module "%s": %s\n', mod_name, ME.message);
    for k = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    % Save report before exit
    ReportFile = bst_report('Save');
    if ~isempty(ReportFile)
        copyfile(ReportFile, fullfile(opts.OutputDir, [SubjectName '_report_error.html']));
    end
    brainstorm stop;
    diary off;
    rethrow(ME);
end

%% ========================================================================
%% Export subject as self-contained .zip
%% ========================================================================
fprintf('\n--- Exporting subject ---\n');

% Find the subject index (skip Default Subject at index 0)
[~, iSubject] = bst_get('Subject', SubjectName);
if isempty(iSubject) || iSubject == 0
    % Fallback: grab the first non-default subject
    ProtocolSubjects = bst_get('ProtocolSubjects');
    for iSub = 1:length(ProtocolSubjects.Subject)
        if ~ProtocolSubjects.Subject(iSub).UseDefaultAnat || ...
                ~strcmpi(ProtocolSubjects.Subject(iSub).Name, bst_get('DirDefaultSubject'))
            iSubject = iSub;
            break;
        end
    end
end

if isempty(iSubject) || iSubject == 0
    error('Could not find subject %s in protocol for export', SubjectName);
end

% Export via Brainstorm's official API
iProtocol = bst_get('iProtocol');
ExportZip = fullfile(opts.OutputDir, [SubjectName '_brainstorm.zip']);

fprintf('Exporting subject %s (index %d) to: %s\n', SubjectName, iSubject, ExportZip);
export_protocol(iProtocol, iSubject, ExportZip);

% Verify export
zipInfo = dir(ExportZip);
if isempty(zipInfo) || zipInfo.bytes == 0
    error('Export failed — zip file missing or empty: %s', ExportZip);
end
fprintf('Export complete: %s (%.1f MB)\n', ExportZip, zipInfo.bytes / 1048576);

%% ========================================================================
%% Save report and cleanup
%% ========================================================================
ReportFile = bst_report('Save');
if ~isempty(ReportFile)
    reportDest = fullfile(opts.OutputDir, [SubjectName '_report.html']);
    copyfile(ReportFile, reportDest);
    fprintf('Report saved: %s\n', reportDest);
end

% Stop Brainstorm
brainstorm stop;
fprintf('\nBrainstorm stopped. Pipeline complete for %s.\n', SubjectName);
fprintf('Finished: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

% Close diary log
diary off;
fprintf('Log saved: %s\n', LogFile);

end


%% ########################################################################
%% MODULE: IMPORT
%% ########################################################################
function [sFilesRaw] = run_import(BidsDir, SubjectName, NVertices)
% Import single subject from BIDS directory into the current protocol.
%
% Handles:
% - Trimming participants.tsv to target subject only
% - BIDS import with FreeSurfer cortex downsampling
% - Anatomy verification (cortex surface must exist for source analysis)
% - Head points cleanup + CTF conversion (omega-specific)
%
% Output: sFilesRaw — raw data file references from BIDS import

fprintf('Importing %s from BIDS: %s\n', SubjectName, BidsDir);

% --- Import BIDS dataset ---
% nvertices triggers FreeSurfer surface import + cortex downsampling.
% anatregister='no' avoids SPM12 dependency for MRI coregistration.
% selectsubj filters to ONLY the target subject (critical when the BIDS
% directory contains multiple subjects, e.g. running locally without the
% HPC wrapper that trims the directory).
sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
    'bidsdir',       {BidsDir, 'BIDS'}, ...
    'selectsubj',    SubjectName, ...
    'nvertices',     NVertices, ...
    'channelalign',  0, ...
    'anatregister',  'no');

% Fallback: process_import_bids may return empty even when data was
% imported successfully (observed with some Brainstorm versions).
% Query the protocol database directly to find raw data files.
if isempty(sFilesRaw)
    fprintf('WARNING: process_import_bids returned empty — querying protocol database...\n');
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if ~isempty(iSubject)
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject');
        for iSt = 1:length(sStudies)
            for iData = 1:length(sStudies(iSt).Data)
                sFilesRaw(end+1).FileName = sStudies(iSt).Data(iData).FileName; %#ok<AGROW>
                sFilesRaw(end).Comment    = sStudies(iSt).Data(iData).Comment;
            end
        end
    end
end

if isempty(sFilesRaw)
    error('BIDS import produced no data files for %s', SubjectName);
end
fprintf('BIDS import complete: %d data files\n', length(sFilesRaw));

% --- Verify anatomy: cortex surface must exist for source analysis ---
sSubjects = bst_get('ProtocolSubjects');
for iSub = 1:length(sSubjects.Subject)
    subName = sSubjects.Subject(iSub).Name;
    iCortex = sSubjects.Subject(iSub).iCortex;
    if isempty(iCortex); iCortex = 0; end
    nSurf = length(sSubjects.Subject(iSub).Surface);
    fprintf('  Subject %s: %d surfaces, iCortex=%d\n', subName, nSurf, iCortex);
    if (isempty(iCortex) || iCortex == 0) ...
            && ~strcmpi(subName, '@default_subject') ...
            && ~startsWith(subName, 'sub-emptyroom')
        warning('No cortex for %s — source analysis will fail. Check FreeSurfer derivatives.', subName);
    end
end

% --- Post-import: head points cleanup + CTF conversion ---
% Standard for omega/CTF MEG datasets
sFilesRaw = bst_process('CallProcess', 'process_headpoints_remove', sFilesRaw, [], ...
    'zlimit', 0);
sFilesRaw = bst_process('CallProcess', 'process_headpoints_refine', sFilesRaw, []);
sFilesRaw = bst_process('CallProcess', 'process_ctf_convert', sFilesRaw, [], ...
    'rectype', 2);

fprintf('Import complete for %s\n', SubjectName);
end


%% ########################################################################
%% MODULE: PREPROCESS
%% ########################################################################
function [sFilesRest, sFilesBand] = run_preprocess(SubjectName, sFilesRaw)
% Preprocessing: notch filter, bandpass, detect ECG, SSP cardiac.
%
% Follows the omega resting-state tutorial:
% 1. Notch 60 Hz + harmonics (North America power line)
% 2. High-pass 0.3 Hz (remove drift)
% 3. Delete raw + notch intermediates
% 4. Separate rest vs noise recordings
% 5. Detect heartbeats on ECG channel
% 6. SSP cardiac artifact removal
%
% Input:  sFilesRaw — from import module
% Output: sFilesRest — cleaned rest recordings
%         sFilesBand — all bandpass-filtered files (rest + noise)

fprintf('Preprocessing %s\n', SubjectName);

% 1. Notch filter — 60 Hz + harmonics
sFilesNotch = bst_process('CallProcess', 'process_notch', sFilesRaw, [], ...
    'freqlist',    [60, 120, 180, 240, 300], ...
    'sensortypes', 'MEG, EEG', ...
    'read_all',    1);

% 2. High-pass filter — 0.3 Hz
sFilesBand = bst_process('CallProcess', 'process_bandpass', sFilesNotch, [], ...
    'sensortypes', 'MEG, EEG', ...
    'highpass',    0.3, ...
    'lowpass',     0, ...
    'attenuation', 'strict', ...
    'mirror',      0, ...
    'useold',      0, ...
    'read_all',    1);

% 3. Delete originals + notch intermediates (save disk)
bst_process('CallProcess', 'process_delete', [sFilesRaw, sFilesNotch], [], ...
    'target', 2);

% 4. Re-select all bandpass-filtered data files
sFilesBand = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname', 'All');

% 5. Select rest recordings (tag: task-rest)
sFilesRest = bst_process('CallProcess', 'process_select_tag', sFilesBand, [], ...
    'tag',    'task-rest', ...
    'search', 1, ...
    'select', 1);

% 6. Detect heartbeats on ECG channel
bst_process('CallProcess', 'process_evt_detect_ecg', sFilesRest, [], ...
    'channelname', 'ECG', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');

% 7. SSP: cardiac artifact removal
bst_process('CallProcess', 'process_ssp_ecg', sFilesRest, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG', ...
    'usessp',      1, ...
    'select',      1);

fprintf('Preprocessing complete for %s\n', SubjectName);
end


%% ########################################################################
%% MODULE: SOURCE
%% ########################################################################
function [sFilesSrc] = run_source(SubjectName, sFilesRest, sFilesBand)
% Source estimation: noise covariance, head model, dSPM.
%
% Follows the omega resting-state tutorial:
% 1. Select noise (empty-room) recordings for noise covariance
% 2. Compute noise covariance (shared across conditions)
% 3. Overlapping spheres head model (MEG standard)
% 4. dSPM source estimation, kernel only
%
% Input:  sFilesRest — rest recordings (from preprocess)
%         sFilesBand — all bandpass-filtered files (from preprocess)
% Output: sFilesSrc  — dSPM source kernel results

fprintf('Source estimation for %s\n', SubjectName);

% 1. Select noise (empty room) recordings
sFilesNoise = bst_process('CallProcess', 'process_select_tag', sFilesBand, [], ...
    'tag',    'task-noise', ...
    'search', 1, ...
    'select', 1);

if isempty(sFilesNoise)
    warning('No task-noise recordings found — using rest data for noise covariance');
    sFilesNoise = sFilesRest;
end

% 2. Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesNoise, [], ...
    'baseline',       [], ...
    'sensortypes',    'MEG', ...
    'target',         1, ...    % Noise covariance
    'dcoffset',       1, ...    % Block by block
    'identity',       0, ...
    'copycond',       1, ...
    'copysubj',       1, ...
    'copymatch',      1, ...
    'replacefile',    1);

% 3. Head model — overlapping spheres (standard for MEG)
bst_process('CallProcess', 'process_headmodel', sFilesRest, [], ...
    'sourcespace', 1, ...   % Cortex surface
    'meg',         3);      % Overlapping spheres

% 4. dSPM source estimation (kernel only: one per file)
sFilesSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesRest, [], ...
    'output',  2, ...    % Kernel only: one per file
    'inverse', struct(...
        'Comment',        'dSPM: MEG', ...
        'InverseMethod',  'minnorm', ...
        'InverseMeasure', 'dspm2018', ...
        'SourceOrient',   {{'fixed'}}, ...
        'Loose',          0.2, ...
        'UseDepth',       1, ...
        'WeightExp',      0.5, ...
        'WeightLimit',    10, ...
        'NoiseMethod',    'reg', ...
        'NoiseReg',       0.1, ...
        'SnrMethod',      'fixed', ...
        'SnrRms',         1e-06, ...
        'SnrFixed',       3, ...
        'ComputeKernel',  1, ...
        'DataTypes',      {{'MEG'}}));

if isempty(sFilesSrc)
    error('Source estimation produced no results for %s', SubjectName);
end

fprintf('Source estimation complete: %d results\n', length(sFilesSrc));
end


%% ########################################################################
%% MODULE: TIMEFREQ
%% ########################################################################
function run_timefreq(SubjectName, sFilesSrc)
% Time-frequency: PSD on sources with frequency bands, normalize, project.
%
% Follows the omega resting-state tutorial:
% 1. PSD on source-space with frequency band definitions
% 2. Spectrum normalization (relative power)
% 3. Project sources to default anatomy (for group comparison)
% 4. Spatial smoothing (3mm FWHM)
%
% Input: sFilesSrc — from source module (dSPM kernel results)

fprintf('Time-frequency analysis for %s\n', SubjectName);
fprintf('Using %d source result(s)\n', length(sFilesSrc));

% 1. PSD on source space with frequency band definitions
sSrcPsd = bst_process('CallProcess', 'process_psd', sFilesSrc, [], ...
    'timewindow',  [0, 100], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'clusters',    {}, ...
    'scoutfunc',   1, ...   % Mean
    'edit',        struct(...
        'Comment',         'Power,FreqBands', ...
        'TimeBands',       [], ...
        'Freqs',           {{'delta', '2, 4', 'mean'; ...
                            'theta', '5, 7', 'mean'; ...
                            'alpha', '8, 12', 'mean'; ...
                            'beta', '15, 29', 'mean'; ...
                            'gamma1', '30, 59', 'mean'; ...
                            'gamma2', '60, 90', 'mean'}}, ...
        'ClusterFuncTime', 'none', ...
        'Measure',         'power', ...
        'Output',          'all', ...
        'SaveKernel',      0));

% 2. Spectrum normalization — relative power
sSrcPsdNorm = bst_process('CallProcess', 'process_tf_norm', sSrcPsd, [], ...
    'normalize', 'relative', ...
    'overwrite', 0);

% 3. Project sources to default anatomy (for group comparison)
sSrcPsdProj = bst_process('CallProcess', 'process_project_sources', sSrcPsdNorm, [], ...
    'headmodeltype', 'surface');

% 4. Spatial smoothing (3 mm FWHM)
bst_process('CallProcess', 'process_ssmooth_surfstat', sSrcPsdProj, [], ...
    'fwhm',      3, ...
    'overwrite', 1);

fprintf('Time-frequency analysis complete for %s\n', SubjectName);
end


%% ########################################################################
%% UTILITY: expand_tilde
%% ########################################################################
function p = expand_tilde(p)
% Expand leading ~ to user home directory.
% Java's FileInputStream does NOT handle tilde — it treats '~' as a literal
% character, causing FileNotFoundException on .nii.gz reads.
if ~isempty(p) && p(1) == '~'
    home = char(java.lang.System.getProperty('user.home'));
    p = fullfile(home, p(2:end));
end
end
