% Find Wire Patterns for a given target fields using Streamlines of a
% simulated thin wire approximation.
% Works perfectly fine for simple geometries. However, no generalization 
% for arbitrary surfaces
% Example code for a shielded cylindrical geometry
% Units are SI: Meter, Ampere, Tesla, etc.
%
% 2019-11
% Sebastian Littin
% sebastian.littin@uniklinik-freiburg.de


clear all
close all


%% coil description: Cylindrical unshielded coil

plot_all = 1; % set to 1, to optionally plot intermediate steps

% define coil-parameters of the matrix coil: segments_angular, half_length, len_step
CoilDefinition.Partitions = 2;
segments_angular=48;
segments_angular_shield = segments_angular;
half_length=0.6; % 600mm
len_step = 0.015; % 15mm
r_coil = 0.4;  % 400mm coil diameter
r_shield = 0.5;

arc_angle = 360/(segments_angular);
[elm_angle, elm_z] = ndgrid((0:segments_angular-1)*arc_angle, (-half_length:len_step:half_length)); 
CoilDefinition(1).num_elements=size(elm_angle);
elm_angle_shift = elm_angle([2:end,1],:);

% Define Cylindrical Main Surface

CoilDefinition(1).thin_wire_nodes_start = [cosd(elm_angle(:))*r_coil,sind(elm_angle(:))*r_coil,elm_z(:)];
CoilDefinition(1).thin_wire_nodes_stop = [cosd(elm_angle_shift(:))*r_coil,sind(elm_angle_shift(:))*r_coil,elm_z(:)];

CoilDefinition(1).num_elements = size(elm_angle);



% Define Shielding Surface
arc_angle = 360/(segments_angular_shield);
[elm_angle_shield, elm_z] = ndgrid((0:segments_angular_shield-1)*arc_angle, (-half_length:len_step:half_length));
CoilDefinition(2).num_elements=size(elm_angle_shield);
elm_angle_shift = elm_angle_shield([2:end,1],:);

CoilDefinition(2).thin_wire_nodes_start = [cosd(elm_angle(:))*r_shield,sind(elm_angle(:))*r_shield,elm_z(:)];
CoilDefinition(2).thin_wire_nodes_stop = [cosd(elm_angle_shift(:))*r_shield,sind(elm_angle_shift(:))*r_shield,elm_z(:)];
CoilDefinition(2).num_elements=size(elm_angle_shield);

CoilDefinition(2).num_elements = size(elm_angle_shield);


% Some additional definitions for 3D contour plots
CoilDefinition(1).Radius = r_coil;
CoilDefinition(2).Radius = r_shield;

CoilDefinition(1).Length = half_length*2;
CoilDefinition(2).Length = half_length*2;




% possibility to plot thin wire elements
if plot_all == 1
figure;
hold all
for np=1:2
for n = 1:length(CoilDefinition(np).thin_wire_nodes_start)
plot3([CoilDefinition(np).thin_wire_nodes_start(n,1) CoilDefinition(np).thin_wire_nodes_stop(n,1)], ...
    [CoilDefinition(np).thin_wire_nodes_start(n,2) CoilDefinition(np).thin_wire_nodes_stop(n,2)],...
    [CoilDefinition(np).thin_wire_nodes_start(n,3) CoilDefinition(np).thin_wire_nodes_stop(n,3)])
    
end
end
hold off
axis equal tight
title('Thin-wire current elements');
view([1 1 1])
end


%% Definition of target points in a 3D-volume

% define main target
TargetDefinition.shape = 'sphere';
TargetDefinition.radius = 0.15;
TargetDefinition.resol_radial = 2;
TargetDefinition.resol_angular = 24;
TargetDefinition.strength = 5e-3;
TargetDefinition.direction = 'y';

target_main = Make_Target(TargetDefinition);

% possibility to plot main target
if plot_all == 1
figure; scatter3(target_main.points.x1(:), target_main.points.x2(:), target_main.points.x3(:), ones(size(target_main.points.x1(:)))*25, target_main.field(:))
axis equal tight
title('Main Target Points and Field');
view([1 1 1])
end

TargetDefinition.shape = 'cylinder';
TargetDefinition.radius = 0.65;
TargetDefinition.length = 1.2;
TargetDefinition.resol_radial = 1;
TargetDefinition.resol_angular = 48;
TargetDefinition.resol_length = 24;
TargetDefinition.strength = 0e-3;
TargetDefinition.direction = 'y';

target_shield = Make_Target(TargetDefinition);

% optionally plot shield target
if plot_all == 1
figure; scatter3(target_shield.points.x1(:), target_shield.points.x2(:), target_shield.points.x3(:), ones(size(target_shield.points.x1(:)))*25, target_shield.field(:))
axis equal tight
title('Shielding Target Points and Field');
view([1 1 1])
axis equal tight
end

x1 = [target_main.points.x1(:); target_shield.points.x1(:)];
x2 = [target_main.points.x2(:); target_shield.points.x2(:)];
x3 = [target_main.points.x3(:); target_shield.points.x3(:)];

Points=[x1(:),x2(:),x3(:)];
Target.Points=Points;
num_points=length(Points(:,1));
Target.num_points = num_points;

kn = length(x1)^2;
kp = length(x1);

num_points_main=length(target_main.points.x1);
num_points_shield=length(target_shield.points.x1);


%% Calculate Sensitivity
CoilDefinition(1).StreamDirection = 2;
CoilDefinition(2).StreamDirection = 2;

Sensitivity = ThinWireSensitivity(CoilDefinition, Target);

%% Calculate the unregularized Solution

E_Mat = [Sensitivity(1).ElementFieldsStream Sensitivity(2).ElementFieldsStream];
btarget = [target_main.field(:); target_shield.field(:)];

ElementCurrents_unreg = pinv(E_Mat)*btarget;


%% Plot unregularized current distribution

main_stop = CoilDefinition(1).num_elements(1)*(CoilDefinition(1).num_elements(2)-1);

ElementCurrents(1).Stream = reshape(ElementCurrents_unreg(1:main_stop,:),size(elm_angle)-[0 1]);
ElementCurrents(2).Stream = reshape(ElementCurrents_unreg(main_stop+1:end,:),size(elm_angle)-[0 1]);

if plot_all == 1
figure; set(gcf,'Name','3D coil','Position',[   1   1   1000   500]);
subplot(1,2,1)
imab(ElementCurrents(1).Stream); colorbar; title('a) main layer without regularization');
subplot(1,2,2)
imab(ElementCurrents(2).Stream); colorbar; title('b) shielding layer without regularization');

end
% PlotThinWireStreamFunction3D(CoilDefinition, ElementCurrents)
%% Calculate the regularized Solution
% define Tikhonov Matrix
E_Mat = [Sensitivity(1).ElementFieldsStream Sensitivity(2).ElementFieldsStream];
btarget = [target_main.field(:); target_shield.field(:)];

W = eye(size(Sensitivity(1).ElementFieldsStream,2));

w = W - circshift(W,segments_angular,1);
w(1:2*segments_angular,end-2*segments_angular+1:end) = zeros(2*segments_angular);

w_red = w(:,1:end-segments_angular)';

z = zeros(size(w));
z = zeros(size(w_red));

Reg_mat = [w_red z; z w_red];

tic
ElementCurrents_Reg_Weigh=TikhonovReg_Weigh(E_Mat, btarget, 5e-2, Reg_mat); 
toc


%% Add additional constraints to enforce peripheral elements to be 0

E_Mat = [Sensitivity(1).ElementFieldsStream Sensitivity(2).ElementFieldsStream];

btarget = [target_main.field(:); target_shield.field(:)];


lambda = 1e1;

W = eye(size(Sensitivity(1).ElementFieldsStream ,2));

w = W - circshift(W,segments_angular,2);
w(1:2*segments_angular,end-2*segments_angular+1:end) = zeros(2*segments_angular);

w_ext = [w; [lambda*eye(segments_angular) zeros(segments_angular,size(Sensitivity(1).ElementFieldsStream,2)-segments_angular)];...
        [zeros(segments_angular,size(Sensitivity(1).ElementFieldsStream,2)-segments_angular)  lambda*eye(segments_angular) ]];

w_full = [w_ext  zeros(size(w_ext)); zeros(size(w_ext)) w_ext];
   
ElementCurrents_Reg_Weigh = TikhonovReg_Weigh(E_Mat, btarget, 5e-1, w_full); 



%% Plot currents in 2D

n_cont = 15;

main_stop = CoilDefinition(1).num_elements(1)*(CoilDefinition(1).num_elements(2)-1);

ElementCurrents(1).Stream = reshape(ElementCurrents_Reg_Weigh(1:main_stop,:),size(elm_angle)-[0 1]);
ElementCurrents(2).Stream = reshape(ElementCurrents_Reg_Weigh(main_stop+1:end,:),size(elm_angle)-[0 1]);

cont_max = max(max(ElementCurrents(1).Stream))*1;%0.98;
cont_min = min(min(ElementCurrents(1).Stream))*1;%*0.98;

% figure; set(gcf,'Name','3D coil','Position',[   1   1   1000   500]);
hold all
for nP =1:2
    figure; 
% subplot(1,2,nP)
hold all
imab(ElementCurrents(nP).Stream); colorbar; %title('a) regularized main layer');
[C,H] = contour(ElementCurrents(nP).Stream' ,[cont_min:((abs(cont_max)+abs(cont_min))/n_cont):cont_max],'k','LineWidth', 2);

% subplot(1,2,nP)
% imab(ElementCurrents(2).Stream'); colorbar; title('b) regularized shielding layer');

end
hold off

%% Plot multi layer contours

nP = 1;

PlotCoord = (CoilDefinition(nP).thin_wire_nodes_start + CoilDefinition(nP).thin_wire_nodes_stop)/2;

n_cont = 15;

ElmtsPlot = [reshape(ElementCurrents(nP).Stream,(CoilDefinition(nP).num_elements -[0 1]))];
% Add two radial columns to not miss iso-contours at radial
% interconnections
ElmtsPlot = [ElmtsPlot(end,:); ElmtsPlot; ElmtsPlot(1,:)];
cont_max_main = max(max(ElmtsPlot));
[C1,H1] = contour(ElmtsPlot(:,:)',[-cont_max_main:(2*cont_max_main/n_cont):cont_max_main],'k','LineWidth', 2);

nP = 2;

PlotCoord = (CoilDefinition(nP).thin_wire_nodes_start + CoilDefinition(nP).thin_wire_nodes_stop)/2;

n_cont = 13;

ElmtsPlot = [reshape(ElementCurrents(nP).Stream,(CoilDefinition(nP).num_elements -[0 1]))];% Add two radial columns to not miss iso-contours at radial
% interconnections
ElmtsPlot = [ElmtsPlot(end,:); ElmtsPlot; ElmtsPlot(1,:)];
% cont_max_main = max(max(ElmtsPlot));
[C2,H2] = contour(ElmtsPlot(:,:)',[-cont_max_main:(2*cont_max_main/n_cont):cont_max_main],'k','LineWidth', 2);


%% 3D Plot of the contours

figure; set(gcf,'Name','3D coil','Position',[   1   1   1000   1000]);
hold all

S = contourdata(C1);
ccount = size(S);
nP =1;
for i = 1:ccount(2)
    sx=CoilDefinition(nP).Radius*cos(S(i).xdata/(CoilDefinition(nP).num_elements(1))*2*pi);
    sy=CoilDefinition(nP).Radius.*sin(S(i).xdata/(CoilDefinition(nP).num_elements(1))*2*pi);
    sz=S(i).ydata./length(ElmtsPlot(1,:)')*CoilDefinition(nP).Length - CoilDefinition(nP).Length/2;
    
    plot3(sx,sy,sz,'b','LineWidth', 1)
end

S = contourdata(C2);
ccount = size(S);
nP =2;
for i = 1:ccount(2)
    sx=CoilDefinition(nP).Radius*cos(S(i).xdata/(CoilDefinition(nP).num_elements(1))*2*pi);
    sy=CoilDefinition(nP).Radius.*sin(S(i).xdata/(CoilDefinition(nP).num_elements(1))*2*pi);
    sz=S(i).ydata./length(ElmtsPlot(1,:)')*CoilDefinition(nP).Length - CoilDefinition(nP).Length/2;
    
    plot3(sx,sy,sz,'r','LineWidth', 1)
end

hold off
view([-97 25]);

axis tight equal off
font_size = 12;
set(gca,'fontsize',font_size)

