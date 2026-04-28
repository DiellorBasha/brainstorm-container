%% test_pipeline_and_aggregate.m
% End-to-end test: run bst_single_subject on two subjects, then aggregate.
%
% Uses omega-tutorial dataset (must have sub-0002 and sub-0003 available).
% Runs the full pipeline (timefreq) for each subject, then combines the
% two per-subject protocol exports into a single group protocol.
%
% Usage:
%   Just run this script in MATLAB. No arguments needed.
%   Make sure brainstorm3 and this scripts/ folder are on the path.

clear; clc;

%% ===== Configuration =====
BidsDir    = '~/workspace/library/datasets/omega-tutorial';
OutputDir  = '~/workspace/library/datasets/brainstorm_db/test_aggregate';
BstDir     = '~/workspace/library/software/brainstorm3';
BstDbDir   = '~/workspace/library/datasets/brainstorm_db/tmp_aggregate';
ScriptDir  = fileparts(mfilename('fullpath'));

% Subjects to process
subjects = {'0002', '0003'};

% Pipeline stop position (run full pipeline)
module = 'timefreq';

% Group protocol name
groupProtocol = 'OMEGA_Aggregate_Test';

%% ===== Setup paths =====
addpath(ScriptDir);
addpath(expand_tilde(BstDir));

% Clean output directory
OutputDir = expand_tilde(OutputDir);
BstDbDir  = expand_tilde(BstDbDir);
if exist(OutputDir, 'dir')
    fprintf('Cleaning previous output: %s\n', OutputDir);
    rmdir(OutputDir, 's');
end
mkdir(OutputDir);

if exist(BstDbDir, 'dir')
    fprintf('Cleaning previous temp DB: %s\n', BstDbDir);
    rmdir(BstDbDir, 's');
end
mkdir(BstDbDir);

%% ===== Phase 1: Process each subject =====
fprintf('\n');
fprintf('============================================================\n');
fprintf('  PHASE 1: Per-subject processing (%s)\n', module);
fprintf('============================================================\n');

for i = 1:length(subjects)
    sub = subjects{i};
    fprintf('\n--- Processing sub-%s [%d/%d] ---\n\n', sub, i, length(subjects));

    bst_single_subject(BidsDir, OutputDir, sub, module, ...
        'BstDir', BstDir, ...
        'BstDbDir', BstDbDir);

    fprintf('\n--- sub-%s complete ---\n', sub);
end

%% ===== Verify exports =====
fprintf('\n');
fprintf('============================================================\n');
fprintf('  Verifying per-subject exports\n');
fprintf('============================================================\n');

for i = 1:length(subjects)
    zipName = sprintf('sub-%s_brainstorm.zip', subjects{i});
    zipPath = fullfile(OutputDir, zipName);
    if exist(zipPath, 'file')
        d = dir(zipPath);
        fprintf('  OK: %s (%.1f MB)\n', zipName, d.bytes / 1e6);
    else
        error('Missing export: %s', zipPath);
    end
end

%% ===== Phase 2: Aggregate into group protocol =====
fprintf('\n');
fprintf('============================================================\n');
fprintf('  PHASE 2: Aggregating subjects into group protocol\n');
fprintf('============================================================\n\n');

bst_aggregate_subjects(OutputDir, groupProtocol, ...
    'BstDir', BstDir, ...
    'BstDbDir', BstDbDir);

%% ===== Done =====
fprintf('\n');
fprintf('============================================================\n');
fprintf('  TEST COMPLETE\n');
fprintf('============================================================\n');
fprintf('  Subjects processed: %d\n', length(subjects));
fprintf('  Module: %s\n', module);
fprintf('  Per-subject zips: %s\n', OutputDir);
fprintf('  Group protocol: %s (in %s)\n', groupProtocol, BstDbDir);
fprintf('============================================================\n');


%% ===== Helper =====
function p = expand_tilde(p)
    if startsWith(p, '~')
        home = char(java.lang.System.getProperty('user.home'));
        p = fullfile(home, p(2:end));
    end
end
