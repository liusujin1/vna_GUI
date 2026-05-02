import numpy as np
import plotly.graph_objects as go
from dash import Input, Output, State, callback, no_update, ctx
from app import app_state
from core.signal_proc import get_series_color
from core.spectral import coherence
from core.floor_analysis import (
    third_octave_bands, band_rms_velocity,
    vc_criteria_curves, VC_COLORS,
    dynamic_stiffness, floor_coherence,
)


@callback(
    Output('graph-floor-vib', 'figure'),
    Output('graph-floor-stiff', 'figure'),
    Output('graph-floor-coh', 'figure'),
    Output('status-bar', 'children', allow_duplicate=True),
    Input('btn-floor-plot', 'n_clicks'),
    State('dd-vib-file', 'value'),
    State('dd-stiff-file', 'value'),
    State('input-vib-ch', 'value'),
    State('input-resp-ch', 'value'),
    State('chk-vc', 'value'),
    prevent_initial_call=True,
)
def plot_floor(n_clicks, vib_file_id, stiff_file_id,
               vib_ch_str, resp_ch_str, vc_flags):
    if not vib_file_id and not stiff_file_id:
        return no_update, no_update, no_update, 'Select at least one file'

    vib_channels = _parse_channel_list(vib_ch_str)
    resp_channels = _parse_channel_list(resp_ch_str)

    msgs = []

    fig_vib = _render_floor_vibration(vib_file_id, vib_channels, vc_flags or [])
    fig_stiff, stiff_msg = _render_floor_stiffness(stiff_file_id, resp_channels)
    fig_coh, coh_msg = _render_floor_coherence(stiff_file_id, resp_channels)

    if stiff_msg:
        msgs.append(f'Stiff: {stiff_msg}')
    if coh_msg:
        msgs.append(f'Coh: {coh_msg}')

    status = 'Floor vibration plotted'
    if msgs:
        status += ' | ' + '; '.join(msgs)

    return fig_vib, fig_stiff, fig_coh, status


def _render_floor_vibration(file_id, vib_channels, vc_flags):
    fig = go.Figure()

    if file_id and file_id in app_state['files']:
        fdata = app_state['files'][file_id]
        vna = fdata.get('vna')

        if vna and vna.get('available') and len(vna.get('freq', [])) > 2:
            freq = vna['freq']
            f_pos = freq[freq > 0]
            if len(f_pos) >= 2:
                fc, fc_L, fc_U = third_octave_bands(float(f_pos.min()), float(f_pos.max()))

                if len(fc) > 0:
                    for ci, ch in enumerate(vib_channels):
                        if ch < 1 or ch > vna.get('n_ch', 0):
                            continue
                        aspec = vna['aspec'].get(ch, np.array([]))
                        if len(aspec) == 0:
                            continue

                        eu = vna['eu'].get(ch, 1)
                        rms = band_rms_velocity(freq, aspec, vna['rbw'], eu, fc, fc_L, fc_U)

                        valid = np.isfinite(fc) & np.isfinite(rms) & (fc > 0) & (rms > 0)
                        if np.any(valid):
                            fig.add_trace(go.Scatter(
                                x=fc[valid], y=rms[valid],
                                mode='lines+markers', name=f'ch{ch}',
                                line=dict(width=1.1, color=get_series_color(ci)),
                                marker=dict(size=5),
                            ))

    vc = vc_criteria_curves()
    for label in ['VC-A', 'VC-B', 'VC-C', 'VC-D']:
        flag = label[-1]
        if flag in vc_flags:
            fig.add_trace(go.Scatter(
                x=vc['f'], y=vc[label],
                mode='lines', name=label,
                line=dict(dash='dash', width=1.5, color=VC_COLORS.get(label, 'gray')),
            ))

    fig.update_layout(
        title='Floor Vibration - 1/3 Octave Band',
        xaxis_title='Frequency (Hz)', yaxis_title='RMS Velocity (um/s)',
        xaxis_type='log', yaxis_type='log',
        template='plotly_white', showlegend=True,
        margin=dict(l=60, r=20, t=30, b=40), legend=dict(font=dict(size=10)),
    )
    return fig


def _render_floor_stiffness(file_id, resp_channels):
    fig = go.Figure()
    msg = ''

    if not file_id or file_id not in app_state['files']:
        msg = 'no file selected'
    else:
        fdata = app_state['files'][file_id]
        vna = fdata.get('vna')

        if not vna or not vna.get('xcmeas_available'):
            msg = f'{fdata["file_name"]}: no xcmeas data'
        else:
            excite_ch = _auto_excite_ch(vna)
            if excite_ch is None:
                msg = 'no excite channel found in xcstate'
            else:
                plotted = 0
                skipped = []
                for ci, resp_ch in enumerate(resp_channels):
                    key = (excite_ch, resp_ch)
                    xc = vna['xcmeas'].get(key)
                    if xc is None or len(xc.get('xfer', [])) == 0:
                        skipped.append(resp_ch)
                        continue

                    eu_resp = vna['eu'].get(resp_ch, 1)
                    eu_exc = vna['eu'].get(excite_ch, 1)
                    f, k_abs = dynamic_stiffness(vna['freq'], xc['xfer'], eu_resp, eu_exc)

                    if len(f) > 0:
                        fig.add_trace(go.Scatter(
                            x=f, y=k_abs, mode='lines',
                            name=f'ch{resp_ch} (excite=ch{excite_ch})',
                            line=dict(width=1.2, color=get_series_color(ci)),
                        ))
                        plotted += 1
                    else:
                        skipped.append(resp_ch)

                if plotted > 0:
                    f_all = np.concatenate([np.array(t.x) for t in fig.data])
                    f_min, f_max = max(30, float(f_all.min())), min(1000, float(f_all.max()))
                    if f_max > f_min:
                        fig.add_trace(go.Scatter(
                            x=[f_min, f_max], y=[1e8, 1e8],
                            mode='lines', name='Spec (1e8 N/m)',
                            line=dict(dash='dash', width=1.5, color='rgb(217,51,51)'),
                        ))

                if skipped:
                    avail_keys = [k for k in vna['xcmeas'].keys()]
                    msg = f'no xcmeas({excite_ch},ch{skipped}), available: {avail_keys}'

    fig.update_layout(
        title='Dynamic Stiffness',
        xaxis_title='Frequency (Hz)', yaxis_title='Magnitude (N/m)',
        xaxis_type='log', yaxis_type='log',
        template='plotly_white', showlegend=True,
        margin=dict(l=60, r=20, t=30, b=40), legend=dict(font=dict(size=10)),
    )
    return fig, msg


def _render_floor_coherence(file_id, resp_channels):
    fig = go.Figure()
    msg = ''

    if not file_id or file_id not in app_state['files']:
        msg = 'no file selected'
    else:
        fdata = app_state['files'][file_id]
        vna = fdata.get('vna')

        if not vna or not vna.get('xcmeas_available'):
            msg = f'{fdata["file_name"]}: no xcmeas data'
        else:
            excite_ch = _auto_excite_ch(vna)
            if excite_ch is None:
                msg = 'no excite channel found in xcstate'
            else:
                plotted = 0
                for ci, resp_ch in enumerate(resp_channels):
                    key = (excite_ch, resp_ch)
                    xc = vna['xcmeas'].get(key)
                    if xc is None or len(xc.get('coh', [])) == 0:
                        continue

                    f, coh_data = floor_coherence(vna['freq'], xc['coh'])

                    if len(f) > 0:
                        fig.add_trace(go.Scatter(
                            x=f, y=coh_data, mode='lines',
                            name=f'ch{resp_ch} (excite=ch{excite_ch})',
                            line=dict(width=1.1, color=get_series_color(ci)),
                        ))
                        plotted += 1

                if plotted == 0:
                    msg = f'no coherence data for excite=ch{excite_ch}'

    fig.update_layout(
        title='Coherence',
        xaxis_title='Frequency (Hz)', yaxis_title='Coherence',
        xaxis_type='log', yaxis_range=[0, 1],
        template='plotly_white', showlegend=True,
        margin=dict(l=60, r=20, t=30, b=40), legend=dict(font=dict(size=10)),
    )
    return fig, msg


def _auto_excite_ch(vna):
    refc = vna.get('xcstate', {}).get('refc', [])
    if refc:
        return refc[0]
    keys = list(vna.get('xcmeas', {}).keys())
    if keys:
        return keys[0][0]
    return None


def _parse_channel_list(raw):
    if not raw:
        return []
    channels = []
    for part in str(raw).replace(' ', ',').split(','):
        part = part.strip()
        if part:
            try:
                channels.append(int(part))
            except ValueError:
                pass
    return channels
