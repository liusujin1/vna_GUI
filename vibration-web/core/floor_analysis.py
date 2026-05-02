import numpy as np


def third_octave_bands(min_f, max_f):
    if not np.isfinite(min_f) or not np.isfinite(max_f) or min_f <= 0 or max_f <= min_f:
        return np.array([]), np.array([]), np.array([])

    N = 3

    n_max = round(N * np.ceil(np.log(max_f / 1000) / np.log(2)) + 1)
    n_max = max(n_max, 1)

    f_above = [1000.0]
    for n in range(n_max):
        f_above.append(f_above[-1] * 10 ** (3 / (10 * N)))
    f_above = np.array(f_above)
    f_above = f_above[f_above < max_f * (2 ** (0.5 / N))]

    n_min = round(N * np.ceil(np.log(1000 / min_f) / np.log(2)) + 1)
    n_min = max(n_min, 1)

    f_below = [1000.0]
    for n in range(n_min):
        f_below.append(f_below[-1] / (10 ** (3 / (10 * N))))
    f_below = np.array(f_below)
    f_below = f_below[f_below > min_f * (2 ** (-0.5 / N))]

    fc = np.unique(np.concatenate([f_below, f_above]))
    fc = fc[(fc < max_f * (2 ** (0.5 / N))) & (fc > min_f * (2 ** (-0.5 / N)))]

    fc_L = fc / (2 ** (1 / (2 * N)))
    fc_U = fc * (2 ** (1 / (2 * N)))

    fc = _ansi_preferred_adjust(fc)
    fc_L = _sd_round(fc_L, 3, 5)
    fc_U = _sd_round(fc_U, 3, 5)

    valid = np.isfinite(fc) & np.isfinite(fc_L) & np.isfinite(fc_U) & (fc > 0) & (fc_L > 0) & (fc_U > fc_L)
    fc = fc[valid]
    fc_L = fc_L[valid]
    fc_U = fc_U[valid]

    if len(fc) > 0 and max_f < fc_U[-1]:
        fc = fc[:-1]
        fc_L = fc_L[:-1]
        fc_U = fc_U[:-1]

    return fc, fc_L, fc_U


def band_rms_velocity(freq, accel_psd, rbw, eu, bands_fc, bands_low, bands_high):
    freq = np.asarray(freq).flatten()
    accel_psd = np.asarray(accel_psd).flatten()

    M = min(len(freq), len(accel_psd))
    if M < 3:
        return np.full(len(bands_fc), np.nan)

    f = freq[1:M]
    a_psd = accel_psd[1:M] * (eu ** 2) / rbw

    valid = np.isfinite(f) & np.isfinite(a_psd) & (f > 0) & (a_psd > 0)
    f = f[valid]
    a_psd = a_psd[valid]

    if len(f) < 2:
        return np.full(len(bands_fc), np.nan)

    v_spec = a_psd / ((2 * np.pi * f) ** 2)

    rms = np.full(len(bands_fc), np.nan)
    for i in range(len(bands_fc)):
        idx = (f >= bands_low[i]) & (f <= bands_high[i])
        if np.any(idx):
            rms[i] = np.sqrt(np.sum(v_spec[idx] * rbw)) * 1e6

    return rms


def vc_criteria_curves():
    f_ref = np.array([4, 8, 80])
    return {
        'f': f_ref,
        'VC-A': np.array([100, 50, 50]),
        'VC-B': np.array([50, 25, 25]),
        'VC-C': np.array([12.5, 12.5, 12.5]),
        'VC-D': np.array([6.25, 6.25, 6.25]),
    }


VC_COLORS = {
    'VC-A': 'rgb(51,51,51)',
    'VC-B': 'rgb(26,102,217)',
    'VC-C': 'rgb(217,51,51)',
    'VC-D': 'rgb(38,153,51)',
}


def dynamic_stiffness(freq, xfer, eu_resp, eu_excite):
    freq = np.asarray(freq).flatten()
    xfer = np.asarray(xfer).flatten()

    M = min(len(freq), len(xfer))
    if M < 3:
        return np.array([]), np.array([])

    f = freq[1:M]
    x = xfer[1:M]

    omega = 2 * np.pi * f
    eu_ratio = eu_resp / eu_excite if eu_excite != 0 else 1.0
    resp = 1.0 / (x / (omega ** 2) * eu_ratio)
    k_abs = np.abs(resp)

    valid = np.isfinite(f) & np.isfinite(k_abs) & (f > 0) & (k_abs > 0)
    return f[valid], k_abs[valid]


def floor_coherence(freq, coh_data):
    freq = np.asarray(freq).flatten()
    coh_data = np.asarray(coh_data).flatten()

    M = min(len(freq), len(coh_data))
    if M < 3:
        return np.array([]), np.array([])

    f = freq[1:M]
    c = coh_data[1:M]

    valid = np.isfinite(f) & np.isfinite(c) & (f > 0)
    return f[valid], c[valid]


def _ansi_preferred_adjust(fc):
    fc5 = _sd_round(fc, 3, 5)
    fc100 = _sd_round(fc, 3, 100)
    out = fc5.copy()
    mask = (np.isfinite(fc5) & np.isfinite(fc100) & (fc100 != 0) &
            (np.abs(100 * (1 - fc5 / fc100)) < 1))
    out[mask] = fc100[mask]
    return out


def _sd_round(x, n_digits, base):
    x = np.asarray(x, dtype=float)
    out = np.zeros_like(x)
    for i in range(len(x)):
        if x[i] <= 0 or not np.isfinite(x[i]):
            out[i] = x[i]
            continue
        d = np.floor(np.log10(x[i]))
        shift = 10.0 ** (d - (n_digits - 1))
        x_shifted = x[i] / shift
        x_rounded = round(x_shifted / base) * base
        if x_rounded == 0:
            x_rounded = base
        out[i] = x_rounded * shift
    return out
