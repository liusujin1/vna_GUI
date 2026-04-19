
% clc;
% close all;
% clear all;

str_dir = 'D:\SynologyDrive\disk_D\lcb\681#10\20251218\';
str_file = {
            '032.vna';
%             '…‹–À023-S05\–¬ºı’ÒµÊ»¶\007.vna';
%             '…‹–À023-S06\20250515\013.vna';
            };
N = length(str_file);
data = cell(N,1);
for m=1:N
    load([str_dir,str_file{m}],'-mat')
    data{m} = SLm;
end
N1 = length(data{1,1}.scmeas(1,1).tdmeas);
t = data{1,1}.tdxvec';
fs = 1/(t(2)-t(1));
td = t(2)-t(1);

k1 = 3;
% k2 = k1;
% k3 = k1;
% stage_acc = data.SLm.scmeas(1).tdmeas*data.SLm.scmeas(1).eu_val*0.001;
frame_acc1 = data{1,1}.scmeas(k1).tdmeas*data{1,1}.scmeas(k1).eu_val;
% frame_acc2 = data{2,1}.scmeas(k2).tdmeas*data{2,1}.scmeas(k2).eu_val;
% frame_acc3 = data{3,1}.scmeas(k3).tdmeas*data{3,1}.scmeas(k3).eu_val;
%% LPF filtersss
% Fpass = 1;
% Fstop = 100;
% Apass = 1;
% Astop = 50;
wn=2*pi*100;
zeta=0.7;
lpf=tf(wn^2,[1,2*zeta*wn,wn^2]);
lpfd= c2d(lpf,td,'t');
% h = fdesign.lowpass('fp,fst,ap,ast',Fpass,Fstop,Apass,Astop,Fs);
% Hd = design(h);

%% data filter
frame_acc_filter1 = filter(lpfd.num{1},lpfd.den{1},frame_acc1);
% frame_acc_filter2 = filter(lpfd.num{1},lpfd.den{1},frame_acc2);
% frame_acc_filter3 = filter(lpfd.num{1},lpfd.den{1},frame_acc3);
%% figure
plotdata1 = frame_acc_filter1;
% plotdata2 = frame_acc_filter2;
% plotdata3 = frame_acc_filter3;

% plotdata1 = frame_acc1;
% plotdata2 = frame_acc2;
% plotdata3 = frame_acc3;

figure
subplot(211)
plot(t,plotdata1,'b');
% hold on
% plot(t,plotdata2,'r');
% hold on
% plot(t,plotdata3,'c');
title(' ±”Úº”ÀŸ∂»')
ylabel('m/s^2');
xlabel('time/s')
xlim([t(1),t(end)])
grid on
% legend('‘≠ºı’ÒµÊ»¶','THD74(12.5mm)','THD74(6.25mm)')
legend('‘≠ºı’ÒµÊ∆¨','–¬ºı’ÒµÊ∆¨','‘≠ºı’ÒµÊ')
subplot(212)
loglog(data{1,1}.fdxvec,data{1,1}.wincor*data{1,1}.scmeas(k1).aspec*data{1,1}.scmeas(k1).eu_val^2/data{1,1}.rbw,'b')
hold on
loglog(data{2,1}.fdxvec,data{2,1}.wincor*data{2,1}.scmeas(k2).aspec*data{2,1}.scmeas(k2).eu_val^2/data{2,1}.rbw,'r')
% hold on
% loglog(data{3,1}.fdxvec,data{3,1}.wincor*data{3,1}.scmeas(k3).aspec*data{3,1}.scmeas(k3).eu_val^2/data{3,1}.rbw,'c')

xlim([data{1,1}.fdxvec(2),data{1,1}.fdxvec(end)])
ylim([1e-11,1e-3])
grid on
set(gca,'yminorgrid','off')
xlabel('Frequence [Hz]')
ylabel('(m/s^2)^2/Hz]')

% N = 8192-5564;
% 
% figure
% [Pxx_frame,f_frame]=periodogram(frame_acc(5565:end,1),hann(N),N,Fs,'onesided');
%     loglog(f_frame,Pxx_frame,'b');
%     hold on
%     loglog([5 150 300 1000],[1e-8 1e-8 1e-7 1e-7],'r')
%     hold on
%     xlim([f_frame(3),f_frame(end)])
%     grid on
%     ylabel('[dB]')
%     xlabel('Frequency[Hz]')1