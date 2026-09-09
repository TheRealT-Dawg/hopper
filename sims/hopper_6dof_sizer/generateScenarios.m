function [scenarios, mcTable] = generateScenarios(jsonFile, n)
    % Set master seed for deterministic Latin Hypercube sampling
    masterSeed = 42;
    rng(masterSeed, 'twister');

    % Read JSON
    bounds = readstruct(jsonFile);
    paramNames = fieldnames(bounds);
    dim = length(paramNames);
    
    % Generate Latin Hypercube samples in [0,1]
    unitSamples = lhsdesign(n, dim, 'criterion', 'maximin', 'iterations', 50);
    
    % Preallocate struct array
    scenarios(1:n) = struct();
    
    for j = 1:dim
         name = paramNames{j};
         paramData = bounds.(name);
         
        % --- Continuous parameter ---
        if isfield(paramData, "lower")
            lower = paramData.lower;
            upper = paramData.upper;
            scaled = lower + (upper - lower).*unitSamples(:,j);
            
        % --- Discrete parameter ---
        elseif isfield(paramData, "values")
            values = paramData.values;
            k = length(values);
            idx = floor(unitSamples(:,j)*k) + 1;
            idx(idx > k) = k;
            scaled = values(idx);
        else
            error("Parameter %s not properly defined.", name);
        end
        
        for i = 1:n
            scenarios(i).(name) = scaled(i);
        end
    end
    
    % Append metadata tracking fields to every scenario
    for i = 1:n
        scenarios(i).RunID = i;
        scenarios(i).Seed = masterSeed + i;
    end
    
    % Convert dynamic struct array into a MATLAB workspace table
    mcTable = struct2table(scenarios);
    
    % Export table as a CSV file for lead tracking
    writetable(mcTable, 'mc_scenarios.csv');
end