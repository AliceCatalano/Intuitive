function GraspEditor()

THRESH_MTML  = -0.5;
THRESH_MTMR  = -0.8;
MIN_GRASP_S  =  0.3;
COLOR_MTML   = [0.557, 0.267, 0.678];
COLOR_MTMR   = [0.902, 0.494, 0.133];
COLOR_EN     = [0.180, 0.800, 0.443];
COLOR_EX     = [0.922, 0.271, 0.271];
COLORS_PT    = lines(4);

data_root = '/home/acatalano/Desktop/Intuitive/DataStructures';
mat_times = '/home/acatalano/Desktop/Intuitive/DataStructures/NeedlePassageTimes_IE20.mat';
subjects  = {'IE01','IE02','IE03','IE04','IE05','IE07','IE08','IE09','IE10','IE11'};

subj_choice = listdlg('PromptString','Select subject:','SelectionMode','single','ListString',subjects,'ListSize',[200 200]);
if isempty(subj_choice), return; end
subj_name = subjects{subj_choice};
s_idx = subj_choice;

rep_list = arrayfun(@(x) sprintf('Rep %02d',x), 1:20, 'UniformOutput',false);
rep_choice = listdlg('PromptString','Select repetition:', ...
    'SelectionMode','single','ListString',rep_list,'ListSize',[200 200]);
if isempty(rep_choice), return; end
scenario_num = rep_choice;   % reuse scenario_num variable, now = repetition index

mat_file = fullfile(data_root, sprintf('grasp_Exp_T2_%s_rep%02d.mat', subj_name, scenario_num));
if ~exist(mat_file,'file')
    errordlg(sprintf('File not found:\n%s', mat_file)); return;
end

d  = load(mat_file);
t0 = min([d.mtml_time(1), d.mtmr_time(1), d.needle_time(1)]);
mtml_t  = d.mtml_time - t0;
mtmr_t  = d.mtmr_time - t0;
t_end   = max(mtml_t(end), mtmr_t(end));

%% Load entry/exit times for this subject/scenario
entry_t = nan(1,4);
exit_t  = nan(1,4);
if exist(mat_times,'file')
    T = load(mat_times,'EntryTimes','ExitTimes','subjects');
    if isfield(T,'EntryTimes') && s_idx <= size(T.EntryTimes,1)
        entry_t = squeeze(T.EntryTimes(s_idx, scenario_num, :))';
        exit_t  = squeeze(T.ExitTimes(s_idx,  scenario_num, :))';
    end
end

%% Automatic detection from threshold crossings
[auto_mtml_gs, auto_mtml_ge] = detect_grasps(mtml_t, d.mtml_position, THRESH_MTML, MIN_GRASP_S);
[auto_mtmr_gs, auto_mtmr_ge] = detect_grasps(mtmr_t, d.mtmr_position, THRESH_MTMR, MIN_GRASP_S);

mtml_gs = auto_mtml_gs;
mtml_ge = auto_mtml_ge;
mtmr_gs = auto_mtmr_gs;
mtmr_ge = auto_mtmr_ge;

fprintf('%s Scn%d: auto-detected %d MTML grasps, %d MTMR grasps\n', ...
    subj_name, scenario_num, numel(mtml_gs), numel(mtmr_gs));

active_hand   = [];
click_state   = 0;
pending_start = NaN;
h_preview     = [];
selected_hand = [];
selected_idx  = [];

fig = figure('Name', sprintf('Grasp Editor — %s Rep%d', subj_name, scenario_num), ...
    'NumberTitle','off','Position',[2000 2000 1500 860]);

ax1 = axes('Parent',fig,'Position',[0.05 0.56 0.88 0.36]);
ax2 = axes('Parent',fig,'Position',[0.05 0.14 0.88 0.36]);

btn_y = 0.04; btn_h = 0.06;
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.05 btn_y 0.11 btn_h],'String','Add MTML grasp', ...
    'FontSize',8,'BackgroundColor',[0.85 0.75 0.95],'Callback',@(~,~) arm('MTML'));
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.17 btn_y 0.11 btn_h],'String','Add MTMR grasp', ...
    'FontSize',8,'BackgroundColor',[0.98 0.88 0.75],'Callback',@(~,~) arm('MTMR'));
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.29 btn_y 0.09 btn_h],'String','Delete selected', ...
    'FontSize',8,'BackgroundColor',[1 0.75 0.75],'Callback',@delete_cb);
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.39 btn_y 0.09 btn_h],'String','Merge selected', ...
    'FontSize',8,'BackgroundColor',[0.75 0.88 1.00],'Callback',@merge_cb);
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.49 btn_y 0.09 btn_h],'String','Reset to auto', ...
    'FontSize',8,'BackgroundColor',[1.00 0.95 0.75],'Callback',@reset_cb);
uicontrol('Parent',fig,'Style','pushbutton','Units','normalized', ...
    'Position',[0.59 btn_y 0.09 btn_h],'String','Save & close', ...
    'FontSize',8,'BackgroundColor',[0.75 0.95 0.75],'Callback',@save_cb);

status_label = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
    'Position',[0.69 btn_y 0.30 btn_h], ...
    'String','Click shaded interval to select. Use buttons to edit.', ...
    'FontSize',8,'HorizontalAlignment','left');

set(fig,'WindowButtonMotionFcn',@motion_cb);
set(fig,'WindowButtonDownFcn',  @click_cb);
set(fig,'KeyPressFcn',          @key_cb);

redraw();

    %% REDRAW
    function redraw()
        cla(ax1); hold(ax1,'on');
        plot(ax1, mtml_t, d.mtml_position,'Color',COLOR_MTML,'LineWidth',1.2,'DisplayName','MTML');
        yline(ax1, THRESH_MTML,'--','Color',[0.8 0 0],'LineWidth',1.0,'DisplayName',sprintf('Grasp<%.1f',THRESH_MTML));
        draw_point_lines(ax1, entry_t, exit_t, COLORS_PT);
        draw_grasps(ax1, mtml_gs, mtml_ge, COLOR_MTML, 'ML', 'MTML');
        ylabel(ax1,'rad');
        title(ax1, sprintf('MTML — %d grasps (thresh=%.1f)  |  click interval to select', numel(mtml_gs), THRESH_MTML));
        grid(ax1,'on'); xlim(ax1,[0 t_end]); ylim(ax1,[-1.5 1.0]);
        legend(ax1,'Location','northeast','FontSize',7);
        hold(ax1,'off');

        cla(ax2); hold(ax2,'on');
        plot(ax2, mtmr_t, d.mtmr_position,'Color',COLOR_MTMR,'LineWidth',1.2,'DisplayName','MTMR');
        yline(ax2, THRESH_MTMR,'--','Color',[0.8 0 0],'LineWidth',1.0,'DisplayName',sprintf('Grasp<%.1f',THRESH_MTMR));
        draw_point_lines(ax2, entry_t, exit_t, COLORS_PT);
        draw_grasps(ax2, mtmr_gs, mtmr_ge, COLOR_MTMR, 'MR', 'MTMR');
        ylabel(ax2,'rad'); xlabel(ax2,'Time (s)');
        title(ax2, sprintf('MTMR — %d grasps (thresh=%.1f)', numel(mtmr_gs), THRESH_MTMR));
        grid(ax2,'on'); xlim(ax2,[0 t_end]); ylim(ax2,[-1.5 1.0]);
        legend(ax2,'Location','northeast','FontSize',7);
        hold(ax2,'off');

        linkaxes([ax1,ax2],'x');

        if ~isempty(selected_idx)
            highlight_selected();
        end
    end

    function draw_grasps(ax, gs, ge, color, prefix, hand_label)
        yl = ylim(ax);
        for i = 1:numel(gs)
            ph = patch(ax,[gs(i),ge(i),ge(i),gs(i)],[yl(1),yl(1),yl(2),yl(2)], ...
                color,'FaceAlpha',0.22,'EdgeColor',color,'LineWidth',1.2,'HandleVisibility','off');
            set(ph,'ButtonDownFcn',@(~,~) select_grasp(hand_label,i));
            text(ax, gs(i)+0.15, yl(1)+0.88*diff(yl), ...
                sprintf('%s%d\n%.1fs',prefix,i,ge(i)-gs(i)), ...
                'Color',color,'FontSize',7,'FontWeight','bold', ...
                'ButtonDownFcn',@(~,~) select_grasp(hand_label,i));
        end
    end

    function draw_point_lines(ax, en, ex, cols)
        yl = [-1.5 1.0];
        for i = 1:4
            if ~isnan(en(i))
                xline(ax, en(i),'--','Color',cols(i,:),'LineWidth',1.5,'HandleVisibility','off');
                text(ax, en(i)+0.1, yl(1)+0.70*diff(yl), sprintf('En%d',i), ...
                    'Color',cols(i,:),'FontSize',7,'FontWeight','bold');
            end
            if ~isnan(ex(i))
                xline(ax, ex(i),':','Color',cols(i,:),'LineWidth',1.5,'HandleVisibility','off');
                text(ax, ex(i)+0.1, yl(1)+0.60*diff(yl), sprintf('Ex%d',i), ...
                    'Color',cols(i,:),'FontSize',7,'FontWeight','bold');
            end
        end
    end

    function highlight_selected()
        if strcmp(selected_hand,'MTML'), ax=ax1; gs=mtml_gs; ge=mtml_ge; col=COLOR_MTML;
        else,                            ax=ax2; gs=mtmr_gs; ge=mtmr_ge; col=COLOR_MTMR;
        end
        if selected_idx<1||selected_idx>numel(gs), selected_idx=[]; return; end
        hold(ax,'on');
        yl=ylim(ax);
        patch(ax,[gs(selected_idx),ge(selected_idx),ge(selected_idx),gs(selected_idx)], ...
            [yl(1),yl(1),yl(2),yl(2)],col,'FaceAlpha',0.55,'EdgeColor','k','LineWidth',2.5,'HandleVisibility','off');
        hold(ax,'off');
        set(status_label,'String', ...
            sprintf('Selected: %s #%d  [%.2f — %.2f s]  dur=%.2fs  |  DEL=delete  M=merge with next', ...
            selected_hand, selected_idx, gs(selected_idx), ge(selected_idx), ...
            ge(selected_idx)-gs(selected_idx)));
    end

    %% SELECT
    function select_grasp(hand, idx)
        selected_hand = hand;
        selected_idx  = idx;
        redraw();
    end

    %% ARM for adding
    function arm(hand)
        active_hand   = hand;
        click_state   = 1;
        pending_start = NaN;
        selected_hand = []; selected_idx = [];
        delete(h_preview); h_preview = [];
        set(status_label,'String',sprintf('ARMED %s — click START time', hand));
    end

    %% CLICK
    function click_cb(~,~)
        if isempty(active_hand), return; end
        if strcmp(active_hand,'MTML'), ax_active=ax1; else, ax_active=ax2; end
        cp = get(ax_active,'CurrentPoint');
        t_clicked = cp(1,1);
        if t_clicked<0||t_clicked>t_end, return; end

        if click_state==1
            pending_start = t_clicked;
            click_state   = 2;
            set(status_label,'String',sprintf('%s START=%.2fs — click END time', active_hand, pending_start));

        elseif click_state==2
            t_end_new = t_clicked;
            if t_end_new<=pending_start
                set(status_label,'String','End must be after start — click END again'); return;
            end
            delete(h_preview); h_preview=[];
            if strcmp(active_hand,'MTML')
                mtml_gs(end+1)=pending_start; mtml_ge(end+1)=t_end_new;
                [mtml_gs,ord]=sort(mtml_gs); mtml_ge=mtml_ge(ord);
            else
                mtmr_gs(end+1)=pending_start; mtmr_ge(end+1)=t_end_new;
                [mtmr_gs,ord]=sort(mtmr_gs); mtmr_ge=mtmr_ge(ord);
            end
            click_state=0; active_hand=[]; pending_start=NaN;
            redraw();
            set(status_label,'String','Interval added.');
        end
    end

    %% MOTION preview
    function motion_cb(~,~)
        if click_state~=2||isnan(pending_start), return; end
        if strcmp(active_hand,'MTML'), ax_active=ax1; col=COLOR_MTML;
        else,                          ax_active=ax2; col=COLOR_MTMR;
        end
        cp=get(ax_active,'CurrentPoint'); t_now=cp(1,1);
        if t_now<=pending_start, return; end
        delete(h_preview);
        hold(ax_active,'on');
        yl=ylim(ax_active);
        h_preview=patch(ax_active,[pending_start,t_now,t_now,pending_start], ...
            [yl(1),yl(1),yl(2),yl(2)],col,'FaceAlpha',0.15,'EdgeColor',col,'LineWidth',2,'LineStyle','--','HandleVisibility','off');
        hold(ax_active,'off');
        drawnow limitrate;
    end

    %% DELETE
    function delete_cb(~,~)
        if isempty(selected_idx)
            set(status_label,'String','No grasp selected — click on a shaded interval first.'); return;
        end
        if strcmp(selected_hand,'MTML')
            mtml_gs(selected_idx)=[]; mtml_ge(selected_idx)=[];
        else
            mtmr_gs(selected_idx)=[]; mtmr_ge(selected_idx)=[];
        end
        selected_idx=[]; redraw();
        set(status_label,'String','Deleted.');
    end

    %% MERGE selected with next
    function merge_cb(~,~)
        if isempty(selected_idx)
            set(status_label,'String','No grasp selected.'); return;
        end
        if strcmp(selected_hand,'MTML'), gs=mtml_gs; ge=mtml_ge;
        else,                            gs=mtmr_gs; ge=mtmr_ge;
        end
        if selected_idx>=numel(gs)
            set(status_label,'String','No next grasp to merge with.'); return;
        end
        new_s = gs(selected_idx);
        new_e = ge(selected_idx+1);
        gs(selected_idx)=[]; ge(selected_idx)=[];
        gs(selected_idx)=[]; ge(selected_idx)=[];
        gs=[gs(1:selected_idx-1), new_s, gs(selected_idx:end)];
        ge=[ge(1:selected_idx-1), new_e, ge(selected_idx:end)];
        if strcmp(selected_hand,'MTML'), mtml_gs=gs; mtml_ge=ge;
        else,                            mtmr_gs=gs; mtmr_ge=ge;
        end
        selected_idx=[]; redraw();
        set(status_label,'String','Merged.');
    end

    %% RESET to automatic detection
    function reset_cb(~,~)
        mtml_gs = auto_mtml_gs; mtml_ge = auto_mtml_ge;
        mtmr_gs = auto_mtmr_gs; mtmr_ge = auto_mtmr_ge;
        selected_idx=[]; redraw();
        set(status_label,'String','Reset to automatic detection.');
    end

    %% KEYBOARD
    function key_cb(~,evt)
        if strcmp(evt.Key,'delete')||strcmp(evt.Key,'backspace'), delete_cb();
        elseif strcmp(evt.Key,'m'), merge_cb();
        end
    end

    % SAVE
    function save_cb(~,~)
        d.mtml_grasp_start = mtml_gs + t0;
        d.mtml_grasp_end   = mtml_ge + t0;
        d.mtmr_grasp_start = mtmr_gs + t0;
        d.mtmr_grasp_end   = mtmr_ge + t0;
        save(mat_file,'-struct','d');
        fprintf('Saved: %s  MTML=%d  MTMR=%d\n', mat_file, numel(mtml_gs), numel(mtmr_gs));
        set(status_label,'String',sprintf('Saved. MTML=%d  MTMR=%d', numel(mtml_gs), numel(mtmr_gs)));
        delete(fig);
    end

end

% AUTOMATIC DETECTION
function [gs, ge] = detect_grasps(t, pos, thresh, min_dur)
    t    = t(:);
    pos  = pos(:);
    below = pos < thresh;
    trans  = diff([false; below; false]);
    starts = find(trans ==  1);
    ends   = find(trans == -1) - 1;
    gs = []; ge = [];
    for k = 1:numel(starts)
        dur = t(ends(k)) - t(starts(k));
        if dur >= min_dur
            gs(end+1) = t(starts(k)); %#ok<AGROW>
            ge(end+1) = t(ends(k));   %#ok<AGROW>
        end
    end
end