% tutorial_omega_with_export.m - Tutorial with result export
%
% This script runs tutorial_omega and then copies all results to /workspace
% so they're accessible on the host machine after container stops

% Run the original tutorial
tutorial_omega('/data');

% Export all results to mounted workspace directory
fprintf('Exporting results to /workspace...\n');

% Create export directory structure
export_dir = '/workspace/TutorialOmega_Results';
if ~exist(export_dir, 'dir')
    mkdir(export_dir);
end

% Get the current protocol info
ProtocolInfo = bst_get('ProtocolInfo');
if isempty(ProtocolInfo)
    warning('No protocol found. Results may not be available.');
else
    fprintf('Current protocol: %s\n', ProtocolInfo.Comment);
    fprintf('Protocol directory: %s\n', ProtocolInfo.STUDIES);
    
    % Copy the entire protocol directory
    try
        % Use system command to copy recursively
        source_dir = fileparts(ProtocolInfo.STUDIES);
        cmd = sprintf('cp -r "%s" "%s/"', source_dir, export_dir);
        [status, result] = system(cmd);
        
        if status == 0
            fprintf('Successfully exported protocol data to: %s\n', export_dir);
        else
            fprintf('Copy failed: %s\n', result);
        end
        
        % Also copy any .mat files from the protocol
        cmd = sprintf('find "%s" -name "*.mat" -exec cp {} "%s/" \\;', source_dir, export_dir);
        system(cmd);
        
    catch ME
        fprintf('Error during export: %s\n', ME.message);
    end
end

% Copy any reports
try
    system(sprintf('cp /home/brainstorm/.brainstorm/*.html "%s/" 2>/dev/null || true', export_dir));
    system(sprintf('cp /home/brainstorm/.brainstorm/*.pdf "%s/" 2>/dev/null || true', export_dir));
catch
    % Ignore errors if no reports found
end

% List what was exported
fprintf('Exported files:\n');
system(sprintf('find "%s" -type f | head -20', export_dir));

fprintf('Tutorial completed and results exported to %s\n', export_dir);