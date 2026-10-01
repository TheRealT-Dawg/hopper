
ox_density = 1141;   % kg/m^3
fu_density = 800;    % kg/m^3

fu_nu = 1.3e-6;  % m^2/s Fu
ox_nu = 0.17e-6; % m^2/s OX

tank_r = TANKS.singular.radius;
ox_tank_h = TANKS.singular.oxidizer.h;
fu_tank_h = TANKS.singular.fuel.h;

% Baffle design sweep (number, width, thickness), fewest baffles meeting
% the damping targets for fills >= min_fill
baffle_opts.zeta_lat_min = 0.04;
baffle_opts.zeta_ax_min  = 0.15;
baffle_opts.min_fill     = 0.10;
baffle_opts.slosh_amp    = 0.1 * tank_r;   % wall slosh amplitude, m
baffle_opts.objective    = 'count';        % 'count' (fewest baffles) or 'mass'

[ox_baffle, ox_baffle_sweep] = sweepBaffleDesign(IN.propulsion.oxidizer_mass, ...
    ox_density, ox_nu, tank_r, ox_tank_h, baffle_opts);
[fu_baffle, fu_baffle_sweep] = sweepBaffleDesign(IN.propulsion.fuel_mass, ...
    fu_density, fu_nu, tank_r, fu_tank_h, baffle_opts);

ox_baffle_number    = ox_baffle.Nb;
ox_baffle_width     = ox_baffle.w;
ox_baffle_thickness = ox_baffle.t;
fu_baffle_number    = fu_baffle.Nb;
fu_baffle_width     = fu_baffle.w;
fu_baffle_thickness = fu_baffle.t;

tank_names = ["Ox", "Fuel"];
designs = [ox_baffle, fu_baffle];
fprintf('\n=== Baffles (targets: lateral >= %.3f, axial >= %.3f for fill >= %.0f%%) ===\n', ...
    baffle_opts.zeta_lat_min, baffle_opts.zeta_ax_min, 100 * baffle_opts.min_fill);
for i = 1:2
    d = designs(i);
    if d.feasible
        status = "meets targets";
    else
        status = sprintf("TARGETS NOT MET (worst shortfall %.0f%%)", 100 * d.shortfall);
    end
    fprintf('%s: Nb = %d, w = %.1f mm, t = %.1f mm, mass = %.3f kg, min lat = %.4f, min ax = %.4f -> %s\n', ...
        tank_names(i), d.Nb, 1e3 * d.w, 1e3 * d.t, d.mass, d.zeta_lat, d.zeta_ax, status);
end

ox_mass_profile = linspace(0.1, IN.propulsion.oxidizer_mass, 200);
fu_mass_profile = linspace(0.1, IN.propulsion.fuel_mass, 200);

[ox_lateral_damping_ratios] = lateralDampingCalc(ox_mass_profile, ox_density, ox_nu, tank_r, ox_baffle_width, ox_baffle_number, ox_tank_h, ox_baffle_thickness, baffle_opts.slosh_amp);

[fu_lateral_damping_ratios] = lateralDampingCalc(fu_mass_profile, fu_density, fu_nu, tank_r, fu_baffle_width, fu_baffle_number, fu_tank_h, fu_baffle_thickness, baffle_opts.slosh_amp);

[ox_axial_damping_ratios] = axialDampingCalc(ox_mass_profile, ox_density, ox_nu, tank_r, ox_baffle_width, ox_baffle_number, ox_tank_h, ox_baffle_thickness, baffle_opts.slosh_amp);

[fu_axial_damping_ratios] = axialDampingCalc(fu_mass_profile, fu_density, fu_nu, tank_r, fu_baffle_width, fu_baffle_number, fu_tank_h, fu_baffle_thickness, baffle_opts.slosh_amp);

figure
plot(ox_mass_profile, ox_lateral_damping_ratios)
yline(baffle_opts.zeta_lat_min, '--')
xline(baffle_opts.min_fill * IN.propulsion.oxidizer_mass, ':')
xlabel("Ox mass")
ylabel("Lateral Damping Ratio")
title("Lateral Damping Ratio over Ox mass, Number of Baffles: " + ox_baffle_number + " , Baffle width (m): " + ox_baffle_width + " , Baffle thickness (m): " + ox_baffle_thickness)

figure
plot(fu_mass_profile, fu_lateral_damping_ratios)
yline(baffle_opts.zeta_lat_min, '--')
xline(baffle_opts.min_fill * IN.propulsion.fuel_mass, ':')
xlabel("Fuel mass")
ylabel("Lateral Damping Ratio")
title("Lateral Damping Ratio over Fuel mass, Number of Baffles: " + fu_baffle_number + " , Baffle width(m): " + fu_baffle_width + " , Baffle thickness (m): " + fu_baffle_thickness)

figure
plot(ox_mass_profile, ox_axial_damping_ratios)
yline(baffle_opts.zeta_ax_min, '--')
xline(baffle_opts.min_fill * IN.propulsion.oxidizer_mass, ':')
xlabel("Ox mass")
ylabel("Axial Damping Ratio")
title("Axial Damping Ratio over Ox mass, Number of Baffles: " + ox_baffle_number + " , Baffle width (m): " + ox_baffle_width + " , Baffle thickness (m): " + ox_baffle_thickness)

figure
plot(fu_mass_profile, fu_axial_damping_ratios)
yline(baffle_opts.zeta_ax_min, '--')
xline(baffle_opts.min_fill * IN.propulsion.fuel_mass, ':')
xlabel("Fuel mass")
ylabel("Axial Damping Ratio")
title("Axial Damping Ratio over Fuel mass, Number of Baffles: " + fu_baffle_number + " , Baffle width(m): " + fu_baffle_width + " , Baffle thickness (m): " + fu_baffle_thickness)

% Export LUT for sim_setup (baffle_lut.csv) and full design record (.mat)
baffle_lut = table(ox_mass_profile(:), ox_lateral_damping_ratios(:), ox_axial_damping_ratios(:), ...
    fu_mass_profile(:), fu_lateral_damping_ratios(:), fu_axial_damping_ratios(:), ...
    'VariableNames', {'ox_mass_profile', 'ox_lateral_damping_ratios', 'ox_axial_damping_ratios', ...
                      'fu_mass_profile', 'fu_lateral_damping_ratios', 'fu_axial_damping_ratios'});
writetable(baffle_lut, 'baffle_lut.csv');

save('baffle_lut.mat', 'baffle_lut', 'ox_baffle', 'fu_baffle', 'baffle_opts', ...
    'ox_baffle_sweep', 'fu_baffle_sweep', 'tank_r', 'ox_tank_h', 'fu_tank_h');

fprintf('Baffle LUT written to baffle_lut.csv / baffle_lut.mat\n');
