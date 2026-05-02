import os
import uuid
import numpy as np
from .vna_parser import parse_vna_file

SUPPORTED_EXTENSIONS = {'.vna', '.mat', '.txt', '.dat', '.csv', '.xlsx'}


def read_file(filepath, fs_hint=1000):
    _, ext = os.path.splitext(filepath)
    ext = ext.lower()

    if ext in ('.vna', '.mat'):
        result = parse_vna_file(filepath, fs_hint)
    elif ext in ('.txt', '.dat', '.csv'):
        result = _read_text_csv(filepath, fs_hint)
    elif ext == '.xlsx':
        result = _read_excel(filepath, fs_hint)
    else:
        raise ValueError(f'Unsupported file type: {ext}')

    result['id'] = str(uuid.uuid4())[:8]
    result['file_name'] = os.path.basename(filepath)
    result['file_path'] = filepath
    return result


def list_supported_files(directory):
    if not os.path.isdir(directory):
        return []
    files = []
    for name in sorted(os.listdir(directory)):
        _, ext = os.path.splitext(name)
        if ext.lower() in SUPPORTED_EXTENSIONS:
            files.append(os.path.join(directory, name))
    return files


def _read_text_csv(filepath, fs_hint):
    data = None
    for loader in [
        lambda: np.loadtxt(filepath, delimiter=','),
        lambda: np.loadtxt(filepath),
        lambda: _manual_parse(filepath),
    ]:
        try:
            data = loader()
            if data is not None and data.size > 0:
                break
        except Exception:
            continue

    if data is None or data.size == 0:
        raise ValueError('File does not contain numeric data')

    return _parse_numeric_matrix(data, fs_hint)


def _read_excel(filepath, fs_hint):
    import pandas as pd
    df = pd.read_excel(filepath, header=None)
    data = df.values.astype(float)
    return _parse_numeric_matrix(data, fs_hint)


def _manual_parse(filepath):
    rows = []
    with open(filepath, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if parts:
                try:
                    rows.append([float(x) for x in parts])
                except ValueError:
                    continue
    if not rows:
        return np.array([])
    return np.array(rows)


def _parse_numeric_matrix(data, fs_hint):
    data = np.squeeze(data)

    if data.ndim == 1:
        y = data
        fs = float(fs_hint)
        t = np.arange(len(y)) / fs
    elif data.ndim == 2 and data.shape[1] >= 2:
        c1 = data[:, 0]
        c2 = data[:, 1]
        if _is_time_like(c1):
            t = c1
            y = c2
            dt = np.mean(np.diff(t))
            fs = 1.0 / dt if dt > 0 else float(fs_hint)
        else:
            y = c1
            fs = float(fs_hint)
            t = np.arange(len(y)) / fs
    else:
        y = data.flatten()
        fs = float(fs_hint)
        t = np.arange(len(y)) / fs

    return {
        'id': None,
        'file_name': '',
        'file_path': '',
        't': t,
        'fs': fs,
        'n_ch': 1,
        'valid_channels': [1],
        'raw_by_ch': {1: y},
        'vna': None,
    }


def _is_time_like(v):
    v = np.asarray(v).flatten()
    if len(v) < 3 or not np.all(np.isfinite(v)):
        return False
    d = np.diff(v)
    if not np.all(d > 0):
        return False
    return np.std(d) / max(np.mean(d), 1e-10) < 0.01
