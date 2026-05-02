from dash import html, dcc
import os


DEFAULT_DATA_DIR = os.environ.get('VIBRATION_DATA_DIR', os.getcwd())


PLOT_TYPE_OPTIONS = [
    {'label': 'Time', 'value': 'time'},
    {'label': 'PSD', 'value': 'psd'},
    {'label': 'Cumulative PSD', 'value': 'cumpsd'},
    {'label': 'Transmissibility', 'value': 'trans'},
    {'label': 'Coherence', 'value': 'coh'},
]

QUANTITY_OPTIONS = [
    {'label': 'Acceleration', 'value': 'acceleration'},
    {'label': 'Velocity', 'value': 'velocity'},
    {'label': 'Displacement', 'value': 'displacement'},
]

PSD_SOURCE_OPTIONS = [
    {'label': 'VNA Native', 'value': 'vna'},
    {'label': 'Periodogram', 'value': 'periodogram'},
]


def create_layout():
    return html.Div([
        dcc.Store(id='held-traces-1', data=None),
        dcc.Store(id='held-traces-2', data=None),
        dcc.Store(id='held-traces-3', data=None),
        dcc.Store(id='annotations-1', data=[]),
        dcc.Store(id='annotations-2', data=[]),
        dcc.Store(id='annotations-3', data=[]),

        html.Div([
            _left_panel(),
            _right_panel(),
        ], style={
            'display': 'flex',
            'height': '100vh',
            'fontFamily': 'system-ui, -apple-system, sans-serif',
        }),
    ])


def _left_panel():
    return html.Div([
        html.H3('Vibration Viewer', style={'margin': '0 0 12px 0', 'fontSize': '18px'}),

        # --- File Management ---
        html.Details([
            html.Summary('Data', style={'fontWeight': 'bold', 'cursor': 'pointer', 'fontSize': '14px'}),

            html.Div([
                dcc.Upload(
                    id='upload-data',
                    children=html.Div(['Drag & drop or ', html.A('browse files')]),
                    style={
                        'width': '100%', 'height': '50px', 'lineHeight': '50px',
                        'borderWidth': '1px', 'borderStyle': 'dashed', 'borderRadius': '5px',
                        'textAlign': 'center', 'margin': '6px 0', 'fontSize': '12px',
                    },
                    multiple=True,
                ),

                html.Label('NAS Path:', style={'fontSize': '12px', 'marginTop': '6px'}),
                html.Div([
                    dcc.Input(id='nas-path', type='text', value=DEFAULT_DATA_DIR,
                              style={'flex': '1', 'fontSize': '12px', 'padding': '3px'}),
                    html.Button('Load', id='btn-nas-load', n_clicks=0,
                                style={'fontSize': '12px', 'padding': '3px 8px', 'marginLeft': '4px'}),
                ], style={'display': 'flex', 'marginBottom': '6px'}),

                html.Label('Loaded Data:', style={'fontSize': '12px'}),
                dcc.Checklist(id='data-checklist', options=[], value=[],
                              style={'maxHeight': '200px', 'overflowY': 'auto', 'fontSize': '12px'}),

                html.Div([
                    html.Button('Delete Selected', id='btn-delete', n_clicks=0,
                                style={'fontSize': '11px', 'padding': '2px 6px'}),
                ], style={'marginTop': '4px'}),

                html.Div([
                    html.Label('Rename:', style={'fontSize': '12px', 'width': '50px'}),
                    dcc.Input(id='input-rename', type='text', debounce=True,
                              style={'flex': '1', 'fontSize': '12px', 'padding': '2px'}),
                ], style={'display': 'flex', 'alignItems': 'center', 'marginTop': '4px'}),

                html.Div([
                    html.Label('Scale:', style={'fontSize': '12px', 'width': '50px'}),
                    dcc.Input(id='input-scale', type='number', value=1.0, debounce=True,
                              style={'flex': '1', 'fontSize': '12px', 'padding': '2px'}),
                ], style={'display': 'flex', 'alignItems': 'center', 'marginTop': '4px'}),

                html.Div(id='scale-info', style={'fontSize': '11px', 'color': '#888', 'marginTop': '2px'}),
            ]),
        ], open=True, style={'marginBottom': '10px'}),

        # --- Processing Parameters ---
        html.Details([
            html.Summary('Processing', style={'fontWeight': 'bold', 'cursor': 'pointer', 'fontSize': '14px'}),

            html.Div([
                _labeled_input('T start (s):', 'input-tstart', '', 'text'),
                _labeled_input('T end (s):', 'input-tend', '', 'text'),

                html.Div([
                    html.Label('PSD Source:', style={'fontSize': '12px', 'width': '70px'}),
                    dcc.Dropdown(id='dd-psd-source', options=PSD_SOURCE_OPTIONS, value='vna',
                                 style={'flex': '1', 'fontSize': '12px'}, clearable=False),
                ], style={'display': 'flex', 'alignItems': 'center', 'marginTop': '4px'}),

                html.Div([
                    html.Label('Quantity:', style={'fontSize': '12px', 'width': '70px'}),
                    dcc.Dropdown(id='dd-quantity', options=QUANTITY_OPTIONS, value='acceleration',
                                 style={'flex': '1', 'fontSize': '12px'}, clearable=False),
                ], style={'display': 'flex', 'alignItems': 'center', 'marginTop': '4px'}),

                html.Hr(style={'margin': '6px 0'}),

                html.Div([
                    dcc.Checklist(id='chk-filter',
                                  options=[
                                      {'label': ' Low-pass', 'value': 'low'},
                                      {'label': ' High-pass', 'value': 'high'},
                                  ], value=[], inline=True,
                                  style={'fontSize': '12px'}),
                ]),

                _labeled_input('Low cutoff (Hz):', 'input-low-cutoff', 100, 'number'),
                _labeled_input('High cutoff (Hz):', 'input-high-cutoff', 5, 'number'),
                _labeled_input('Filter order:', 'input-filter-order', 4, 'number'),

                html.Button('Reset Filter', id='btn-reset-filter', n_clicks=0,
                            style={'fontSize': '11px', 'padding': '2px 6px', 'marginTop': '4px'}),
            ]),
        ], open=True, style={'marginBottom': '10px'}),

        # --- Plot Controls ---
        html.Details([
            html.Summary('Plot', style={'fontWeight': 'bold', 'cursor': 'pointer', 'fontSize': '14px'}),
            html.Div([
                html.Div([
                    html.Button('Plot', id='btn-plot', n_clicks=0,
                                style={'fontSize': '13px', 'padding': '4px 16px',
                                       'backgroundColor': '#1976D2', 'color': 'white',
                                       'border': 'none', 'borderRadius': '4px', 'cursor': 'pointer'}),
                    dcc.Checklist(id='chk-hold',
                                  options=[{'label': ' Hold', 'value': 'hold'}],
                                  value=[], inline=True,
                                  style={'fontSize': '12px', 'marginLeft': '12px'}),
                    html.Button('Clear', id='btn-clear', n_clicks=0,
                                style={'fontSize': '12px', 'padding': '3px 10px', 'marginLeft': '8px'}),
                ], style={'display': 'flex', 'alignItems': 'center'}),
            ]),
        ], open=True, style={'marginBottom': '10px'}),

        # --- Status ---
        html.Div(id='status-bar', children='Ready',
                 style={'fontSize': '11px', 'color': '#666', 'marginTop': '8px',
                        'borderTop': '1px solid #ddd', 'paddingTop': '6px'}),

    ], style={
        'width': '260px', 'minWidth': '240px',
        'padding': '10px', 'overflowY': 'auto',
        'borderRight': '1px solid #ddd', 'backgroundColor': '#fafafa',
    })


def _right_panel():
    return html.Div([
        dcc.Tabs(id='tabs', value='main', children=[
            dcc.Tab(label='Main', value='main', children=[_main_tab()]),
            dcc.Tab(label='Floor Vibration', value='floor', children=[_floor_tab()]),
        ]),
    ], style={'flex': '1', 'padding': '8px', 'overflowY': 'auto'})


def _main_tab():
    axes = []
    defaults = ['time', 'psd', 'trans']
    for i in range(1, 4):
        axes.append(html.Div([
            html.Div([
                dcc.Dropdown(
                    id=f'dd-plot-type-{i}',
                    options=PLOT_TYPE_OPTIONS,
                    value=defaults[i - 1],
                    style={'width': '180px', 'fontSize': '12px'},
                    clearable=False,
                ),
            ], style={'marginBottom': '2px'}),
            dcc.Graph(
                id=f'graph-main-{i}',
                config={'displayModeBar': True, 'scrollZoom': True},
                style={'height': '30vh'},
            ),
        ], style={'marginBottom': '4px'}))

    return html.Div(axes)


def _floor_tab():
    return html.Div([
        html.Div([
            html.Div([
                html.Label('Vib File:', style={'fontSize': '12px', 'width': '65px'}),
                dcc.Dropdown(id='dd-vib-file', options=[], style={'flex': '1', 'fontSize': '12px'}, clearable=False),
            ], style={'display': 'flex', 'alignItems': 'center', 'flex': '1', 'marginRight': '10px'}),

            html.Div([
                html.Label('Stiff File:', style={'fontSize': '12px', 'width': '65px'}),
                dcc.Dropdown(id='dd-stiff-file', options=[], style={'flex': '1', 'fontSize': '12px'}, clearable=False),
            ], style={'display': 'flex', 'alignItems': 'center', 'flex': '1'}),
        ], style={'display': 'flex', 'marginBottom': '6px'}),

        html.Div([
            html.Div([
                html.Label('Vib Ch:', style={'fontSize': '12px', 'width': '55px'}),
                dcc.Input(id='input-vib-ch', type='text', value='2,3,4',
                          style={'flex': '1', 'fontSize': '12px', 'padding': '2px'}),
            ], style={'display': 'flex', 'alignItems': 'center', 'flex': '1', 'marginRight': '8px'}),
            html.Div([
                html.Label('Resp Ch:', style={'fontSize': '12px', 'width': '60px'}),
                dcc.Input(id='input-resp-ch', type='text', value='4',
                          style={'flex': '1', 'fontSize': '12px', 'padding': '2px'}),
            ], style={'display': 'flex', 'alignItems': 'center', 'flex': '1'}),
        ], style={'display': 'flex', 'marginBottom': '6px'}),

        html.Div([
            dcc.Checklist(
                id='chk-vc',
                options=[
                    {'label': ' VC-A', 'value': 'A'},
                    {'label': ' VC-B', 'value': 'B'},
                    {'label': ' VC-C', 'value': 'C'},
                    {'label': ' VC-D', 'value': 'D'},
                ],
                value=['A', 'B', 'C', 'D'],
                inline=True,
                style={'fontSize': '12px'},
            ),
            html.Button('Plot', id='btn-floor-plot', n_clicks=0,
                        style={'fontSize': '13px', 'padding': '4px 16px', 'marginLeft': '12px',
                               'backgroundColor': '#1976D2', 'color': 'white',
                               'border': 'none', 'borderRadius': '4px', 'cursor': 'pointer'}),
        ], style={'display': 'flex', 'alignItems': 'center', 'marginBottom': '6px'}),

        dcc.Graph(id='graph-floor-vib', config={'displayModeBar': True, 'scrollZoom': True},
                  style={'height': '28vh'}),
        dcc.Graph(id='graph-floor-stiff', config={'displayModeBar': True, 'scrollZoom': True},
                  style={'height': '28vh'}),
        dcc.Graph(id='graph-floor-coh', config={'displayModeBar': True, 'scrollZoom': True},
                  style={'height': '28vh'}),
    ])


def _labeled_input(label, input_id, default, input_type='text'):
    return html.Div([
        html.Label(label, style={'fontSize': '12px', 'width': '100px', 'minWidth': '70px'}),
        dcc.Input(id=input_id, type=input_type, value=default,
                  style={'flex': '1', 'fontSize': '12px', 'padding': '2px'}),
    ], style={'display': 'flex', 'alignItems': 'center', 'marginTop': '4px'})
