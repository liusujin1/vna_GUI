import os
import threading
import time
import traceback
import webbrowser


PORT = 8050
HOST_CANDIDATES = ['127.0.0.1', 'localhost', '0.0.0.0']


def _get_base_dir():
    if getattr(__import__('sys'), 'frozen', False):
        return os.path.dirname(os.path.abspath(__import__('sys').executable))
    return os.path.dirname(os.path.abspath(__file__))


def _get_log_path():
    return os.path.join(_get_base_dir(), 'vibration-web-error.log')


def _log_error(msg):
    try:
        with open(_get_log_path(), 'a') as f:
            f.write('%s\n' % msg)
    except Exception:
        pass


def _serve_with_host(host, server, serve_func, err_box):
    try:
        serve_func(server, listen='%s:%d' % (host, PORT), threads=8)
    except Exception as e:
        err_box['err'] = e
        err_box['tb'] = traceback.format_exc()


def _start_server(server, serve_func):
    for host in HOST_CANDIDATES:
        err_box = {'err': None, 'tb': ''}
        t = threading.Thread(target=_serve_with_host, args=(host, server, serve_func, err_box))
        t.daemon = True
        t.start()
        time.sleep(1.8)
        if t.is_alive():
            return host, t
        if err_box['err'] is not None:
            _log_error('Host %s failed:\n%s' % (host, err_box['tb']))
    raise RuntimeError('All hosts failed. Check vibration-web-error.log')


def main():
    base_dir = _get_base_dir()
    os.environ.setdefault('VIBRATION_DATA_DIR', base_dir)

    try:
        from waitress import serve as waitress_serve
        from app import server
    except Exception:
        _log_error('Import failed:\n%s' % traceback.format_exc())
        raise

    try:
        import webview
    except Exception:
        webview = None
        _log_error('webview import failed:\n%s' % traceback.format_exc())

    host, server_thread = _start_server(server, waitress_serve)
    url = 'http://%s:%d' % (('127.0.0.1' if host == '0.0.0.0' else host), PORT)

    if webview is not None:
        try:
            webview.create_window(
                'Vibration Viewer',
                url,
                width=1400,
                height=900,
                min_size=(1000, 700),
            )
            webview.start(gui='edgechromium')
            return
        except Exception:
            _log_error('webview failed:\n%s' % traceback.format_exc())

    webbrowser.open(url)
    while server_thread.is_alive():
        time.sleep(0.5)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        _log_error('launcher failed:\n%s' % traceback.format_exc())
        raise
