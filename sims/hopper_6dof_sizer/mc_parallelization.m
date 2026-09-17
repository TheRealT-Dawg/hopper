% --- Monte Carlo Simulation Master Script ---
warning('off', 'MATLAB:Python:PyNotFound')
clear; clc;

% Options: 'parallel', 'serial', 'nominal'
runMode = 'parallel';

if strcmp(runMode, 'parallel')
    if ~isempty(gcp('nocreate'))
        delete(gcp);
    end
    parpool();
end

% Attach all required models, lookup files, and subfolder directories to workers
mFiles = dir('*.m');
matFiles = dir('*.mat');
slxFiles = dir('*.slx');
xlsxFiles = dir('*.xlsx');
jsonFiles = dir('*.json');
addAllFiles = [{matFiles.name}, {slxFiles.name}, {xlsxFiles.name}, {jsonFiles.name}, {mFiles.name}];

if strcmp(runMode, 'parallel')
    p = gcp();
    addAttachedFiles(p, addAllFiles);
end

jsonFile = 'mc_params.json';

if ~strcmp(runMode, 'nominal')
    n = input('Enter the number of Monte Carlo scenarios (e.g., 1000): ');
    if isempty(n) || n <= 0
        error('Invalid input. Please enter a positive integer.');
    end
    [scenarios, mcTable] = generateScenarios(jsonFile, n);
    scenarioStructs = table2struct(mcTable);
    resultsCell = cell(n, 1); 
end

% --- Execution Router (Switch-Case) ---
switch runMode
    case 'parallel'
        tic;
        parfor i = 1:n
            % Add necessary project subpaths on each worker
            addpath(genpath(pwd)); 
            addpath('./sizing'); addpath('./inputs'); addpath('./propulsion'); addpath('./dynamics');
            
            currentScenario = scenarioStructs(i);
            localResult = struct(); 
            
            try
                % 1. Vehicle initialization and sizing chain
                mc_sim_setup(currentScenario);
                IN        = evalin('base', 'IN');
                VEH       = evalin('base', 'VEH');
                TANKS     = evalin('base', 'TANKS');
                STRUCT    = evalin('base', 'STRUCT');
                cg_init   = evalin('base', 'cg_init');
                engine_cg = evalin('base', 'engine_cg');
                OUT       = Outputs(IN, VEH, TANKS, STRUCT);
                LinerizationMaster();
                
                % 2. Setup simulation input object
                mc_sim_setup(currentScenario);
                simInput = Simulink.SimulationInput('hopper_6dof_NED_v2');
                simInput = simInput.setVariable('currentScenario', currentScenario);
                
                % 3. Execute simulation and post-process
                sim_out = sim(simInput);
                localResult = mc_main(currentScenario, sim_out); 
                
                % 4. Validate engineering constraints (Pass/Fail)
                localResult = check_constraints(localResult);
                
            catch ME
                localResult.scenario = currentScenario;
                localResult.status.success = false;
                localResult.status.error = ME.message;
                localResult.status.pass = false;
            end
            
            resultsCell{i} = localResult;
        end
        elapsedTime = toc;
        fprintf('Completed %d Monte Carlo runs in %.2f seconds.\n', n, elapsedTime);
        
        % --- Export Results ---
        mcTable.Results = resultsCell;
        writetable(mcTable, 'mc_results_parallel.csv');
        fprintf('Results successfully saved to mc_results_parallel.csv\n');
        
    case 'serial'
        tic;
        for i = 1:n
            addpath(genpath(pwd)); 
            addpath('./sizing'); addpath('./inputs'); addpath('./propulsion'); addpath('./dynamics');
            
            currentScenario = scenarioStructs(i);
            localResult = struct(); 
            
            try
                % 1. Vehicle initialization and sizing chain
                mc_sim_setup(currentScenario);
                IN        = evalin('base', 'IN');
                VEH       = evalin('base', 'VEH');
                TANKS     = evalin('base', 'TANKS');
                STRUCT    = evalin('base', 'STRUCT');
                cg_init   = evalin('base', 'cg_init');
                engine_cg = evalin('base', 'engine_cg');
                OUT       = Outputs(IN, VEH, TANKS, STRUCT);
                LinerizationMaster();
                
                % 2. Setup simulation input object
                mc_sim_setup(currentScenario);
                simInput = Simulink.SimulationInput('hopper_6dof_NED_v2');
                simInput = simInput.setVariable('currentScenario', currentScenario);
                
                % 3. Execute simulation and post-process
                sim_out = sim(simInput);
                localResult = mc_main(currentScenario, sim_out); 
                
                % 4. Validate engineering constraints (Pass/Fail)
                localResult = check_constraints(localResult);
                
            catch ME
                localResult.scenario = currentScenario;
                localResult.status.success = false;
                localResult.status.error = ME.message;
                localResult.status.pass = false;
            end
            
            resultsCell{i} = localResult;
        end
        elapsedTime = toc;
        fprintf('Completed %d sequential runs in %.2f seconds.\n', n, elapsedTime);
        
        % --- Export Results ---
        mcTable.Results = resultsCell;
        writetable(mcTable, 'mc_results_serial.csv');
        fprintf('Results successfully saved to mc_results_serial.csv\n');
        
    case 'nominal'
        tic;
        try
            nominalScenario = mc_input();
            mc_sim_setup(nominalScenario);
            IN        = evalin('base', 'IN');
            VEH       = evalin('base', 'VEH');
            TANKS     = evalin('base', 'TANKS');
            STRUCT    = evalin('base', 'STRUCT');
            cg_init   = evalin('base', 'cg_init');
            engine_cg = evalin('base', 'engine_cg');
            OUT       = Outputs(IN, VEH, TANKS, STRUCT);
            LinerizationMaster();
            
            mc_sim_setup(nominalScenario);
            simInput = Simulink.SimulationInput('hopper_6dof_NED_v2');
            sim_out = sim(simInput);
            disp('Nominal simulation completed successfully.');
        catch ME
            rethrow(ME);
        end
        elapsedTime = toc;
        fprintf('Nominal run completed in %.2f seconds.\n', elapsedTime);
        
    otherwise
        error('Invalid runMode specified. Use ''parallel'', ''serial'', or ''nominal''.');
end