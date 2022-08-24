#!/usr/bin/python3
# -*- coding: utf-8 -*-


import matplotlib.pyplot as plt


def main():

    fig, ax = plt.subplots()

    # legacy zfec first

    df = {
        '-O2' : 51.804,
        '-O3 -march=native' : 53.105
    }
    labels, speed = zip(*df.items())

    patches = plt.barh(labels, speed, height=0.5, color='brown')

    for rect, label in zip(patches, labels):
        width = rect.get_width()
        height = rect.get_height()
        x = rect.get_x()
        y = rect.get_y()
        label_x = x + width + 6
        label_y = y + height / 2

        ax.text(label_x, label_y, label, ha='left', va='center', fontsize=9)

    # zfex now

    df = {
        '-O2 -DZFEX_UNROLL_ADDMUL_SIMD=1' : 169.997,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=1' : 251.576,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=2' : 275.800,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=4' : 279.742,
        '-O3 -DZFEX_UNROLL_ADDMUL_SIMD=8' : 261.318,
    }
    labels, speed = zip(*df.items())

    patches = plt.barh(labels, speed, height=0.5, color='green')

    for rect, label in zip(patches, labels):
        width = rect.get_width()
        height = rect.get_height()
        x = rect.get_x()
        y = rect.get_y()
        label_x = x + width + 6
        label_y = y + height / 2

        ax.text(label_x, label_y, label, ha='left', va='center', fontsize=9)

    ax.set_xlim([0, 600])
    ax.axes.yaxis.set_ticklabels([])
    ax.invert_yaxis()
    ax.set_xlabel('Speed, MB/sec')
    ax.set_title("Encoding benchmark of legacy zfec vs. SIMD zfex\nk=223, m=255, size=43488\nIntel(R) Xeon(R) CPU @ 2.20GHz")
    ax.legend(['zfec::fec_encode', 'zfex::fec_encode_simd'], loc='upper right')

    plt.savefig('bench_intel_k223_m255_43488.png')
    plt.show()

    return 0


if __name__ == '__main__':
    main()
