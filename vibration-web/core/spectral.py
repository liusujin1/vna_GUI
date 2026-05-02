import numpy as np


def transmissibility_db(freq, xfer, eu_ch, eu_ref):
    freq = np.asarray(freq).flatten()
    xfer = np.asarray(xfer).flatten()

    M = min(len(freq), len(xfer))
    if M < 3:
        return np.array([]), np.array([])

    f = freq[1:M]
    x = xfer[1:M]

    if not np.isfinite(eu_ref) or eu_ref == 0:
        return np.array([]), np.array([])

    xfer_corr = x * (eu_ch / eu_ref)
    tr_lin = np.abs(xfer_corr)

    valid = np.isfinite(f) & np.isfinite(tr_lin) & (f > 0) & (tr_lin > 0)
    f = f[valid]
    tr_lin = tr_lin[valid]

    return f, 20 * np.log10(tr_lin)


def coherence(freq, coh_data):
    freq = np.asarray(freq).flatten()
    coh_data = np.asarray(coh_data).flatten()

    M = min(len(freq), len(coh_data))
    if M < 3:
        return np.array([]), np.array([])

    f = freq[1:M]
    c = coh_data[1:M]

    valid = np.isfinite(f) & np.isfinite(c) & (f > 0)
    return f[valid], c[valid]


def cumulative_rms(freq, psd):
    freq = np.asarray(freq).flatten()
    psd = np.asarray(psd).flatten()

    if len(freq) == 0 or len(psd) == 0 or len(freq) != len(psd):
        return np.array([]), np.array([])

    valid = np.isfinite(freq) & np.isfinite(psd) & (freq > 0) & (psd >= 0)
    freq = freq[valid]
    psd = psd[valid]
    if len(freq) < 2:
        return np.array([]), np.array([])

    order = np.argsort(freq)
    freq = freq[order]
    psd = psd[order]

    cum_val = np.zeros_like(freq)
    for i in range(1, len(freq)):
        df = freq[i] - freq[i - 1]
        if np.isfinite(df) and df > 0:
            cum_val[i] = cum_val[i - 1] + 0.5 * (psd[i - 1] + psd[i]) * df
        else:
            cum_val[i] = cum_val[i - 1]

    cum_val = np.maximum(cum_val, 0)
    return freq, 3 * np.sqrt(cum_val)
