import numpy as np
from scipy import signal
from scipy.fft import fft, ifft


def butterworth_filter(y, fs, use_low=False, low_cutoff=100.0,
                       use_high=False, high_cutoff=5.0, order=4):
    y = np.asarray(y).flatten()
    if len(y) == 0 or not np.isfinite(fs) or fs <= 0:
        return y

    order = max(1, int(order))
    nyquist = fs / 2.0

    if use_low and use_high:
        if np.isfinite(low_cutoff) and np.isfinite(high_cutoff):
            if high_cutoff >= low_cutoff:
                return y

    try:
        if use_high and np.isfinite(high_cutoff) and 0 < high_cutoff < nyquist:
            wn = high_cutoff / nyquist
            b, a = signal.butter(order, wn, btype='high')
            y = signal.filtfilt(b, a, y)

        if use_low and np.isfinite(low_cutoff) and 0 < low_cutoff < nyquist:
            wn = low_cutoff / nyquist
            b, a = signal.butter(order, wn, btype='low')
            y = signal.filtfilt(b, a, y)
    except Exception:
        return np.asarray(y).flatten()

    return y


def time_window(t, y, t_start=None, t_end=None):
    t = np.asarray(t).flatten()
    y = np.asarray(y).flatten()
    N = min(len(t), len(y))
    t = t[:N]
    y = y[:N]

    mask = np.ones(N, dtype=bool)
    if t_start is not None and np.isfinite(t_start):
        mask &= t >= t_start
    if t_end is not None and np.isfinite(t_end):
        mask &= t <= t_end

    return t[mask], y[mask]


def fft_spectrum(y, fs):
    y = np.asarray(y).flatten()
    N = len(y)
    if N < 2:
        return np.array([]), np.array([])

    y = y - np.mean(y)
    Y = fft(y)
    P2 = np.abs(Y / N)
    P1 = P2[:N // 2 + 1].copy()
    if len(P1) > 2:
        P1[1:-1] = 2 * P1[1:-1]

    f = fs * np.arange(N // 2 + 1) / N
    return f, P1


def periodogram_psd(y, fs):
    y = np.asarray(y).flatten()
    y = y[np.isfinite(y)]
    if len(y) < 2 or not np.isfinite(fs) or fs <= 0:
        return np.array([]), np.array([])

    y = y - np.mean(y)
    try:
        f, psd = signal.periodogram(y, fs)
    except Exception:
        f, psd = fft_spectrum(y, fs)

    valid = np.isfinite(f) & np.isfinite(psd) & (f > 0) & (psd > 0)
    return f[valid], psd[valid]


def vna_psd(aspec, eu, wincor, rbw):
    aspec = np.asarray(aspec).flatten()
    psd = wincor * aspec * (eu ** 2) / rbw
    return psd


def convert_quantity_time(y, fs, target='acceleration', use_high=False, high_cutoff=0):
    y = np.asarray(y).flatten()
    target = target.lower().strip()
    if target == 'acceleration' or len(y) < 2 or not np.isfinite(fs) or fs <= 0:
        return y

    y_work = y - np.mean(y)
    N = len(y_work)
    freq_signed = _signed_freq_vector(N, fs)
    omega = 2 * np.pi * freq_signed
    Y = fft(y_work)

    if use_high and np.isfinite(high_cutoff) and high_cutoff > 0:
        Y[np.abs(freq_signed) < high_cutoff] = 0

    scale = np.zeros_like(omega, dtype=complex)
    nonzero = np.abs(omega) > 0

    if target == 'velocity':
        scale[nonzero] = 1.0 / (1j * omega[nonzero])
        return np.real(ifft(Y * scale)) * 1e6
    elif target == 'displacement':
        scale[nonzero] = -1.0 / (omega[nonzero] ** 2)
        return np.real(ifft(Y * scale)) * 1e6
    return y


def convert_quantity_psd(freq, psd, target='acceleration', use_high=False, high_cutoff=0):
    freq = np.asarray(freq).flatten()
    psd = np.asarray(psd).flatten()

    if len(freq) == 0 or len(psd) == 0 or len(freq) != len(psd):
        return np.array([]), np.array([])

    valid = np.isfinite(freq) & np.isfinite(psd) & (freq > 0) & (psd > 0)
    freq = freq[valid]
    psd = psd[valid]

    target = target.lower().strip()
    omega = 2 * np.pi * freq

    if target == 'velocity':
        psd = psd / (omega ** 2) * 1e12
    elif target == 'displacement':
        psd = psd / (omega ** 4) * 1e12

    if target != 'acceleration' and use_high and np.isfinite(high_cutoff) and high_cutoff > 0:
        keep = freq >= high_cutoff
        freq = freq[keep]
        psd = psd[keep]

    valid = np.isfinite(freq) & np.isfinite(psd) & (freq > 0) & (psd > 0)
    return freq[valid], psd[valid]


def _signed_freq_vector(N, fs):
    if N % 2 == 0:
        k = np.concatenate([np.arange(N // 2 + 1), np.arange(-N // 2 + 1, 0)])
    else:
        k = np.concatenate([np.arange((N - 1) // 2 + 1), np.arange(-((N - 1) // 2), 0)])
    return k * (fs / N)


COLOR_PALETTE = [
    [0.0000, 0.4470, 0.7410],
    [0.8500, 0.3250, 0.0980],
    [0.9290, 0.6940, 0.1250],
    [0.4940, 0.1840, 0.5560],
    [0.4660, 0.6740, 0.1880],
    [0.3010, 0.7450, 0.9330],
    [0.6350, 0.0780, 0.1840],
    [0.2500, 0.2500, 0.2500],
]


def get_series_color(idx):
    c = COLOR_PALETTE[idx % len(COLOR_PALETTE)]
    return f'rgb({int(c[0]*255)},{int(c[1]*255)},{int(c[2]*255)})'
