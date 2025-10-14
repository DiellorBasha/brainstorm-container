% export_results.m - Export existing protocol to workspace
%
% This script exports the TutorialOmega protocol to /workspace

fprintf('=== EXPORTING BRAINSTORM RESULTS ===\n');

% Start Brainstorm
if ~brainstorm('status')
    brainstorm nogui local
end

% Get the protocol information
protocols = bst_get('ProtocolsList');
fprintf('Available protocols:\n');
for i = 1:length(protocols)
    fprintf('  - %s\n', protocols(i).Comment);
end

% Find TutorialOmega protocol
omega_protocol = [];
for i = 1:length(protocols)
    if strcmp(protocols(i).Comment, 'TutorialOmega')
        omega_protocol = protocols(i);
        break;
    end
end

if isempty(omega_protocol)
    error('TutorialOmega protocol not found');
end

fprintf('Found TutorialOmega protocol\n');
fprintf('Protocol directory: %s\n', omega_protocol.STUDIES);

% Create export directory
export_dir = '/workspace/TutorialOmega_Export';
if ~exist(export_dir, 'dir')
    mkdir(export_dir);
end

% Copy the entire protocol directory
source_dir = fileparts(omega_protocol.STUDIES);
fprintf('Copying from: %s\n', source_dir);
fprintf('Copying to: %s\n', export_dir);

% Use system command to copy recursively
cmd = sprintf('cp -r "%s"/* "%s/"', source_dir, export_dir);
[status, result] = system(cmd);

if status == 0
    fprintf('Successfully exported protocol data!\n');
else
    fprintf('Copy failed: %s\n', result);
end

% List what was exported
fprintf('Exported contents:\n');
exported_files = dir(export_dir);
for i = 1:length(exported_files)
    if ~strcmp(exported_files(i).name, '.') && ~strcmp(exported_files(i).name, '..')
        fprintf('  - %s\n', exported_files(i).name);
    end
end

% Count .mat files
mat_files = dir(fullfile(export_dir, '**', '*.mat'));
fprintf('Total .mat files exported: %d\n', length(mat_files));

brainstorm stop
fprintf('Export completed! Results in: %s\n', export_dir);