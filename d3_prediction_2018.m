% A random forest is trained on historical D3 basketball team data
% in order to predict which teams in 2018 will make it into the 
% D3 March Madness tournament

clear all; close all;
 
%% Import and convert historical data
 
file = "Historical Data.xlsx";

% Import 1 at a time so as to save the txt to int mappings in <var>_map

% import region data
[region, region_txt] =xlsread(file, "B2:B183");
 
% convert strings to integers and save mapping in region_map
% regoin_map is a map object 
[region_ints, region_map] = map_to_int(region_txt);
 
[team, team_txt] = xlsread(file, "D2:D183");
[team_ints, team_map] = map_to_int(team_txt);
 

[conference, conference_txt] = xlsread(file, "E2:E183");
[conference_ints, conference_map] = map_to_int(conference_txt);
 
% use a custom function to calculate vRRO as a proportion 
[vRRO, vRRO_txt] = xlsread(file, "I2:I183");
[vRRO_proportion, vRRO_wins, vRRO_losses] = record_to_proportion(vRRO_txt);
 
[WL, WL_txt] = xlsread(file, "H2:H183");
[WL_proportion, WL_wins, WL_losses] = record_to_proportion(WL_txt);
 
clear region region_txt  team team_txt WL WL_txt;
clear conference conference_txt  vRRO vRRO_txt;
 
%% Get all data in the same order as in the spreadsheet
% read in rest of data that 
format longG;        % needed because xlsread was using scientific notation
A = xlsread(file);   % gets whole spreadsheet

A = [A(:, 1), region_ints, A(:, 3), team_ints, conference_ints, A(:, 6), A(:, 7), vRRO_proportion, vRRO_wins, vRRO_losses, WL_wins, WL_losses]; 
 
% B: (berth) 
B = xlsread(file, "J2:J183");   % berth = 1, not berth = 0?
 
%% Split all data (A and B) into training, validation, and testing
% not shuffling data because it increased mean squared error substantially
% this was probably because the data is sequential (2015, 2016, 2017)
train_split = .60 * length(A);       % 60% train
val_split = .80 * length(A);         % 20% validation
test_split = 1 * length(A);          % 20% test  
 
A_train = A(1:train_split, :);
B_train = B(1:train_split, :);
 
A_val = A((train_split + 1):val_split, :);
B_val = B((train_split + 1):val_split, :);
 
A_test = A((val_split + 1):test_split, :);
B_test = B((val_split + 1):test_split, :);
 
%% Build the model on training data
numTrees = 60;
numtoAverage = 1;
nForest = ones(numTrees, 1);

 
% Random Forest
overall_mse = 0;

% Tune the number of trees in the random forest - try 1 to numTrees
for n = 1:numTrees
    currentMSE = 0;
    
    % run the fit-predict-evaluate cycle numtoAverage number of times
    for i = 1:numtoAverage
        % surrogate automatically handles missing data by treating it as a
        % variable
        Forest = TreeBagger(n, A_train, B_train, 'method', 'regression', 'Surrogate', 'on');
        PredForest = predict(Forest,A_val);
        mseForest = (sum((B_val - PredForest).^2)) / length(B_val);
        currentMSE = currentMSE + mseForest; 
    end
    currentMSE = currentMSE / numtoAverage;
    overall_mse = overall_mse + currentMSE;
    nForest(n,1) = currentMSE;
end
overall_mse = overall_mse / numTrees
 
%% Plot the mean squared error (MSE) for forests with from 1 to numtrees trees
x = (1:numTrees);
x = reshape(x,[numTrees, 1]);
manyTree = plot(x,nForest(:,:));
 
%% Test the data -- ¡do only after tuning the model!
% n = 300 because here, mse_test is (usually) stable to the hundredths place
ForestFinalModel = TreeBagger(300, A_train, B_train, 'method', 'regression', 'Surrogate', 'on');
PredForestFinalModel = predict(ForestFinalModel, A_test);
 
mse_test = (sum((B_test - PredForestFinalModel).^2)) / length(B_test)
 
PredForestVal = predict(ForestFinalModel, A_val);
mse_val = (sum((B_val - PredForestVal).^2)) / length(B_val)
 
 
%% 2018 data import and format
clear region_ints team_ints conference_ints vRRO_proportion;
 
file = "Data_2018.xlsx";
 
[region, region_txt] =xlsread(file, "B2:B54");
[region_ints, region_map] = map_to_int(region_txt, region_map);
 
[team, team_txt] = xlsread(file, "D2:D54");
[team_ints, team_map] = map_to_int(team_txt, team_map);
 
[conference, conference_txt] = xlsread(file, "E2:E54");
[conference_ints, conference_map] = map_to_int(conference_txt, conference_map);
 
% use a custom function to calculate vRRO as a proportion
[vRRO, vRRO_txt] = xlsread(file, "J2:J54");
[vRRO_proportion, vRRO_wins, vRRO_losses] = record_to_proportion(vRRO_txt);
 
[WL, WL_txt] = xlsread(file, "I2:I54");
[WL_proportion, WL_wins, WL_losses] = record_to_proportion(WL_txt);
 
 
%% Get all 2018 data in the same order as in the 2018 spreadsheet
% read in rest of data
format longG;        % needed because xlsread was using scientific notation
A_2018 = xlsread(file);   % gets whole spreadsheet
 

A_2018 = [A_2018(:, 1), region_ints, A_2018(:, 3), team_ints, conference_ints, A_2018(:, 6), A_2018(:, 7), vRRO_proportion, vRRO_wins, vRRO_losses, WL_wins, WL_losses]; 
 
 
%% Use model above to predict berths 
prediction_probabilities = predict(ForestFinalModel, A_2018);

% convert to binomial data
% berth_probability = 21 / size(A_2018, 1);   % 21 out of 50 since predicting 21 that receive a berth
berth_probability = mean([B_train; B_val; B_test]);
prediction_classification = [];

for i = 1:size(prediction_probabilities, 1)
    if prediction_probabilities(i, 1) >= berth_probability
        prediction_classification = [prediction_classification; 1];
        
    else
        prediction_classification = [prediction_classification; 0];
    end
end

 
%% FUNCTIONS
 
% maps strings in string_data (key) to an integer in int_data (value).
% map_obj is used to convert to strings to integers and can be
% used later if more data is imported ? this ensures consistent
% conversions and should be much faster than manually converting.
function [int_data, map_obj] = map_to_int(string_data, map_obj)
    num_rows = size(string_data, 1); % # of rows in array
    int_data = [];
    
    if nargin == 1          % if no mapping dictionary supplied
        map_obj = containers.Map();
        next_value = 0;     % if add new entry to map_obj, it would have this value
    
    else    % else, mapping dictionary is supplied
        next_value = size(map_obj, 1);
    end
    
    % the key is the string data, value is the integer string is mapped to
    for i = 1:num_rows
        for key = string_data(i,1)
            
            % if key/string already in map_obj so use its value
            if isKey(map_obj, key) 
                int_value = values(map_obj, key);
                int_data = [int_data; int_value];
              
            % else not in map_obj -->  add key:value to entry
            else    
                % make string, int entry into map_obj 
                new_entry = containers.Map(key, next_value);
                map_obj = [map_obj; new_entry];
       
                % append it to the bottom of column int_data
                int_value = values(map_obj, key);
 
                int_data = [int_data; int_value];
                next_value = next_value + 1;
            end
        end
    end
 
    % weird stuff to make int_data a vector;
    % done because int_data is an array of arrays but want vector of ints
    cell2mat(int_data);
    
    temp = int_data;
    clear int_data;
    int_data = [];
    for i = temp
        i = cell2mat(i);
        int_data = [int_data; i];
    end
        
end
 
% takes in string_data column (the records "W-L") and converts it to 
% a column of proportions, each calculated as (W / W + L)
function [proportions, won, lost] = record_to_proportion(string_data)
    proportions = []; won = []; lost = [];
    wins = 0; losses = 0;
    
    for i = 1:size(string_data)
        for record = string_data(i)
            record = cell2mat(record);
            wins_losses = sscanf(record, '%i-%i'); 
            wins = wins_losses(1); losses = wins_losses(2);
         
            win_proportion = wins / (wins + losses);
            proportions = [proportions; win_proportion];
            
            won = [won; wins];
            lost = [lost; losses];
        end
    end
end
 
% Did not use for final model
% takes the data (X) and targets (y) and randomly shuffle rows
% returns A and B separately and preserve row data with target
function [X_shuffled, y_shuffled] = shuffle_rows(X, y)
    X_and_y = [X, y];
    % shuffle rows
    X_and_y_shuffled = X_and_y(randperm(size(X_and_y, 1)), :);
 
    % columns 1 - 8
    X_shuffled = X_and_y_shuffled(:, 1:(size(X_and_y_shuffled, 2) - 1));
    % berth column
    y_shuffled = X_and_y_shuffled(:, size(X_and_y_shuffled, 2));
end
