function [PS,f] = bt_fft(mp,powspecrange,timevec)
% Take input 'mp', which is a TGM, AC map, or TGM diagonal, and put all
% its rows and columns in a FieldTrip data structure. Then, apply a
% Hanning window and perform multitaper FFT.

% Check number of rows and columns
nrows = size(mp,1);
ncols = size(mp,2);

if ncols == 1 % Diag
    mp = mp'; % flip to row vector
    ftdat.trial{1} = mp;
    ftdat.time{1} = timevec;
elseif nrows == 1 % Diag
    ftdat.trial{1} = mp;
    ftdat.time{1} = timevec;

else          % TGM or AC
    for row = 1:nrows % Perform FFT over rows
        ftdat.trial{row} = mp(row,:);
        ftdat.time{row} = timevec;
    end
    for col = 1:ncols % Perform FFT over columns
        ftdat.trial{col+nrows} = mp(col,:);
        ftdat.time{col+nrows} = timevec;
    end
end

ftdat.label = {'dummy'};
ftdat.sampleinfo = [1 size(mp,1)];

% Run Multitaper FFT
cfg = [];
cfg.method      = 'mtmfft';
cfg.output      = 'pow';
cfg.taper       = 'hanning';
cfg.foilim      = [powspecrange(1),powspecrange(end)];
cfg.toi         = timevec;
output          = ft_freqanalysis(cfg, ftdat);

l = nearest(output.freq,powspecrange(1)); %minimum frequency to be tested
h = nearest(output.freq,powspecrange(end)); %maximum frequency to be tested
ps_range = l:h; % this is the range of frequencies desired

PS = output.powspctrm(ps_range);
f = output.freq(ps_range);

end