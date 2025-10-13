% tutorial_omega_custom_db.m - Tutorial with custom database location
%
% This version sets the Brainstorm database to /workspace so all results
% are automatically saved to the mounted directory

% Set custom database location in mounted workspace
custom_db_dir = '/workspace/brainstorm_database';
if ~exist(custom_db_dir, 'dir')
    mkdir(custom_db_dir);
end

% Start Brainstorm with custom database location
if ~brainstorm('status')
    brainstorm('nogui', 'local', custom_db_dir);
end

% Verify database location
db_dir = bst_get('BrainstormDbDir');
fprintf('Brainstorm database directory: %s\n', db_dir);

% Now run the tutorial - all results will be saved to /workspace
tutorial_omega('/data');

fprintf('All results saved to: %s\n', custom_db_dir);