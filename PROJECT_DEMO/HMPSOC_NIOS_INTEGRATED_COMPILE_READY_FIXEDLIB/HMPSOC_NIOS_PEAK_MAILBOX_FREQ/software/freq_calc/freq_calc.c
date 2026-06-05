#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_stdio.h"

#define SAMPLE_RATE_HZ 16000u

static void print_dec(uint32_t value)
{
    char buf[11];
    int i = 10;

    buf[i] = '\0';

    if (value == 0) {
        alt_putchar('0');
        return;
    }

    while (value > 0 && i > 0) {
        i--;
        buf[i] = '0' + (value % 10u);
        value /= 10u;
    }

    alt_putstr(&buf[i]);
}

int main(void)
{
    uint32_t packet_count = 0;
    uint32_t packets_since_print = 0;

    alt_putstr("Nios frequency polling started\n");

    while (1)
    {
        uint32_t valid = IORD(PEAK_VALID_PIO_BASE, 0);

        if (valid & 0x1u)
        {
            uint32_t payload = IORD(PEAK_PAYLOAD_PIO_BASE, 0);

            uint32_t event_spacing = payload + 1u;
            uint32_t full_period_samples = 2u * event_spacing;

            uint32_t freq_hz = 0u;
            if (full_period_samples != 0u)
            {
                freq_hz = SAMPLE_RATE_HZ / full_period_samples;
            }

            /* Always update LED PIO immediately. 40 Hz = 0x28, 80 Hz = 0x50. */
            IOWR(LED_PIO_BASE, 0, freq_hz & 0xffu);

            packet_count++;
            packets_since_print++;

            /*
             * Peak detector fires twice per signal cycle.
             * So event packets per second ~= 2 * frequency.
             * Print once per second-ish.
             */
            uint32_t print_threshold = 2u * freq_hz;
            if (print_threshold == 0u) {
                print_threshold = 1u;
            }

            if (packets_since_print >= print_threshold)
            {
                alt_putstr("payload=");
                print_dec(payload);

                alt_putstr(" freq=");
                print_dec(freq_hz);
                alt_putstr(" Hz");

                alt_putstr(" packets=");
                print_dec(packet_count);
                alt_putstr("\n");

                packets_since_print = 0u;
            }

            IOWR(PEAK_CLEAR_PIO_BASE, 0, 1u);
            IOWR(PEAK_CLEAR_PIO_BASE, 0, 0u);
        }
    }

    return 0;
}
