import numpy as np
import plotly.graph_objects as go
from dash import Input, Output, State, callback, no_update, ctx
from app import app_state
from core.signal_proc import (
    butterworth_filter, time_window, fft_spectrum,
    periodogram_psd, vna_psd, convert_quantity_time,
    convert_quantity_psd, get_series_color,
)
from core.spectral import transmissibility_db, coherence, cumulative_rms


@callback(
    Output('graph-main-1', 'figure'),
    Output('graph-main-2', 'figure'),
    Output('graph-main-3', 'figure'),
    Output('held-traces-1', 'data'),
    Output('held-traces-2', 'data'),
    Output('held-traces-3', 'data'),
    Output('status-bar', 'children', allow_duplicate=True),
    Input('btn-plot', 'n_clicks'),
    Input('btn-clear', 'n_clicks'),
    State('data-checklist', 'value'),
    State('dd-plot-type-1', 'value'),
    State('dd-plot-type-2', 'value'),
    State('dd-plot-type-3', 'value'),
    State('input-tstart', 'value'),
    State('input-tend', 'value'),
    State('dd-psd-source', 'value'),
    State('dd-quantity', 'value'),
    State('chk-filter', 'value'),
    State('input-low-cutoff', 'value'),
    State('input-high-cutoff', 'value'),
    State('input-filter-order', 'value'),
    State('chk-hold', 'value'),
    State('held-traces-1', 'data'),
    State('held-traces-2', 'data'),
    State('held-traces-3', 'data'),
    prevent_initial_call=True,
)
def plot_main(plot_clicks, clear_clicks,
              selected_ids, pt1, pt2, pt3,
              t_start, t_end,
              psd_source, quantity,
              filter_flags, low_cutoff, high_cutoff, filter_order,
              hold_flags,
              held1, held2, held3):

    trigger = ctx.triggered_id

    if trigger == 'btn-clear':
        empty = _empty_fig()
        return empty, empty, empty, None, None, None, 'Plots cleared'

    if trigger != 'btn-plot':
        return (no_update,) * 7

    if not selected_ids:
        return (no_update,) * 6 + ('Select at least one channel',)

    params = _build_params(t_start, t_end, psd_source, quantity,
                           filter_flags, low_cutoff, high_cutoff, filter_order)

    hold_on = 'hold' in (hold_flags or [])
    plot_types = [pt1, pt2, pt3]
    held_data = [held1, held2, held3]

    tag = _param_tag(params) if hold_on else ''

    figs = []
    new_held = []

    for i, ptype in enumerate(plot_types):
        fig = go.Figure()

        if hold_on and held_data[i]:
            for trace_dict in held_data[i]:
                fig.add_trace(go.Scatter(**trace_dict))

        held_count = len(held_data[i]) if hold_on and held_data[i] else 0
        new_traces = _render_traces(ptype, selected_ids, params, i, held_count)
        for trace in new_traces:
            if tag:
                trace.name = f'{trace.name} [{tag}]'
            fig.add_trace(trace)

        _apply_layout(fig, ptype, params)

        all_traces = []
        if hold_on and held_data[i]:
            all_traces.extend(held_data[i])
        for trace in new_traces:
            all_traces.append({
                'x': list(trace.x) if trace.x is not None else [],
                'y': list(trace.y) if trace.y is not None else [],
                'name': trace.name,
                'mode': 'lines',
                'line': {'width': 1.1, 'color': trace.line.color if trace.line and trace.line.color else None},
            })
        new_held.append(all_traces if hold_on else None)
        figs.append(fig)

    return (*figs, *new_held,
            f'Plotted {len(selected_ids)} entries')


def _build_params(t_start, t_end, psd_source, quantity,
                  filter_flags, low_cutoff, high_cutoff, filter_order):
    def _safe_float(v, default=None):
        if v is None or v == '':
            return default
        try:
            return float(v)
        except (ValueError, TypeError):
            return default

    return {
        't_start': _safe_float(t_start),
        't_end': _safe_float(t_end),
        'psd_source': psd_source or 'vna',
        'quantity': quantity or 'acceleration',
        'use_low': 'low' in (filter_flags or []),
        'use_high': 'high' in (filter_flags or []),
        'low_cutoff': _safe_float(low_cutoff, 100),
        'high_cutoff': _safe_float(high_cutoff, 5),
        'filter_order': int(_safe_float(filter_order, 4)),
    }


def _param_tag(params):
    parts = []
    src = params.get('psd_source', 'vna')
    if src != 'vna':
        parts.append(src)
    q = params.get('quantity', 'acceleration')
    if q != 'acceleration':
        parts.append(q[:3])
    if params.get('use_low'):
        parts.append(f'LP{params["low_cutoff"]:.0f}')
    if params.get('use_high'):
        parts.append(f'HP{params["high_cutoff"]:.0f}')
    return ','.join(parts) if parts else src


def _render_traces(plot_type, selected_ids, params, color_offset, held_count=0):
    renderers = {
        'time': _traces_time,
        'psd': _traces_psd,
        'cumpsd': _traces_cumpsd,
        'trans': _traces_trans,
        'coh': _traces_coh,
    }
    renderer = renderers.get(plot_type, _traces_time)
    return renderer(selected_ids, params, color_offset, held_count)


def _traces_time(selected_ids, params, color_offset, held_count=0):
    traces = []
    for idx, sid in enumerate(selected_ids):
        series, fdata = _get_series_and_file(sid)
        if series is None or fdata is None:
            continue

        ch = series['ch']
        y = fdata['raw_by_ch'].get(ch, np.array([]))
        if len(y) == 0:
            continue

        t = fdata['t'][:len(y)]
        t, y = time_window(t, y, params['t_start'], params['t_end'])

        y = butterworth_filter(y, fdata['fs'],
                               params['use_low'], params['low_cutoff'],
                               params['use_high'], params['high_cutoff'],
                               params['filter_order'])
        y = y * series['scale']

        if params['quantity'] != 'acceleration':
            y = convert_quantity_time(y, fdata['fs'], params['quantity'],
                                     params['use_high'], params['high_cutoff'])

        traces.append(go.Scatter(
            x=t[:len(y)], y=y, mode='lines', name=series['label'],
            line=dict(width=1.1, color=get_series_color(idx + held_count + color_offset * 3)),
        ))
    return traces


def _traces_psd(selected_ids, params, color_offset, held_count=0):
    traces = []
    for idx, sid in enumerate(selected_ids):
        series, fdata = _get_series_and_file(sid)
        if series is None or fdata is None:
            continue

        ch = series['ch']
        f, psd = _get_psd(fdata, ch, params)
        if len(f) == 0:
            continue

        if params['quantity'] != 'acceleration':
            f, psd = convert_quantity_psd(f, psd, params['quantity'],
                                         params['use_high'], params['high_cutoff'])

        psd = psd * (series['scale'] ** 2)

        traces.append(go.Scatter(
            x=f, y=psd, mode='lines', name=series['label'],
            line=dict(width=1.1, color=get_series_color(idx + held_count + color_offset * 3)),
        ))
    return traces


def _traces_cumpsd(selected_ids, params, color_offset, held_count=0):
    traces = []
    for idx, sid in enumerate(selected_ids):
        series, fdata = _get_series_and_file(sid)
        if series is None or fdata is None:
            continue

        ch = series['ch']
        f, psd = _get_psd(fdata, ch, params)
        if len(f) == 0:
            continue

        if params['quantity'] != 'acceleration':
            f, psd = convert_quantity_psd(f, psd, params['quantity'],
                                         params['use_high'], params['high_cutoff'])

        psd = psd * (series['scale'] ** 2)
        f_cum, y_cum = cumulative_rms(f, psd)

        if len(f_cum) > 0:
            traces.append(go.Scatter(
                x=f_cum, y=y_cum, mode='lines', name=series['label'],
                line=dict(width=1.1, color=get_series_color(idx + held_count + color_offset * 3)),
            ))
    return traces


def _traces_trans(selected_ids, params, color_offset, held_count=0):
    traces = []
    for idx, sid in enumerate(selected_ids):
        series, fdata = _get_series_and_file(sid)
        if series is None or fdata is None:
            continue

        vna = fdata.get('vna')
        if vna is None or not vna.get('available') or not vna.get('xcmeas_available'):
            continue

        ch = series['ch']
        ref_ch = _auto_ref_ch(vna, ch)
        if ref_ch is None:
            continue

        key = (ref_ch, ch)
        xc = vna['xcmeas'].get(key)
        if xc is None or len(xc.get('xfer', [])) == 0:
            continue

        eu_ch = vna['eu'].get(ch, 1)
        eu_ref = vna['eu'].get(ref_ch, 1)
        f, tr_db = transmissibility_db(vna['freq'], xc['xfer'], eu_ch, eu_ref)

        if len(f) > 0:
            traces.append(go.Scatter(
                x=f, y=tr_db, mode='lines', name=f'{series["label"]} (ref=ch{ref_ch})',
                line=dict(width=1.1, color=get_series_color(idx + held_count + color_offset * 3)),
            ))
    return traces


def _traces_coh(selected_ids, params, color_offset, held_count=0):
    traces = []
    for idx, sid in enumerate(selected_ids):
        series, fdata = _get_series_and_file(sid)
        if series is None or fdata is None:
            continue

        vna = fdata.get('vna')
        if vna is None or not vna.get('available') or not vna.get('xcmeas_available'):
            continue

        ch = series['ch']
        ref_ch = _auto_ref_ch(vna, ch)
        if ref_ch is None:
            continue

        key = (ref_ch, ch)
        xc = vna['xcmeas'].get(key)
        if xc is None or len(xc.get('coh', [])) == 0:
            continue

        f, coh_data = coherence(vna['freq'], xc['coh'])

        if len(f) > 0:
            traces.append(go.Scatter(
                x=f, y=coh_data, mode='lines', name=f'{series["label"]} (ref=ch{ref_ch})',
                line=dict(width=1.1, color=get_series_color(idx + held_count + color_offset * 3)),
            ))
    return traces


def _auto_ref_ch(vna, ch):
    xcstate = vna.get('xcstate', {})
    refc_list = xcstate.get('refc', [])

    for ref in refc_list:
        if (ref, ch) in vna['xcmeas']:
            return ref

    for key in vna['xcmeas']:
        if key[1] == ch:
            return key[0]

    return None


def _apply_layout(fig, plot_type, params):
    layout_map = {
        'time': dict(
            title='Time Domain',
            xaxis_title='Time (s)',
            yaxis_title=_time_ylabel(params['quantity']),
        ),
        'psd': dict(
            title='PSD',
            xaxis_title='Frequency (Hz)',
            yaxis_title=_psd_ylabel(params['quantity']),
            xaxis_type='log', yaxis_type='log',
        ),
        'cumpsd': dict(
            title='Cumulative PSD (3-sigma)',
            xaxis_title='Frequency (Hz)',
            yaxis_title=_cumpsd_ylabel(params['quantity']),
            xaxis_type='log', yaxis_type='log',
        ),
        'trans': dict(
            title='Transmissibility (dB)',
            xaxis_title='Frequency (Hz)',
            yaxis_title='dB',
            xaxis_type='log',
        ),
        'coh': dict(
            title='Coherence',
            xaxis_title='Frequency (Hz)',
            yaxis_title='Coherence',
            xaxis_type='log',
            yaxis_range=[0, 1],
        ),
    }
    cfg = layout_map.get(plot_type, layout_map['time'])
    fig.update_layout(
        **cfg,
        template='plotly_white', showlegend=True,
        margin=dict(l=60, r=20, t=30, b=40),
        legend=dict(font=dict(size=10)),
    )


# --- Click-to-pin annotation callbacks ---
for _i in range(1, 4):
    @callback(
        Output(f'annotations-{_i}', 'data'),
        Output(f'graph-main-{_i}', 'figure', allow_duplicate=True),
        Input(f'graph-main-{_i}', 'clickData'),
        State(f'annotations-{_i}', 'data'),
        State(f'graph-main-{_i}', 'figure'),
        prevent_initial_call=True,
        _graph_idx=_i,
    )
    def _pin_annotation(click_data, existing_annots, current_fig, _graph_idx=_i):
        if not click_data or not current_fig:
            return no_update, no_update

        point = click_data['points'][0]
        x_val = point.get('x')
        y_val = point.get('y')

        if x_val is None or y_val is None:
            return no_update, no_update

        if isinstance(y_val, (int, float)):
            y_text = f'{y_val:.4g}'
        else:
            y_text = str(y_val)
        if isinstance(x_val, (int, float)):
            x_text = f'{x_val:.4g}'
        else:
            x_text = str(x_val)

        layout = current_fig.get('layout', {})
        x_log = layout.get('xaxis', {}).get('type') == 'log'
        y_log = layout.get('yaxis', {}).get('type') == 'log'

        ax = np.log10(x_val) if x_log and isinstance(x_val, (int, float)) and x_val > 0 else x_val
        ay = np.log10(y_val) if y_log and isinstance(y_val, (int, float)) and y_val > 0 else y_val

        new_annot = {
            'x': ax, 'y': ay,
            'xref': 'x', 'yref': 'y',
            'text': f'({x_text}, {y_text})',
            'showarrow': True,
            'arrowhead': 2,
            'arrowsize': 1,
            'arrowwidth': 1,
            'ax': 30, 'ay': -30,
            'font': {'size': 10},
            'bgcolor': 'rgba(255,255,255,0.8)',
            'bordercolor': '#666',
            'borderwidth': 1,
            '_raw_x': x_val,
            '_raw_y': y_val,
        }

        annots = list(existing_annots or [])

        for a in annots:
            if abs(a.get('_raw_x', a.get('x', 0)) - x_val) < 1e-10 and \
               abs(a.get('_raw_y', a.get('y', 0)) - y_val) < 1e-10:
                annots.remove(a)
                fig = go.Figure(current_fig)
                fig.update_layout(annotations=[
                    {k: v for k, v in a.items() if not k.startswith('_')} for a in annots
                ])
                return annots, fig

        annots.append(new_annot)
        fig = go.Figure(current_fig)
        fig.update_layout(annotations=[
            {k: v for k, v in a.items() if not k.startswith('_')} for a in annots
        ])
        return annots, fig


def _get_psd(fdata, ch, params):
    vna = fdata.get('vna')

    if params['psd_source'] == 'vna' and vna and vna.get('available'):
        freq = vna['freq']
        aspec = vna['aspec'].get(ch, np.array([]))
        if len(aspec) > 0 and len(freq) > 0:
            eu = vna['eu'].get(ch, 1)
            psd = vna_psd(aspec, eu, vna['wincor'], vna['rbw'])
            M = min(len(freq), len(psd))
            f = freq[1:M]
            p = psd[1:M]
            valid = np.isfinite(f) & np.isfinite(p) & (f > 0) & (p > 0)
            return f[valid], p[valid]

    y = fdata['raw_by_ch'].get(ch, np.array([]))
    if len(y) > 0:
        t = fdata['t'][:len(y)]
        t, y = time_window(t, y, params.get('t_start'), params.get('t_end'))

        y = butterworth_filter(y, fdata['fs'],
                               params.get('use_low', False), params.get('low_cutoff', 100),
                               params.get('use_high', False), params.get('high_cutoff', 5),
                               params.get('filter_order', 4))
        return periodogram_psd(y, fdata['fs'])

    return np.array([]), np.array([])


def _get_series_and_file(series_id):
    for s in app_state['series']:
        if s['id'] == series_id:
            fdata = app_state['files'].get(s['file_id'])
            return s, fdata
    return None, None


def _empty_fig():
    return go.Figure().update_layout(
        template='plotly_white',
        margin=dict(l=60, r=20, t=30, b=40),
    )


def _time_ylabel(quantity):
    return {'acceleration': 'Acceleration (m/s²)',
            'velocity': 'Velocity (μm/s)',
            'displacement': 'Displacement (μm)'}.get(quantity, 'Amplitude')


def _psd_ylabel(quantity):
    return {'acceleration': '(m/s²)²/Hz',
            'velocity': '(μm/s)²/Hz',
            'displacement': 'μm²/Hz'}.get(quantity, 'PSD')


def _cumpsd_ylabel(quantity):
    return {'acceleration': '3σ RMS (m/s²)',
            'velocity': '3σ RMS (μm/s)',
            'displacement': '3σ RMS (μm)'}.get(quantity, '3σ RMS')
