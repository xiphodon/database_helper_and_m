
data = readtable('test_result.txt');

Scores      = log((1 - data.probDefault)./ data.probDefault) * 50 / log(2) + 450;
ProbDefault = data.probDefault;
RespVarMap = ~data.overdue;
NumDef      = sum(RespVarMap == 0);
NumObs      = numel(Scores);
AnalysisLevel = '';

% Get first score data for KS plot
    [~,iWorst]  = max(ProbDefault);
    WorstScore  = Scores(iWorst);
    WorstData   = RespVarMap(Scores == WorstScore);
    WorstGoods  = sum(WorstData);
    WorstBads   = length(WorstData) - WorstGoods;
    
    % Compute table of data or decile level statistics
    T = getValidationTable(ProbDefault,Scores,...
        RespVarMap,AnalysisLevel,NumDef,NumObs);

    % Compute relevant measures
    Stats = getValidationStatistics(T,NumDef,NumObs);

    % Show plots
    hf = plotValidationCurves({'ROC','KS'},T,Stats,NumDef,NumObs,...
       WorstScore,WorstBads,WorstGoods);

%% Helper functions

function T = getValidationTable(ProbDefault,Scores,RespVarMap,AnalysisLevel,NumDef,NumObs)
    % This helper function computes the statistics used to plot the curves.
    % The reported statistics are either at the score or the decile level.
    % These are the Scores, sorted from riskiest to safest, the 
    % corresponding Probabilities of Default, True Bads, False Bads, True 
    % Goods, False Goods, Sensitivity, False Alarm Rate and Percentage 
    % Observations.

    if strcmpi(AnalysisLevel,'deciles')
       
        % Create a Numeric container for ProbDefault against mapped
        % response. Apply Equal Frequency with 10 bins.
        % The container sorts from low probabilities to high probabilities,
        % and the cut points use the "left-edge" convention. This works
        % well, because we need a "right-edge" convention sorting from
        % high to low probabilities. So, after binning, we simply need to
        % flip the order of the cut points and the order of the frequency
        % table.
        dbc = internal.finance.binning.container.Numeric(ProbDefault,...
           RespVarMap,'ResponseOrder',[0 1]);
        % Create an equal frequency algorithm (try to) find the 10 equal
        % frequency bins
        ef = internal.finance.binning.algorithm.EqualFrequency;
        ef = ef.setOptions('NumBins',10);
        dbc = ef.runAlgorithm(dbc);

        % Get cumulative frequency table; note we flip, as per discussion
        % above.
        DecileCumFTPD = cumsum(flipud(dbc.getFrequencyTable));

        % We need to map cut points from pd's to scores, including the best
        % possible score, for the table cut points.
       
        % Find cut points in the order we want them (flipped) and including
        % the min pd; keep location of min pd (best score)
        [MinPD,MinPDInd] = min(ProbDefault);
        DecileCPPD = [flipud(dbc.getCutPoints);MinPD];

        % The number of bins after binning might not be 10, if there are too
        % few possible scores, or if only a few scores are assigned to most
        % of the data.
        NumDecileBinsPD = length(DecileCPPD);
       
        % Currently, the cut points from the container are not
        % full-precision, so we need to find the full-precision pd's before
        % mapping and before aggregating pd's.
        DecileCPPDFullPrecision = zeros(size(DecileCPPD));
        DecileCPScore = zeros(size(DecileCPPD));
        for ii=1:NumDecileBinsPD-1
           [~,ind] = min(abs(DecileCPPD(ii)-ProbDefault));
           DecileCPPDFullPrecision(ii) = ProbDefault(ind);
           DecileCPScore(ii) = Scores(ind);
        end
        % Last DecileCPPD is full-precision, by construction
        DecileCPPDFullPrecision(end) = DecileCPPD(end);
        DecileCPScore(end) = Scores(MinPDInd);

        % Compute pd's for each bin as the average pd of the data points in
        % the bin. Note that this implementation is actually a weighted
        % average, since the average is computed over all observations in
        % the bin.
        DecilePD = zeros(NumDecileBinsPD,1);
        DecilePD(1) = mean(ProbDefault(ProbDefault>=DecileCPPDFullPrecision(1)));
        for ii=2:NumDecileBinsPD
           DecilePD(ii) = mean(ProbDefault(DecileCPPDFullPrecision(ii-1)>ProbDefault &...
              ProbDefault>=DecileCPPDFullPrecision(ii)));
        end

        % Set variables used to finish the validation table below, outside
        % the decile v. score branching
        sScores = DecileCPScore;
        sProbDefault = DecilePD;
        TrueBads  = DecileCumFTPD(:,1);
        FalseBads = DecileCumFTPD(:,2);
        CumObs = TrueBads + FalseBads;
        PctObs = CumObs/CumObs(end);

    else
        
        [sProbDefault,Ind] = sort(ProbDefault,'descend');
        sScores = Scores(Ind);
        sRespVarMap = RespVarMap(Ind);

        TrueBads  = cumsum(~sRespVarMap); % CumBads
        FalseBads = cumsum(sRespVarMap); % CumGoods
        CumObs    = TrueBads + FalseBads;
        PctObs    = CumObs./NumObs;

        % Remove duplicates from sorted scores and statistics
        uInd = [sScores(1:end-1) ~= sScores(2:end);true];
        sScores = sScores(uInd);
        sProbDefault = sProbDefault(uInd);
        TrueBads  = TrueBads(uInd);
        FalseBads = FalseBads(uInd);
        PctObs    = PctObs(uInd);
        
    end
    
    % Compute the True Goods, False Goods, Sensitivity and False Alarm Rate
    TrueGoods   = FalseBads(end) - FalseBads;
    FalseGoods  = TrueBads(end) - TrueBads;
    Sensitivity = TrueBads./NumDef;
    FalseAlarm  = FalseBads./(NumObs-NumDef);
    
    T = table(sScores,sProbDefault,TrueBads,FalseBads,TrueGoods,FalseGoods,...
        Sensitivity,FalseAlarm,PctObs,'VariableNames',{'Scores','ProbDefault',...
        'TrueBads','FalseBads','TrueGoods','FalseGoods','Sensitivity',...
        'FalseAlarm','PctObs'});

end

function Stats = getValidationStatistics(T,NumDef,NumObs)

    % CAP
    x = [0;T.PctObs];
    y = [0;T.Sensitivity];
    
    aucap = 0.5*(y(1:end-1)+y(2:end))'*diff(x);
    ar = (aucap-0.5)/((1-NumDef/NumObs/2)-0.5);

    % ROC
    x = [0;T.FalseAlarm];
    % same y as CAP
    
    auroc = 0.5*(y(1:end-1)+y(2:end))'*diff(x);
    
    % KS
    [KSValue,KSInd] = max(T.Sensitivity-T.FalseAlarm);
    KSScore = T.Scores(KSInd);
    
    % Create Stats table output
    Measure = {'Accuracy Ratio','Area under ROC curve','KS statistic',...
            'KS score'}';
    Value  = [ar;auroc;KSValue;KSScore];
    
    Stats = table(Measure,Value);

end

%% Plot functions

function hf = plotValidationCurves(plotID,T,Stats,NumDef,NumObs,...
   WorstScore,WorstBads,WorstGoods)
    
    xPerfMdl = [0; NumDef/NumObs; 1];
    yPerfMdl = [0; 1; 1];
    Color1   = [1 1 0.6]; 
    Color2   = [0.8 1 1];
    
    % CAP data
    PctObs = [0;T.PctObs];
    TrueBadsRate = [0;T.Sensitivity];
    
    % ROC data
    FalseBadsRate = [0;T.FalseAlarm];
    
    % KS data
    Scores   = T.Scores;
    CumBads  = T.Sensitivity;
    CumGoods = T.FalseAlarm;
    
    % Additional KS adjustments and information
    
    % Adjust first point for deciles. Strictly speaking, the adjustment is
    % for any situation where the first value in Scores is not the minimum
    % observed score (which is the usual situation with deciles), in which
    % case we want to add data for the left-most values of the KS plot.
    if Scores(1) ~= WorstScore
       Scores   = [WorstScore;Scores];
       CumBads  = [WorstBads/NumDef; CumBads];
       CumGoods = [WorstGoods/(NumObs-NumDef); CumGoods];
    end
    
    % Get values for text in CAP plot
    [~,IndAR] = ismember('Accuracy Ratio',Stats.Measure);
    ar = Stats.Value(IndAR);
    
    % Get values for text in ROC plot
    [~,IndAUROC] = ismember('Area under ROC curve',Stats.Measure);
    auroc = Stats.Value(IndAUROC);
    
    % Get values for text in KS plot
    [~,IndKSValue] = ismember('KS statistic',Stats.Measure);
    KSValue = Stats.Value(IndKSValue);
    [~,IndKSScore] = ismember('KS score',Stats.Measure);
    KSScore = Stats.Value(IndKSScore);
    KSInd = find(KSScore==Scores,1,'first');
    
    if ischar(plotID)
        plotID = {plotID};
    end
        
    plotID = unique(plotID,'stable');
    
    hFig = cell(numel(plotID),1);
    
    for i = 1 : numel(plotID)
        % CAP
        if strcmpi(plotID{i},'cap')
            hFig{i} = plotCAP(PctObs,TrueBadsRate,xPerfMdl,yPerfMdl,...
                Color1,Color2,ar);
        end
        
        % ROC
        if strcmpi(plotID{i},'roc')
            hFig{i} = plotROC(FalseBadsRate,TrueBadsRate,Color1,auroc);
        end
        
        % KS
        if any(strcmpi(plotID{i},{'ks','k-s'}))
            hFig{i} = plotKS(Scores,CumBads,CumGoods,KSScore,KSValue,KSInd);
        end
    end
    
    hf = [hFig{:}];
end


function hcap = plotCAP(x,y,xPerfMdl,yPerfMdl,Color1,Color2,Measure)
    hcap = figure;
    hax  = axes('Parent',hcap);

    xLimits = get(hax,'XLim');
    yLimits = get(hax,'YLim');
    

    hp1 = fill([x;flipud(x)],[x;flipud(y)],Color1);
    set(hp1,'Parent',hax,'EdgeColor','none')
    hold(hax,'on')
    hp2 = fill([x;flipud(xPerfMdl)],[y;flipud(yPerfMdl)],Color2);
    set(hp2,'Parent',hax,'EdgeColor','none')

    box(hax,'on')
    plot(hax,x,y,'k-')
    plot(hax,x,x,'k--')
    plot(hax,xPerfMdl,yPerfMdl,'k')
    TextInPlot = sprintf('AR = %0.3f',Measure);
    text(0.6*diff(xLimits),0.2*diff(yLimits),TextInPlot,...
        'HorizontalAlignment','Center','Parent',hax)
    xlabel('Fraction of borrowers')
    ylabel('Fraction of defaulters')
    title(hax,'Cumulative Accuracy Profile (CAP) curve')

end


function hroc = plotROC(x,y,Color,Measure)
    hroc = figure;
    hax  = axes('Parent',hroc);

    xLimits = get(hax,'XLim');
    yLimits = get(hax,'YLim');
    X = [x;1;1;0];
    Y = [y;1;0;0];
    
    hp1 = fill(X,Y,Color);
    set(hp1,'Parent',hax,'EdgeColor','none')
    hold(hax,'on')
    plot(hax,x,y,'k-')
    box(hax,'on')
    TextInPlot = sprintf('AUROC = %0.3f',Measure);
    text(0.6*diff(xLimits),0.2*diff(yLimits),TextInPlot,...
        'HorizontalAlignment','Center','Parent',hax)
    xlabel('Fraction of non-defaulters')
    ylabel('Fraction of defaulters')
    title(hax,'Receiver Operating Characteristic (ROC) curve')
    
end


function hks = plotKS(Scores,CumBads,CumGoods,KSScore,KSValue,KSInd)
    hks = figure;
    hax = axes('Parent',hks);
    
    plot(hax,Scores,CumBads,Scores,CumGoods);
    if all(diff(Scores) < 0)
        set(hax,'XDir','Reverse');
    end
    hl = legend({'Cumulative Bads','Cumulative Goods'},'location','Best',...
        'AutoUpdate','Off');
    set(hl,'Parent',hks)
    xlabel('Score (Riskiest to Safest)')
    ylabel('Cumulative Probability')

    hold(hax,'on')
    xLimits = get(hax,'XLim');
    yLimits = get(hax,'YLim');

    plot(hax,[KSScore KSScore],yLimits,'k:')
    plot(hax,[xLimits(1) KSScore],[CumBads(KSInd) CumBads(KSInd)],'k:')
    plot(hax,[xLimits(1) KSScore],[CumGoods(KSInd) CumGoods(KSInd)],'k:')

    TextInPlot = sprintf('K-S %3.1f%%, at %g',KSValue*100,KSScore);
    text((xLimits(1)+KSScore)/2,(CumGoods(KSInd)+CumBads(KSInd))/2,TextInPlot,...
        'HorizontalAlignment','Center','Parent',hax)
    
    title(hax,'K-S Plot')
    hold(hax,'off')
end