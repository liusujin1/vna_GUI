import base64
import os
import tempfile
from dash import Input, Output, State, callback, no_update, ctx
from app import app_state
from core.file_reader import read_file, list_supported_files


@callback(
    Output('data-checklist', 'options'),
    Output('data-checklist', 'value'),
    Output('dd-vib-file', 'options'),
    Output('dd-vib-file', 'value'),
    Output('dd-stiff-file', 'options'),
    Output('dd-stiff-file', 'value'),
    Output('status-bar', 'children'),
    Input('upload-data', 'contents'),
    Input('btn-nas-load', 'n_clicks'),
    Input('btn-delete', 'n_clicks'),
    State('upload-data', 'filename'),
    State('nas-path', 'value'),
    State('data-checklist', 'value'),
    prevent_initial_call=True,
)
def manage_data(upload_contents, nas_clicks, delete_clicks,
                upload_filenames, nas_path, selected_ids):

    trigger = ctx.triggered_id

    if trigger == 'upload-data' and upload_contents:
        return _handle_upload(upload_contents, upload_filenames)

    if trigger == 'btn-nas-load' and nas_path:
        return _handle_nas_load(nas_path)

    if trigger == 'btn-delete':
        return _handle_delete(selected_ids)

    return (no_update,) * 7


def _handle_upload(contents_list, filenames_list):
    if not contents_list:
        return (no_update,) * 6 + ('No files selected',)

    loaded = 0
    failed = 0

    for content, filename in zip(contents_list, filenames_list):
        try:
            _, content_string = content.split(',')
            decoded = base64.b64decode(content_string)

            _, ext = os.path.splitext(filename)
            with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
                tmp.write(decoded)
                tmp_path = tmp.name

            try:
                data = read_file(tmp_path)
                data['file_name'] = filename
                file_id = data['id']
                app_state['files'][file_id] = data

                for ch in data['valid_channels']:
                    series_id = f"{file_id}_ch{ch}"
                    app_state['series'].append({
                        'id': series_id,
                        'file_id': file_id,
                        'ch': ch,
                        'label': f"{filename}+ch{ch}",
                        'scale': 1.0,
                    })
                loaded += 1
            finally:
                os.unlink(tmp_path)
        except Exception as e:
            failed += 1

    return _build_outputs(f'Loaded {loaded} file(s), {_count_series()} entries' +
                          (f', {failed} failed' if failed else ''))


def _handle_nas_load(nas_path):
    files = list_supported_files(nas_path)
    if not files:
        return (no_update,) * 6 + (f'No supported files in {nas_path}',)

    loaded = 0
    failed = 0

    for fpath in files:
        try:
            data = read_file(fpath)
            file_id = data['id']
            app_state['files'][file_id] = data

            for ch in data['valid_channels']:
                series_id = f"{file_id}_ch{ch}"
                app_state['series'].append({
                    'id': series_id,
                    'file_id': file_id,
                    'ch': ch,
                    'label': f"{data['file_name']}+ch{ch}",
                    'scale': 1.0,
                })
            loaded += 1
        except Exception:
            failed += 1

    return _build_outputs(f'Loaded {loaded} file(s) from NAS, {_count_series()} entries' +
                          (f', {failed} failed' if failed else ''))


def _handle_delete(selected_ids):
    if not selected_ids:
        return (no_update,) * 6 + ('Nothing selected',)

    selected_set = set(selected_ids)
    app_state['series'] = [s for s in app_state['series'] if s['id'] not in selected_set]

    used_file_ids = {s['file_id'] for s in app_state['series']}
    for fid in list(app_state['files'].keys()):
        if fid not in used_file_ids:
            del app_state['files'][fid]

    return _build_outputs(f'Deleted {len(selected_ids)} entries')


@callback(
    Output('input-rename', 'value'),
    Output('input-scale', 'value'),
    Output('scale-info', 'children'),
    Input('data-checklist', 'value'),
    prevent_initial_call=True,
)
def sync_selection(selected_ids):
    if not selected_ids or len(selected_ids) != 1:
        count = len(selected_ids) if selected_ids else 0
        return '', 1.0, f'{count} selected' if count != 1 else ''

    for s in app_state['series']:
        if s['id'] == selected_ids[0]:
            return s['label'], s['scale'], f'Editing: {s["label"]}'

    return '', 1.0, ''


@callback(
    Output('data-checklist', 'options', allow_duplicate=True),
    Output('status-bar', 'children', allow_duplicate=True),
    Input('input-rename', 'value'),
    State('data-checklist', 'value'),
    prevent_initial_call=True,
)
def on_rename(new_name, selected_ids):
    if not new_name or not selected_ids or len(selected_ids) != 1:
        return no_update, no_update

    for s in app_state['series']:
        if s['id'] == selected_ids[0]:
            s['label'] = new_name
            break

    options = _sorted_checklist_options()
    return options, f'Renamed to "{new_name}"'


@callback(
    Output('status-bar', 'children', allow_duplicate=True),
    Input('input-scale', 'value'),
    State('data-checklist', 'value'),
    prevent_initial_call=True,
)
def on_scale(scale_val, selected_ids):
    if scale_val is None or not selected_ids or len(selected_ids) != 1:
        return no_update

    for s in app_state['series']:
        if s['id'] == selected_ids[0]:
            s['scale'] = float(scale_val)
            return f'Scale of "{s["label"]}" = {scale_val}'

    return no_update


def _build_outputs(status_msg):
    checklist_options = _sorted_checklist_options()
    file_options = _sorted_file_options()
    first_file = file_options[0]['value'] if file_options else None
    return (checklist_options, [], file_options, first_file,
            file_options, first_file, status_msg)


def _sorted_checklist_options():
    sorted_series = sorted(app_state['series'], key=lambda s: s['label'])
    return [{'label': s['label'], 'value': s['id']} for s in sorted_series]


def _sorted_file_options():
    sorted_files = sorted(app_state['files'].items(), key=lambda kv: kv[1]['file_name'])
    return [{'label': d['file_name'], 'value': fid} for fid, d in sorted_files]


def _count_series():
    return len(app_state['series'])
