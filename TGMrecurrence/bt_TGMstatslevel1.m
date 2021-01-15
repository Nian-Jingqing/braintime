function [stats1] = bt_TGMstatslevel1(config, bt_data, bt_TGMquant)
% Acquire single subject level statistics using permutation testing.
% Null distributions are created by shuffling the classification labels
% numperms1 times and collecting the power spectra from the resulting AC
% maps. If config.figure = 'yes', displays stats results on the single
% subject level.
% To enable second level testing, create one output structure per
% participant (e.g. TGMstat1{currentsubject}).
%
% Use:
% [stats1{subj}] = bt_TGMstatslevel1(config, bt_data, bt_TGMquant)
%
% Input Arguments:
% config
%   - mvpacfg        % Load the same cfg file as used to generate empirical
%                    % TGM. Critical: difference in shuffle and empirical
%                    % data should not be caused by differences in
%                    % classification parameters.
%                    %
%   - numperms1      % Number of permutations on the first statistical
%                    % level.
%                    %
%   - normalize      % Normalize empirical and shuffled TGMs by the mean
%                    % and std of shuffled TGMs (Default: yes)
%                    %
%   - statsrange     % Range of recurrence rates to be statistically tested
%                    % in the TGM.
%                    %
%   - figure         % 'yes' or 'no': display statistical results
%                    %
% bt_data            % Data structure obtained from bt_TGMquant. Contains:
%                    % TGM, AC map, FFT information of the AC map, and
%                    % config details saved for later retrieval.
%                    %
% bt_TGMquant        %  TGM obtained by mv_classify_timextime
%                    %
% Output:
% stats1             % Output structure which contains power spectra of
%                    % the empirical data, permutation data, and the
%                    % associated frequency vector.

%% Get information
numperms1 = config.numperms1;                             % Number of first level permutations
warpfreq = bt_TGMquant.warpfreq;                          % Warped frequency (frequency of the carrier)
TGM = bt_TGMquant.TGM;                                    % Time Generalization Matrix of the data
refdimension = bt_TGMquant.refdimension;                  % Reference dimension used
clabel = config.clabel;                                   % Classification labels
cfg_mv = config.mvpacfg;                                  % MVPA Light configuration structured used to obtain TGM
if isfield(config,'normalize')
    normalize = config.normalize;                         % Normalize empirical and shuffled TGMs by the mean and std of shuffled TGMs
else
    normalize = 'yes';
end

% Set up recurrence range over which stats will be applied
if isfield(config,'statsrange')
    statsrange = config.statsrange(1):config.statsrange(end);
else
    statsrange = 1:30;
end

% Adjust to be a factor of warped frequency in case of brain time ref dimension
if strcmp(refdimension.dim,'braintime')
    statsrange = statsrange/warpfreq;
end

%% statistically test TGM
% FIRST LEVEL PERMUTATION
% % Pre-allocate
fullspec_shuff = zeros(1,numel(statsrange));
permTGM = zeros(numperms1,size(TGM,1),size(TGM,2));

% First level permutations
for perm1 = 1:numperms1
    fprintf('First level permutation number %i\n', perm1);
    clabel = clabel(randperm(numel(clabel)));
    [permTGM(perm1,:,:),~] = mv_classify_timextime(cfg_mv, bt_data.trial, clabel);
end

% If normalize, calculate mean and std and correct
if strcmp(normalize,'yes')
    mn_permTGM = mean(permTGM,1);
    mn = mean(mn_permTGM(:));
    sd = std(mn_permTGM(:));
    
    for perm1 = 1:numperms1 % Normalize shuffled data
        permTGM(perm1,:,:) = (permTGM(perm1,:,:)-mn)./sd;
    end
    
    TGM = (TGM-mn)./sd; % Normalize empirical data
end

% Analyze first level permutation
for perm1 = 1:numperms1
    
    % Calculate autocorrelation map (AC)
    ac=autocorr2d(squeeze(permTGM(perm1,:,:)));
    
    % Run FFT over all rows and columns of the AC map
    nvecs=numel(ac(:,1));
    
    % Perform FFT over one row to get f and find out statsrange indices
    if perm1 == 1
        [~,f]=Powspek(ac(1,:),nvecs/refdimension.value);
        l = nearest(f,statsrange(1)); %minimum frequency to be tested
        h = nearest(f,statsrange(end)); %maximum frequency to be tested
        srange = l:h;
    end
    
    for vec=1:nvecs
        %1st dimenssion
        [PS,f]=Powspek(ac(vec,:),nvecs/refdimension.value);
        PS1(vec,:) = PS(srange);
        
        %2nd dimension
        [PS,f]=Powspek(ac(:,vec),nvecs/refdimension.value);
        PS2(vec,:) = PS(srange);
        
    end
    avg_PS = mean(PS1,1)+mean(PS2,1); %Mean power spectra
    fullspec_shuff(perm1,:) = avg_PS;
end

f=f(l:h); %filter frequency vector based on range of interest

% EMPIRICAL DATA
% Calculate autocorrelation map (AC)
ac=autocorr2d(TGM);

% Size of all rows and columns
nvecs=numel(ac(:,1));

% Pre-allocate
PS1 = zeros(nvecs,numel(srange));
PS2 = zeros(nvecs,numel(srange));

% Run FFT over all rows and columns of the AC map
for vec=1:nvecs
    %1st dimenssion
    [PS,f]=Powspek(ac(vec,:),nvecs/refdimension.value);
    PS1(vec,:) = PS(srange);
    
    %2nd dimension
    [PS,f]=Powspek(ac(:,vec),nvecs/refdimension.value);
    PS2(vec,:) = PS(srange);
end
f=f(l:h); %filter frequency vector based on range of interest
avg_PS = mean(PS1,1)+mean(PS2,1); %Mean power spectra
fullspec_emp = avg_PS;

% Only calculate confidence interval and plot stats if desired
if isfield(config,'figure')
    if strcmp(config.figure,'yes')
        figopt = 1;
    else
        figopt = 0;
    end
else
    figopt = 1; %Default yes
end

if figopt == 1
    %% Create confidence interval for each frequency bin
    createCI = true;
    if numperms1 <20
        warning('on');
        warning('No confidence interval will be displayed as the number of first level permutations is too low (<20)')
        createCI = false;
    end
    
    if createCI == true
        for f_ind = 1:numel(f)
            % Confidence interval
            low_CI(f_ind,:) = prctile(fullspec_shuff(:,f_ind),2.5);
            hi_CI(f_ind,:) = prctile(fullspec_shuff(:,f_ind),97.5);
        end
    end
    
    %% Plot results
    figure;hold on;set(gcf, 'WindowState', 'maximized'); % create full screen figure

    if strcmp(refdimension.dim,'braintime') % Only for brain time, separate warped frequency
        subplot(1,10,1:3)
        wfreq = nearest(f,1); %Find the warped frequency (1 Hz)
        plot(fullspec_emp(wfreq),'o','MarkerSize',6,'MarkerEdgeColor','blue','MarkerFaceColor','blue'); %Plot marker of empirical power
        violinplot(fullspec_shuff(:,wfreq),'test','ShowData',false,'ViolinColor',[0.8 0.8 0.8],'MedianColor',[0 0 0],'BoxColor',[0.5 0.5 0.5],'EdgeColor',[0 0 0],'ViolinAlpha',0.8);
        
        % Set legend
        h = get(gca,'Children');
        l2 = legend(h([9 3]),'Empirical (emp) recurrence power','Permuted (perm) recurrence power');
        set(l2,'Location','best');
        
        % Set up axes
        ylabel('Recurrence power');
        xticklabels(' ');
        xlabel('Warped frequency (1 Hz)');
        title(['1st level recurrence at warped frequency (1Hz)'])
        
        % Adapt font
        set(gca,'FontName','Arial')
        set(gca,'FontSize',16)
        
        % Now plot recurrence power spectrum
        subplot(1,10,5:10)
        hold on
    end
    
    yyaxis left
    p1 = plot(f,fullspec_emp,'LineStyle','-','LineWidth',3,'Color','b'); %Mean across 1st level perms
    p2 = plot(f,mean(fullspec_shuff,1),'LineStyle','-','LineWidth',2,'Color',[0.3 0.3 0.3]); %Mean across 1st level perms
    xlabel('Recurrence frequency')
    ylabel('Mean power across participants')
    
    if strcmp(refdimension.dim,'braintime') %warp freq line is dependent on clock (warped freq) or brain time (1 hz)
        p3 = line([1 1], [0 max(fullspec_emp)],'color',[1 0 1],'LineWidth',4); %Line at warped freq
        xlabel('Recurrence frequency (factor of warped freq)')
    else
        p3 = line([warpfreq warpfreq], [0 max(fullspec_emp)],'color',[1 0 1],'LineWidth',4); %Line at warped freq
        xlabel('Recurrence frequency')
    end
    p3.Color(4) = 0.45;
    
    % Plot confidence interval
    if createCI == true
        c2 = plot(f,low_CI,'LineStyle','-','LineWidth',0.5,'Color','k');
        c3 = plot(f,hi_CI,'LineStyle','-','LineWidth',0.5,'Color','k');
        p4 = patch([f fliplr(f)],[low_CI' fliplr(hi_CI')], 1,'FaceColor', 'black', 'EdgeColor', 'none', 'FaceAlpha', 0.15);
        
        % legend
        l2 = legend([p1 p2 p3 p4],{'Average emp spectrum','Average perm spectrum', 'Warped frequency', 'Conf. interv. perm spectrum'});
    else
        l2 = legend([p1 p2 p3],{'Average emp spectrum','Average perm spectrum','Warped frequency'});
    end
    set(l2,'Location','best')
    
    % add title
    title('Recurrence power spectra (1st level stats)');
    
    % Adapt font
    set(gca,'FontName','Arial')
    set(gca,'FontSize',16)
    
    % Notify user about lack of p-values
    disp('p-values are calculated in the second-level statistics (bt_TGMstatslevel2)');
end

%% Create output structure
stats1.f = f;                                         % Frequency vector
stats1.empTGM = TGM;                                  % Empirical TGM
stats1.shuffTGM = permTGM;                            % Nperm1 shuffled TGMs
stats1.empspec = fullspec_emp;                        % Power spectrum of average empirical data
stats1.shuffspec = fullspec_shuff;                    % Power spectrum of average permutation data
stats1.refdimension = refdimension;                   % Save reference dimension (clock or brain time)