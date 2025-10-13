% call_tutorial_omega_direct.m - Direct call to tutorial_omega with /data path
%
% This script directly calls tutorial_omega with the containerized data path
% without additional wrapper functionality

fprintf('=== Direct OMEGA Tutorial Call ===\n');
fprintf('Dataset path: /data\n');
fprintf('Calling tutorial_omega(''/data'')\n');

% Verify dataset exists
if ~exist('/data', 'dir')
    error('Dataset directory /data not found. Check volume mounting.');
end

% List dataset contents
fprintf('Dataset contents:\n');
dirList = dir('/data');
for i = 1:length(dirList)
    if ~strcmp(dirList(i).name, '.') && ~strcmp(dirList(i).name, '..')
        fprintf('  - %s\n', dirList(i).name);
    end
end

% Call tutorial_omega with the container path
try
    tutorial_omega('/data');
    fprintf('Tutorial completed successfully!\n');
catch ME
    fprintf('Error: %s\n', ME.message);
    rethrow(ME);
end