% clc;close all ;clear all;

str_dir = 'F:\ai\test_data\diji\µÚÒ»¿é\';
str_file = 'psd1.vna';
load([str_dir,str_file],'-mat');

f = SLm.fdxvec(2:end)';
aspec = zeros(length(f),3);
vspec = aspec;
for m=1:3
    ch = m+1;
    aspec(:,m) = SLm.scmeas(ch).aspec(2:end)*SLm.scmeas(ch).eu_val^2/SLm.rbw;
    vspec(:,m) = aspec(:,m)./(2*pi*f).^2;
end

% figure
% loglog(f,aspec(:,1),'b',...
%        f,aspec(:,2),'g',...
%        f,aspec(:,3),'k')
% xlim([f(1),1000])
% grid on
% set(gca,'yminorgrid','off')
% legend('X','Y','Z','VC C')
% xlabel('Frequency [Hz]')
% ylabel('Acc. PSD [(m/s^2)^2/Hz]')

F=[4 8 80];
VCD=[6.25 6.25 6.25];
VCC=[12.5 12.5 12.5];
VCB=[50 25 25];
VCA=[100 50 50];

[fc,fc_l,fc_u,fc_str,fc_l_str,fc_u_str] = nth_freq_band(3,min(f),max(f));
if max(f)<fc_u(end)
    fc = fc(1:end-1);
    fc_l = fc_l(1:end-1);
    fc_u = fc_u(1:end-1);
end

vspec31 = zeros(length(fc),3);
for m=1:length(fc)
    idx = find(f>=fc_l(m) & f<=fc_u(m));
    for n=1:3        
        vspec31(m,n) = sqrt( sum(vspec(idx,n)*SLm.rbw) );
    end
end
figure
loglog(fc,vspec31(:,1)*1e6,'b.-',...
       fc,vspec31(:,2)*1e6,'g.-',...
       fc,vspec31(:,3)*1e6,'k.-')
xlabel('One-Third Octave Band Frequency [Hz]')
ylabel('RMS Velocity [um/s]')
hold on
loglog(F,VCC,'r','linewidth',2)
% hold on
% loglog(F,VCB,'b','linewidth',2)
% hold on
% loglog(F,VCA,'k','linewidth',2)
legend('X','Y','Z','VC C','VC B','VC A','Location','northwest')
xlim([1 100]),ylim([0.1,100])
set(gca,'xticklabel',{1,10,100})
grid on

