import numpy as np
import scipy.io as sio


def parse_vna_file(filepath, fs_hint=1000):
    raw = sio.loadmat(filepath, squeeze_me=True, struct_as_record=False)

    slm = _find_slm_struct(raw)
    if slm is None:
        raise ValueError('No SLm-like struct found in file')

    t = np.asarray(slm.tdxvec).flatten()
    if len(t) < 2:
        raise ValueError('tdxvec is too short')

    dt = np.mean(np.diff(t))
    if not np.isfinite(dt) or dt <= 0:
        fs = float(fs_hint)
        t = np.arange(len(t)) / fs
    else:
        fs = 1.0 / dt

    scmeas = slm.scmeas
    if not hasattr(scmeas, '__len__'):
        scmeas = np.array([scmeas])
    n_ch = len(scmeas)

    raw_by_ch = {}
    valid_channels = []

    for ch_idx in range(n_ch):
        sc = scmeas[ch_idx]
        ch_num = ch_idx + 1

        has_td = _has_field(sc, 'tdmeas')
        has_aspec = _has_field(sc, 'aspec')

        if has_td or has_aspec:
            valid_channels.append(ch_num)

        if has_td:
            eu = _get_eu_val(sc)
            y = np.asarray(sc.tdmeas).flatten() * eu
            N = min(len(t), len(y))
            raw_by_ch[ch_num] = y[:N]
        else:
            raw_by_ch[ch_num] = np.array([])

    if not valid_channels:
        raise ValueError('No valid channels found in scmeas')

    vna = _parse_vna_fields(slm, scmeas, n_ch)

    return {
        'id': None,
        'file_name': '',
        'file_path': filepath,
        't': t,
        'fs': fs,
        'n_ch': n_ch,
        'valid_channels': valid_channels,
        'raw_by_ch': raw_by_ch,
        'vna': vna,
    }


def _find_slm_struct(raw):
    if 'SLm' in raw:
        val = raw['SLm']
        if isinstance(val, np.ndarray) and val.dtype == object:
            val = val.item()
        return val

    for key, val in raw.items():
        if key.startswith('__'):
            continue
        if isinstance(val, np.ndarray) and val.dtype == object:
            val = val.item()
        if hasattr(val, 'scmeas') and hasattr(val, 'tdxvec'):
            return val
    return None


def _parse_vna_fields(slm, scmeas, n_ch):
    freq = np.array([])
    if _has_field(slm, 'fdxvec'):
        freq = np.asarray(slm.fdxvec).flatten()

    wincor = 1.0
    if _has_field(slm, 'wincor') and np.isfinite(slm.wincor):
        wincor = float(slm.wincor)

    rbw = 1.0
    if _has_field(slm, 'rbw') and np.isfinite(slm.rbw) and slm.rbw > 0:
        rbw = float(slm.rbw)

    aspec = {}
    eu = {}
    eu_string = {}
    for ch_idx in range(n_ch):
        sc = scmeas[ch_idx]
        ch_num = ch_idx + 1
        eu[ch_num] = _get_eu_val(sc)
        eu_string[ch_num] = _get_eu_string(sc)

        if _has_field(sc, 'aspec'):
            a = np.asarray(sc.aspec).flatten()
            if len(freq) > 0:
                M = min(len(freq), len(a))
                a = a[:M]
            aspec[ch_num] = a
        else:
            aspec[ch_num] = np.array([])

    xcmeas_data = {}
    xcstate = {'refc': [], 'resp': {}}
    xcmeas_available = False

    if _has_field(slm, 'xcmeas'):
        xcmeas_data, xcstate = _parse_xcmeas(slm, n_ch, len(freq))
        xcmeas_available = bool(xcmeas_data)

    available = len(freq) > 0

    return {
        'available': available,
        'n_ch': n_ch,
        'freq': freq,
        'aspec': aspec,
        'eu': eu,
        'eu_string': eu_string,
        'wincor': wincor,
        'rbw': rbw,
        'xcmeas': xcmeas_data,
        'xcmeas_available': xcmeas_available,
        'xcstate': xcstate,
    }


def _parse_xcmeas(slm, n_ch, freq_len):
    xcmeas_data = {}
    xcstate = {'refc': [], 'resp': {}}

    xc = slm.xcmeas
    if isinstance(xc, np.ndarray):
        if xc.ndim == 2:
            n_ref, n_resp = xc.shape
        elif xc.ndim == 1:
            n_ref = 1
            n_resp = len(xc)
            xc = xc.reshape(1, -1)
        else:
            return xcmeas_data, xcstate
    else:
        return xcmeas_data, xcstate

    if _has_field(slm, 'xcstate'):
        xs = slm.xcstate
        if _has_field(xs, 'refc'):
            refc = np.atleast_1d(np.asarray(xs.refc).flatten()).astype(int)
            xcstate['refc'] = refc.tolist()

            if _has_field(xs, 'resp'):
                resp_arr = xs.resp
                if not hasattr(resp_arr, '__len__'):
                    resp_arr = np.array([resp_arr])
                for k_idx, ref_ch in enumerate(refc):
                    if k_idx < len(resp_arr):
                        r = resp_arr[k_idx]
                        if _has_field(r, 'r'):
                            resp_chs = np.atleast_1d(np.asarray(r.r).flatten()).astype(int)
                            xcstate['resp'][int(ref_ch)] = resp_chs.tolist()

    for ref_idx in range(n_ref):
        for resp_idx in range(n_resp):
            entry = xc[ref_idx, resp_idx]
            ref_ch = ref_idx + 1
            resp_ch = resp_idx + 1

            xfer = None
            coh = None

            if _has_field(entry, 'xfer'):
                xfer_raw = np.asarray(entry.xfer).flatten()
                if len(xfer_raw) > 0 and np.any(xfer_raw != 0):
                    xfer = xfer_raw

            if _has_field(entry, 'coh'):
                coh_raw = np.asarray(entry.coh).flatten()
                if len(coh_raw) > 0 and np.any(coh_raw != 0):
                    coh = coh_raw

            if xfer is not None or coh is not None:
                xcmeas_data[(ref_ch, resp_ch)] = {
                    'xfer': xfer if xfer is not None else np.array([]),
                    'coh': coh if coh is not None else np.array([]),
                }

    return xcmeas_data, xcstate


def _has_field(obj, name):
    if obj is None:
        return False
    if not hasattr(obj, name):
        return False
    val = getattr(obj, name)
    if val is None:
        return False
    if isinstance(val, np.ndarray) and val.size == 0:
        return False
    return True


def _get_eu_val(sc):
    if _has_field(sc, 'eu_val'):
        v = float(sc.eu_val)
        if np.isfinite(v) and v != 0:
            return v
    return 1.0


def _get_eu_string(sc):
    if _has_field(sc, 'eu_string'):
        s = sc.eu_string
        if isinstance(s, np.ndarray):
            s = str(s.item()) if s.size == 1 else str(s)
        return str(s).strip()
    return ''
