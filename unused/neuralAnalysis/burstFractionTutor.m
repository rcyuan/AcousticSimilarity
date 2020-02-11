function allNeuronCorrData = burstFractionTutor(birdIDs, params, varargin)
% generates allNeuronCorrData
if nargin < 2 || isempty(params)
    params = defaultParams;
end
params = processArgs(params, varargin{:});

%dataDir = ['data' filesep birdID filesep];
if ~iscell(birdIDs), birdIDs = {birdIDs}; end
allNeuronCorrData = struct([]);
for hh = 1:numel(birdIDs) % bird loop
    birdRep = reportOnData(birdIDs{hh}, [], [], 'verbose',false);
    birdData = struct([]);
    for ii = 1:numel(birdRep) % session loop
        thisSession = birdRep(ii).sessionID;
        hasData = all(findInManifest(birdRep(ii).manifest,{'bestDistScore', 'neuronSyllableData'}));
        hasLabelData = all(findInManifest(birdRep(ii).manifest,{'neuronSyllableData', ...
            'intraClusterDists', 'interClusterDists', 'acceptedLabels'}));
        if ~hasData
            %fprintf('No data for session %s, continuing...\n', thisSession);
            continue;
        end
        
        % load the data collected from each neuron/syllable pair
        % generated by writeNeuronStats
        nSData        = loadFromManifest(birdRep(ii).manifest, 'neuronSyllableData');
        % load the labels from clustering
        distTo.tutor       = loadFromManifest(birdRep(ii).manifest, 'bestDistScore');
        distTo.consensus   = loadFromManifest(birdRep(ii).manifest, 'distToConsensus');
        distTo.central     = loadFromManifest(birdRep(ii).manifest, 'distToCentral');
        distTo.intra       = loadFromManifest(birdRep(ii).manifest, 'intraClusterDists');
        distTo.inter       = loadFromManifest(birdRep(ii).manifest, 'interClusterDists');
        distTo.humanMatch  = loadFromManifest(birdRep(ii).manifest, 'distToHumanMatch');
        
        nNeurons  = size(nSData, 1);
        nClusters = size(nSData, 2)-1; % not the "unlabeled" clusters

        %%
        sessionData = struct([]);
        fprintf('Reading data for session %s, %d neurons, %d clusters...\n', thisSession, nNeurons, nClusters);
        
        for jj = 1:nNeurons  % neuron loop
            % neuronData is a collection of cluster correlation data for a given neuron
            neuronData = struct([]);
            dPs = fieldnames(distTo);
            
            hf = zeros(1,numel(dPs)); %figure handles
            hasAnyPlot = false(1,numel(dPs)); % whether a plot was created - for titling/init purposes
            
            for kk = 1:nClusters % syllable cluster loop
                thisNeuronEntry = nSData(jj,kk);
                % take out the neuron/syll pair entries for the unlabeled
                % syllable
                if isnan(thisNeuronEntry.syllID)
                    continue;
                end
                
                
                % corrData stores the correlation data between a neuron and a
                % corresponding syllable cluster
                corrData.syllID      = thisNeuronEntry.syllID;
                corrData.isCore      = thisNeuronEntry.isCore;
                corrData.isMUA       = thisNeuronEntry.isMUA;
                corrData.nSylls      = numel(thisNeuronEntry.syllIndex);
                corrData.avgResponse = thisNeuronEntry.FR_syllable - thisNeuronEntry.FR_baseline;
                corrData.pResponse   = thisNeuronEntry.p_ttest;
                corrData.burstFraction = thisNeuronEntry.burstFraction'; %JMA
                
                
                % if there are no cluster labels for this session, it's missing data...
                for ll = 1:numel(dPs)
                    [corrData.('RSAll'),corrData.([dPs{ll} '_DistanceAll']),...
                        corrData.('FRSyll'),corrData.('FRBase'),corrData.('burstFraction')] = ...
                        deal(NaN);
                end
                
                if hasLabelData
                    % loop through these distance prefixes declared in distTo
                    for ll = 1:numel(dPs)
                        % make sure it's not all missing data
                        if all(isnan(distTo.(dPs{ll})(thisNeuronEntry.syllIndex))),
                            % should be looked into
                            warning('No nonNaN values for distances to %s available for cluster %d', dPs{ll}, thisNeuronEntry.syllID);
                            continue;
                        end
                      
                        RS_syll = thisNeuronEntry.rawRates(1,:); RS_base = thisNeuronEntry.rawRates(2,:);
                        corrData.RSAll = RS_syll - RS_base;
                        corrData.FRSyll = RS_syll;
                        corrData.FRBase = RS_base;
                        corrData.([dPs{ll} '_DistanceAll']) = (distTo.(dPs{ll})(thisNeuronEntry.syllIndex));

                    end
                else
                    fprintf('Data missing for session %s, neuron %d, cluster %d...\n',...
                        thisSession, jj, thisNeuronEntry.syllID);
                end
                % add more information about the cluster here?
                neuronData = [neuronData; corrData];
                clear corrData;
            end % end cluster loop
            % add more information about the unit/neuron here
            fprintf('Finished compiling neuron %d for this session %s...\n', jj, thisSession);
            [neuronData.unitNum] = deal(jj);
            sessionData = [sessionData; neuronData];
        end % end neuron loop
        fprintf('Finished compiling for this session %s...\n', thisSession);
        [sessionData.sessionID] = deal(thisSession);
        birdData = [birdData; sessionData];
        % add more information about the session here
    end % end session loop
    fprintf('Finished compiling for this bird %s...\n', birdIDs{hh});
    [sessionData.birdID] = deal(birdIDs{hh});
    allNeuronCorrData = [allNeuronCorrData; birdData];
end % end bird loop

% save('data/allNeuronCorrelations.mat', 'allNeuronCorrData');
end