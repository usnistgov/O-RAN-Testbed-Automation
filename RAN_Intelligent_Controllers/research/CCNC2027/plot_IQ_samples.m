%% IQ Constellation Plot
clear;
clc;

% -------------------------------------------------------------------------
% Configuration
% -------------------------------------------------------------------------

% Available scenarios:
scenario = "AWGN_PLUS5_PL0";
%scenario = "AWGN_0_PL0";
%scenario = "AWGN_MINUS5_PL0";
%scenario = "AWGN_MINUS5_PL25";

% Maximum number of samples considered before duplicate removal
max_points = 2000;

% Marker sizes
marker_size = 15;
inset_marker_size = 15;

% Remove exact duplicate I/Q coordinates.
% This does not change the appearance of opaque black points.
remove_duplicates = true;

% Zoom region for the path-loss figure
zoom_xlim = [-30 30];
zoom_ylim = [-30 30];

% Line width for zoom rectangle, connectors, and inset
zoom_line_width = 1;

% -------------------------------------------------------------------------
% Output directory
% -------------------------------------------------------------------------

output_dir = fileparts(mfilename("fullpath"));

if isempty(output_dir)
    output_dir = pwd;
end

% -------------------------------------------------------------------------
% Select input file
% -------------------------------------------------------------------------

switch scenario
    case "AWGN_PLUS5_PL0"
        filename = "COMBINED_AWGN_5.csv";
        pdfname  = "AWGN_5_PL_0.pdf";

    case "AWGN_0_PL0"
        filename = "COMBINED_AWGN-0.csv";
        pdfname  = "AWGN_0_PL_0.pdf";

    case "AWGN_MINUS5_PL0"
        filename = "COMBINED_AWGN-5.csv";
        pdfname  = "AWGN_-5_PL_0.pdf";

    case "AWGN_MINUS5_PL25"
        filename = "COMBINED_AWGN-5_PL_25.csv";
        pdfname  = "AWGN_-5_PL_25.pdf";

    otherwise
        error("Unknown scenario: %s", scenario);
end

pdfpath = fullfile(output_dir, pdfname);

% -------------------------------------------------------------------------
% Load IQ data
% -------------------------------------------------------------------------

data = readtable(filename, "Delimiter", ";");

I = data.real;
Q = data.imag;

original_count = length(I);

% Uniformly sample across the complete dataset if it exceeds max_points
if length(I) > max_points
    indices = round(linspace(1, length(I), max_points));
    I = I(indices);
    Q = Q(indices);
end

sampled_count = length(I);

% Remove exact duplicate coordinates.
%
% Repeated opaque black markers at exactly the same coordinate are visually
% indistinguishable, but each repetition increases vector-PDF complexity.
if remove_duplicates
    iq_unique = unique([I Q], "rows", "stable");
    I = iq_unique(:,1);
    Q = iq_unique(:,2);
end

fprintf("Original samples:    %d\n", original_count);
fprintf("Samples after limit: %d\n", sampled_count);
fprintf("Vector points drawn: %d\n", length(I));

% -------------------------------------------------------------------------
% Plot
% -------------------------------------------------------------------------

fig = figure( ...
    "Color", "w", ...
    "Position", [100 100 650 430]);

main_ax = axes( ...
    "Parent", fig, ...
    "Position", [0.14 0.22 0.82 0.72]);

% Point markers produce substantially lighter vector PDFs than filled
% scatter markers.
plot(main_ax, I, Q, ...
    "k.", ...
    "MarkerSize", marker_size, ...
    "LineStyle", "none");

xlabel(main_ax, "In-phase (I)", "FontSize", 24);
ylabel(main_ax, "Quadrature (Q)", "FontSize", 24);

grid(main_ax, "on");
box(main_ax, "on");

% Keep I and Q on the same physical scale.
daspect(main_ax, [1 1 1]);

main_ax.FontSize = 24;
main_ax.LineWidth = 1.2;
main_ax.TickDir = "out";
main_ax.GridAlpha = 0.20;
main_ax.XMinorGrid = "off";
main_ax.YMinorGrid = "off";

% -------------------------------------------------------------------------
% Axis configuration
% -------------------------------------------------------------------------

if scenario == "AWGN_MINUS5_PL25"

    % Horizontally shifted parent view while remaining vertically centered.
    xlim(main_ax, [-250 750]);
    ylim(main_ax, [-350 350]);

    xticks(main_ax, [-250 0 250 500 750]);
    yticks(main_ax, [-250 0 250]);

    xtickangle(main_ax, 45);

    % ---------------------------------------------------------------------
    % Zoom-region rectangle
    % ---------------------------------------------------------------------

    rectangle(main_ax, ...
        "Position", [ ...
            zoom_xlim(1), ...
            zoom_ylim(1), ...
            diff(zoom_xlim), ...
            diff(zoom_ylim)], ...
        "EdgeColor", "k", ...
        "LineWidth", zoom_line_width);

    % ---------------------------------------------------------------------
    % Zoomed inset
    % ---------------------------------------------------------------------

    inset_ax = axes( ...
        "Parent", fig, ...
        "Units", "normalized", ...
        "Position", [0.40 0.35 0.54 0.54]);

    % Only send samples that can actually appear inside the inset to the
    % vector renderer.
    zoom_mask = ...
        I >= zoom_xlim(1) & I <= zoom_xlim(2) & ...
        Q >= zoom_ylim(1) & Q <= zoom_ylim(2);

    plot(inset_ax, ...
        I(zoom_mask), ...
        Q(zoom_mask), ...
        "k.", ...
        "MarkerSize", inset_marker_size, ...
        "LineStyle", "none");

    xlim(inset_ax, zoom_xlim);
    ylim(inset_ax, zoom_ylim);

    xticks(inset_ax, [-30 -15 0 15 30]);
    yticks(inset_ax, [-30 -15 0 15 30]);

    daspect(inset_ax, [1 1 1]);
    pbaspect(inset_ax, [1 1 1]);

    grid(inset_ax, "on");
    box(inset_ax, "on");

    inset_ax.FontSize = 18;
    inset_ax.LineWidth = zoom_line_width;
    inset_ax.TickDir = "out";
    inset_ax.GridAlpha = 0.20;
    inset_ax.XMinorGrid = "off";
    inset_ax.YMinorGrid = "off";
    inset_ax.Color = "w";
    inset_ax.XTickLabelRotation = 45;

    % ---------------------------------------------------------------------
    % Zoom connector lines
    % ---------------------------------------------------------------------

    % Rendering must be complete before converting data positions into
    % figure-normalized coordinates.
    drawnow;

    % Left-bottom and left-top corners of zoom rectangle
    [rect_x1, rect_y1] = dataToFigureCoordinates( ...
        main_ax, fig, zoom_xlim(1), zoom_ylim(1));

    [rect_x2, rect_y2] = dataToFigureCoordinates( ...
        main_ax, fig, zoom_xlim(1), zoom_ylim(2));

    % Actual visible plotting box of the inset. This accounts for the
    % square plot-box aspect ratio inside its rectangular axes Position.
    inset_box = getPlotBoxPosition(inset_ax, fig);

    inset_left   = inset_box(1);
    inset_bottom = inset_box(2);
    inset_top    = inset_box(2) + inset_box(4);

    % % Bottom connector
    % annotation(fig, "line", ...
    %     [rect_x1 inset_left], ...
    %     [rect_y1 inset_bottom], ...
    %     "Color", [0.7 0.7 0.7], ...
    %     "LineWidth", zoom_line_width);
    % 
    % % Top connector
    % annotation(fig, "line", ...
    %     [rect_x2 inset_left], ...
    %     [rect_y2 inset_top], ...
    %     "Color", [0.7 0.7 0.7], ...
    %     "LineWidth", zoom_line_width);

else

    xlim(main_ax, [-500 500]);
    ylim(main_ax, [-350 350]);

    xticks(main_ax, [-500 -250 0 250 500]);
    yticks(main_ax, [-250 0 250]);

    xtickangle(main_ax, 45);
end

% -------------------------------------------------------------------------
% Export
% -------------------------------------------------------------------------

drawnow;

exportgraphics(fig, pdfpath, ...
    "ContentType", "vector", ...
    "BackgroundColor", "white");

fprintf("Saved vector PDF to:\n%s\n", pdfpath);

% =========================================================================
% Local functions
% =========================================================================

function [fig_x, fig_y] = dataToFigureCoordinates(ax, fig, x, y)
    % Convert an axes data coordinate into normalized figure coordinates,
    % accounting for the actual plot box after aspect-ratio constraints.

    plot_box = getPlotBoxPosition(ax, fig);

    xl = ax.XLim;
    yl = ax.YLim;

    x_fraction = (x - xl(1)) / diff(xl);
    y_fraction = (y - yl(1)) / diff(yl);

    fig_x = plot_box(1) + x_fraction * plot_box(3);
    fig_y = plot_box(2) + y_fraction * plot_box(4);
end

function plot_box = getPlotBoxPosition(ax, fig)
    % Return the actual visible axes plot box in normalized figure units.
    %
    % axes.Position alone is insufficient when DataAspectRatio or
    % PlotBoxAspectRatio constrains the visible plotting rectangle.

    ax_pixels = getpixelposition(ax, true);
    fig_pixels = getpixelposition(fig, true);

    available_width  = ax_pixels(3);
    available_height = ax_pixels(4);

    % Determine the required physical width/height ratio of the plot box.
    if strcmp(ax.PlotBoxAspectRatioMode, "manual")
        pbar = ax.PlotBoxAspectRatio;
        target_ratio = pbar(1) / pbar(2);

    elseif strcmp(ax.DataAspectRatioMode, "manual")
        dar = ax.DataAspectRatio;

        x_span = diff(ax.XLim);
        y_span = diff(ax.YLim);

        target_ratio = ...
            (x_span / dar(1)) / ...
            (y_span / dar(2));

    else
        target_ratio = available_width / available_height;
    end

    available_ratio = available_width / available_height;

    % Fit the constrained plot box inside the axes Position.
    if available_ratio > target_ratio
        % Height is limiting.
        plot_height = available_height;
        plot_width  = plot_height * target_ratio;

        plot_left   = ax_pixels(1) + ...
            (available_width - plot_width) / 2;
        plot_bottom = ax_pixels(2);

    else
        % Width is limiting.
        plot_width  = available_width;
        plot_height = plot_width / target_ratio;

        plot_left   = ax_pixels(1);
        plot_bottom = ax_pixels(2) + ...
            (available_height - plot_height) / 2;
    end

    plot_box = [ ...
        plot_left   / fig_pixels(3), ...
        plot_bottom / fig_pixels(4), ...
        plot_width  / fig_pixels(3), ...
        plot_height / fig_pixels(4)];
end