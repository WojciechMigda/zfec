#!/usr/bin/python3
# -*- coding: utf-8 -*-


import matplotlib.pyplot as plt


def main():

    fig, ax = plt.subplots()

    # legacy zfec first

    df = {
        '-O2' : 557.010,
        '-O3 -march=native' : 596.444
    }
    labels, speed = zip(*df.items())

    patches = plt.barh(labels, speed, height=0.5, color='brown')

    for rect, label in zip(patches, labels):
        width = rect.get_width()
        height = rect.get_height()
        x = rect.get_x()
        y = rect.get_y()
        label_x = x + width + 60
        label_y = y + height / 2

        ax.text(label_x, label_y, label, ha='left', va='center', fontsize=9)

    # zfex now

    df = {
        '-O2 -DZFEX_UNROLL_ADDMUL_SIMD=1' : 2096.781,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=1' : 2933.161,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=2' : 3237.656,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=4' : 3585.507,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=8' : 3810.970,
    }
    labels, speed = zip(*df.items())

    patches = plt.barh(labels, speed, height=0.5, color='green')

    for rect, label in zip(patches, labels):
        width = rect.get_width()
        height = rect.get_height()
        x = rect.get_x()
        y = rect.get_y()
        label_x = x + width + 60
        label_y = y + height / 2

        ax.text(label_x, label_y, label, ha='left', va='center', fontsize=9)

    ax.set_xlim([0, 8000])
    ax.axes.yaxis.set_ticklabels([])
    ax.invert_yaxis()
    ax.set_xlabel('Speed, MB/sec')
    ax.set_title("Encoding benchmark of legacy zfec vs. SIMD zfex\nk=7, m=10, size=1000000\nIntel(R) Xeon(R) CPU @ 2.20GHz")
    ax.legend(['zfec::fec_encode', 'zfex::fec_encode_simd'], loc='upper right')

    plt.savefig('bench_intel_k7_m10_1M.png')
    plt.show()

    return 0


if __name__ == '__main__':
    main()
