%% Load Data
clc;close all ;clear all;
strdir = '\\Li_nas\home\客户方\500\211911\地基测试\正常测试\S\';
strfile = '2（WH右上角）.vna';
% strfile = '003mid_sensor_mid_hanmmer.vna';
load([strdir,strfile],'-mat');

% freq = SLm.fdxvec(2:end)'; % exclude the first frequency: 0 Hz
% resp = SLm.xcmeas(1,2).xfer(2:end)*SLm.scmeas(2).eu_val/SLm.scmeas(1).eu_val;
% coh = SLm.xcmeas(1,2).coh(2:end);

freq = SLm.fdxvec(2:end)'; % exclude the first frequency: 0 Hz
% resp = SLm.xcmeas(1,2).xfer(2:end)*SLm.scmeas(2).eu_val/SLm.scmeas(1).eu_val;
% resp = 1./(SLm.xcmeas(1,4).xfer(2:end)./(2*pi*freq).^2*SLm.scmeas(4).eu_val/SLm.scmeas(1).eu_val);

resp = 1./(SLm.xcmeas(1,4).xfer(2:end)./(2*pi*freq).^2*SLm.scmeas(4).eu_val/SLm.scmeas(1).eu_val);
coh = SLm.xcmeas(1,4).coh(2:end);

% resp = 1./(SLm.xcmeas(1,2).xfer(2:end)./(2*pi*freq).^2*SLm.scmeas(2).eu_val/SLm.scmeas(1).eu_val);
% resp1 = 1./(SLm.xcmeas(1,3).xfer(2:end)./(2*pi*freq).^2*SLm.scmeas(3).eu_val/SLm.scmeas(1).eu_val);
% coh = SLm.xcmeas(1,2).coh(2:end);


% freq = SLm.fdxvec(2:end)'; % exclude the first frequency: 0 Hz
% resp = SLm.xcmeas(1,3).xfer(2:end)*SLm.scmeas(3).eu_val/SLm.scmeas(1).eu_val;
% coh = SLm.xcmeas(1,3).coh(2:end);

h = figure;
% subplot(212)
% semilogx(freq,coh)
% grid on
% xlim([freq(1),freq(end)])
% xlabel('Frequency [Hz]')
% ylabel('Coherence')

% subplot(211)
% semilogx(freq,20*log10(abs(resp)))
loglog(freq,abs(resp))
% hold on
% loglog(freq,abs(resp1),'b')
% loglog(freq,abs(resp)./(2*pi*freq).^2)
grid on
xlim([freq(1),freq(end)])
ylim([10^2,10^12])
ylabel('Magnitude [N/m]')
hold on
%% Select frequency points for fitting, and perform fitting
% fit_freq = [100,140];
% % fit_freq = [120,180];
% % fit_freq = [90,120];
% % fit_freq = [30,80];
% rg = find((freq>=fit_freq(1)) & (freq <=fit_freq(2)));
% w = 2*pi*freq(rg);
% y = abs(resp(rg));
% A = w.^2;
% b = y;
% 
% k = 1/(A\b);

% semilogx(freq(rg),20*log10(w.^2/k),'r','linewidth',2)
loglog([0.1,1280],[10^8,10^8],'r','linewidth',2)
% title(sprintf('Stiffness: %.2E N/m',k),'fontsize',16)
title(sprintf('Dynamic stiffness'),'fontsize',16)
% legend('Measurement(X)','Measurement(Y)','Specification(10^8 N/m)','location','northwest')
legend('Measurement','Specification(10^8 N/m)','location','northwest')