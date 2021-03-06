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
% 

plot_all = 1; % set to 1, to optionally plot intermediate steps
CoilDefinition.Partitions = 2;

half_length_z=0.3; % 600mm => length-z 0.6m
len_step_z = 0.01; % 10mm => step-length-z 1cm
half_length_x=0.3; % 500mm => length-x 0.6m
len_step_x = 0.01; % 10mm => step-length-x 1cm
y_offset = 0.4/2;




length_x=2*half_length_x;
length_z=2*half_length_z;

CoilDefinition(1).Length = [length_x, length_z];
CoilDefinition(2).Length = [length_x, length_z];

[elm_x, elm_y, elm_z] = ndgrid(-half_length_x:len_step_x:half_length_x, y_offset, -half_length_z:len_step_z:half_length_z); 
num_elements=[size(elm_x,1) size(elm_x,3)];

CoilDefinition(1).thin_wire_nodes_start = [elm_x(:)-len_step_x/2,elm_y(:),elm_z(:)];
CoilDefinition(1).thin_wire_nodes_stop = [elm_x(:)+len_step_x/2,elm_y(:),elm_z(:)];

[elm_x, elm_y, elm_z] = ndgrid(-half_length_x:len_step_x:half_length_x, -y_offset, -half_length_z:len_step_z:half_length_z); 
CoilDefinition(1).num_elements=num_elements;


CoilDefinition(2).thin_wire_nodes_start = [elm_x(:)-len_step_x/2,elm_y(:),elm_z(:)];
CoilDefinition(2).thin_wire_nodes_stop = [elm_x(:)+len_step_x/2,elm_y(:),elm_z(:)];

CoilDefinition(2).num_elements=num_elements;

%%


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
TargetDefinition.resol_angular = 64;
TargetDefinition.strength = 5e-3;
TargetDefinition.direction = 'z'; % Direction of constant targe gradient

target_main = Make_Target(TargetDefinition);

% possibility to plot main target
if plot_all == 1
figure; scatter3(target_main.points.x1(:), target_main.points.x2(:), target_main.points.x3(:), ones(size(target_main.points.x1(:)))*25, target_main.field(:))
axis equal tight
title('Main Target Points and Field');
view([1 1 1])
end


x1 = [target_main.points.x1(:)];% target_shield.points.x1(:)];
x2 = [target_main.points.x2(:)];%; target_shield.points.x2(:)];
x3 = [target_main.points.x3(:)];%; target_shield.points.x3(:)];

Points=[x1(:),x2(:),x3(:)];
Target.Points=Points;
num_points=length(Points(:,1));
Target.num_points = num_points;

kn = length(x1)^2;
kp = length(x1);

num_points_main=length(target_main.points.x1);
% num_points_shield=length(target_shield.points.x1);


%% Calculate Sensitivity
CoilDefinition(1).StreamDirection = 2;
CoilDefinition(2).StreamDirection = 2;

Sensitivity = ThinWireSensitivity(CoilDefinition, Target);


%% Add additional constraints to enforce peripheral elements to be 0

E_Mat = [Sensitivity(1).ElementFieldsStream Sensitivity(2).ElementFieldsStream];

btarget = [target_main.field(:)];
% btarget = target_points.field;

lambda1 = 1e2;
lambda2 = 1e2;

% E_Mat = Sensitivity(1).ElementFieldsStream(:,:);
W = eye(size(Sensitivity(1).ElementFieldsStream ,2));

w = W - circshift(W,num_elements(1),2);
w(1:2*num_elements(1),end-2*num_elements(1)+1:end) = zeros(2*num_elements(1));



w_ext = [w; [lambda1*eye(num_elements(1)) zeros(num_elements(1),size(Sensitivity(1).ElementFieldsStream,2)-num_elements(1))];...
        [zeros(num_elements(1),size(Sensitivity(1).ElementFieldsStream,2)-num_elements(1))  lambda1*eye(num_elements(1)) ]];

w_ext2 = zeros(1,size(w,2));
w_ext2(1,1) = lambda2;

w_extend_l = zeros(num_elements(2)-1,size(w,2));

for n_ex = 1:num_elements(2)-1
w_extend_l(n_ex,:) = circshift(w_ext2,n_ex*(num_elements(1)),2); 
end
w_extend_r = circshift(w_extend_l,num_elements(1)-1,2);

w_full = [w_ext  zeros(size(w_ext)); zeros(size(w_ext)) w_ext; w_extend_l zeros(size(w_extend_l));...
    w_extend_r zeros(size(w_extend_r)); zeros(size(w_extend_r)) w_extend_l; zeros(size(w_extend_r)) w_extend_r];

ElementCurrents_Reg_Weigh = TikhonovReg_Weigh(E_Mat, btarget, 15e-1, w_full); 

% figure; imagesc(w_extend_r);

% figure; imab(reshape(ElementCurrents_Reg_Weigh,size(elm_angle)-[0 1])); colorbar;



%% Plot currents in 2D

n_cont = 15;

main_stop = CoilDefinition(1).num_elements(1)*(CoilDefinition(1).num_elements(2)-1);

ElementCurrents(1).Stream = reshape(ElementCurrents_Reg_Weigh(1:main_stop,:),num_elements-[0 1]);
ElementCurrents(2).Stream = reshape(ElementCurrents_Reg_Weigh(main_stop+1:end,:),num_elements-[0 1]);

figure; set(gcf,'Name','3D coil','Position',[   1   1   1000   500]);
hold all
for nP =1:2

cont_max = max(max(ElementCurrents(nP).Stream))*0.9;
cont_min = min(min(ElementCurrents(nP).Stream))*0.9;    
    
% figure;  %set(gcf,'Name','3D coil','Position',[   1   1   1000   500]);
ElmtsPlot = reshape(ElementCurrents(nP).Stream,(CoilDefinition(nP).num_elements -[0 1]));
ElmtsPlot = [ElmtsPlot(end,:); ElmtsPlot; ElmtsPlot(1,:)];
subplot(1,2,nP)
hold all
imab(ElementCurrents(nP).Stream); %colorbar; %title('a) regularized main layer');
[C,H] = contour(ElementCurrents(nP).Stream' ,[cont_min:((abs(cont_max)+abs(cont_min))/n_cont):cont_max],'k','LineWidth', 2);
% 
% subplot(1,2,nP)
% imab(ElementCurrents(2).Stream'); colorbar; title('b) regularized shielding layer');

end
hold off
% PlotThinWireStreamFunction3D(CoilDefinition, ElementCurrents)
%%
figure; set(gcf,'Name','3D coil','Position',[   1   1   1000   1000]);
hold all

for nP = 1:CoilDefinition(1).Partitions

PlotCoord = (CoilDefinition(nP).thin_wire_nodes_start);% + CoilDefinition(nP).thin_wire_nodes_stop)/2;

sx = reshape(PlotCoord(:,1),CoilDefinition(nP).num_elements);
sy = reshape(PlotCoord(:,2),CoilDefinition(nP).num_elements);
sz = reshape(PlotCoord(:,3),CoilDefinition(nP).num_elements);

if CoilDefinition(1).StreamDirection == 1
    sx = (sx(1:end-1,:) + sx(2:end,:))/2;
    sy = (sy(1:end-1,:) + sy(2:end,:))/2;
    sz = (sz(1:end-1,:) + sz(2:end,:))/2;
elseif CoilDefinition(1).StreamDirection == 2
    sx = (sx(:,1:end-1) + sx(:,2:end))/2;
    sy = (sy(:,1:end-1) + sy(:,2:end))/2;
    sz = (sz(:,1:end-1) + sz(:,2:end))/2;
end

ElmtsPlot = reshape(ElementCurrents(nP).Stream,(CoilDefinition(nP).num_elements -[0 1]));

surf(sx,sy,sz,ElmtsPlot,'EdgeColor','none');%,'FaceColor','interp' );

view([-45 12]);

axis tight equal off
font_size = 12;
set(gca,'fontsize',font_size)
% xlabel('x-Axis [m]');
% ylabel('y-Axis [m]');
% zlabel('z-Axis [m]');
end
hold off


