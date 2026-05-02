import dash
import os
from dash import html

app = dash.Dash(
    __name__,
    suppress_callback_exceptions=True,
    title='Vibration Viewer',
)
server = app.server

# Windows打包场景下，默认使用当前工作目录作为数据目录；可通过环境变量覆盖。
DATA_DIR = os.environ.get('VIBRATION_DATA_DIR', os.getcwd())

# Global state (single-user mode)
app_state = {
    'files': {},
    'series': [],
}

from layout import create_layout
app.layout = create_layout()

import callbacks  # noqa: F401, E402

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8050)
