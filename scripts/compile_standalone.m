function compile_standalone(BstDir, OutputDir)
% COMPILE_STANDALONE  Compile Brainstorm pipeline into standalone executables.
%
% Usage:
%   compile_standalone('/path/to/brainstorm3', '/path/to/output')
%
% This script uses MATLAB Compiler (mcc) to produce two standalone binaries:
%   1. bst_single_subject_standalone — per-subject pipeline
%   2. bst_aggregate_subjects_standalone — group aggregation
%
% Requirements:
%   - MATLAB with MATLAB Compiler toolbox
%   - Brainstorm3 source tree
%   - Pipeline scripts (bst_single_subject.m, bst_aggregate_subjects.m)
%
% On Alliance HPC:
%   module load matlab/2023b.2
%   matlab -batch "compile_standalone('$HOME/workspace/software/brainstorm3', '/scratch/$USER/compiled')"
%
% Output:
%   <OutputDir>/bst_single_subject_standalone   (Linux binary)
%   <OutputDir>/bst_aggregate_subjects_standalone (Linux binary)
%   <OutputDir>/run_bst_single_subject_standalone.sh
%   <OutputDir>/run_bst_aggregate_subjects_standalone.sh
%   <OutputDir>/requiredMCRProducts.txt
%
% The compiled binaries accept the SAME arguments as the .m functions but
% passed as strings (mcc converts all inputs to char). The wrapper scripts
% call the binary with the correct MCR path.
%
% Author: Diellor Basha
% Date: 2026

%% Validate inputs
if nargin < 2
    error('Usage: compile_standalone(BstDir, OutputDir)');
end

if ~exist(BstDir, 'dir')
    error('BstDir not found: %s', BstDir);
end

if ~exist(fullfile(BstDir, 'brainstorm.m'), 'file')
    error('Not a valid Brainstorm tree (brainstorm.m missing): %s', BstDir);
end

% Check MATLAB Compiler is available
if ~license('test', 'Compiler')
    error('MATLAB Compiler toolbox is not available. Check: ver compiler');
end

fprintf('================================================================\n');
fprintf(' COMPILE_STANDALONE — Brainstorm Pipeline\n');
fprintf('================================================================\n');
fprintf(' BstDir:    %s\n', BstDir);
fprintf(' OutputDir: %s\n', OutputDir);
fprintf(' MATLAB:    %s\n', version);
fprintf('================================================================\n\n');

%% Setup paths
ScriptsDir = fileparts(mfilename('fullpath'));  % this script's directory
mkdir_safe(OutputDir);

% Add Brainstorm to path (needed for dependency analysis)
addpath(BstDir);
addpath(ScriptsDir);

%% ========================================================================
%% Compile bst_single_subject
%% ========================================================================
fprintf('--- Compiling bst_single_subject_standalone ---\n');

single_subject_src = fullfile(ScriptsDir, 'bst_single_subject.m');
if ~exist(single_subject_src, 'file')
    error('Source not found: %s', single_subject_src);
end

% Include only Brainstorm toolbox tree (not entire ScriptsDir which has
% development test scripts that aren't valid functions for mcc).
% Add bst_aggregate_subjects.m explicitly as a dependency.
aggregate_src = fullfile(ScriptsDir, 'bst_aggregate_subjects.m');
mcc('-m', single_subject_src, ...
    '-o', 'bst_single_subject_standalone', ...
    '-d', OutputDir, ...
    '-a', BstDir, ...
    '-a', aggregate_src, ...
    '-N', ...  % clear path (avoid system toolbox conflicts)
    '-R', '-nodisplay', ...
    '-R', '-nosplash');

fprintf('  -> bst_single_subject_standalone compiled.\n\n');

%% ========================================================================
%% Compile bst_aggregate_subjects
%% ========================================================================
fprintf('--- Compiling bst_aggregate_subjects_standalone ---\n');

if ~exist(aggregate_src, 'file')
    error('Source not found: %s', aggregate_src);
end

mcc('-m', aggregate_src, ...
    '-o', 'bst_aggregate_subjects_standalone', ...
    '-d', OutputDir, ...
    '-a', BstDir, ...
    '-a', single_subject_src, ...
    '-N', ...
    '-R', '-nodisplay', ...
    '-R', '-nosplash');

fprintf('  -> bst_aggregate_subjects_standalone compiled.\n\n');

%% ========================================================================
%% Summary
%% ========================================================================
fprintf('================================================================\n');
fprintf(' Compilation complete!\n');
fprintf('================================================================\n');
fprintf(' Outputs in: %s\n', OutputDir);
d = dir(fullfile(OutputDir, 'bst_*'));
for i = 1:length(d)
    fprintf('   %s  (%s)\n', d(i).name, format_bytes(d(i).bytes));
end
fprintf('\n');
fprintf(' Next steps:\n');
fprintf('   1. Download MCR R2023b for Linux x64:\n');
fprintf('      https://ssd.mathworks.com/supportfiles/downloads/R2023b/Release/2/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2023b_Update_2_glnxa64.zip\n');
fprintf('   2. Place MCR zip + compiled binaries in staging directory\n');
fprintf('   3. Run build-mcr.sh to build the Apptainer container\n');
fprintf('================================================================\n');

end

%% ========================================================================
%% Helper functions
%% ========================================================================

function mkdir_safe(d)
    if ~exist(d, 'dir')
        [ok, msg] = mkdir(d);
        if ~ok
            error('Cannot create directory %s: %s', d, msg);
        end
    end
end

function s = format_bytes(b)
    if b > 1e9
        s = sprintf('%.1f GB', b/1e9);
    elseif b > 1e6
        s = sprintf('%.1f MB', b/1e6);
    elseif b > 1e3
        s = sprintf('%.1f KB', b/1e3);
    else
        s = sprintf('%d B', b);
    end
end
