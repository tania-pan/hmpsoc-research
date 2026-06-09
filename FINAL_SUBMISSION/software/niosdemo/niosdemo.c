#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_stdio.h"
#include "sys/alt_alarm.h"
#include <unistd.h>

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

    // Variables for poll timing
    uint32_t poll_count = 0;
    uint32_t last_ticks = alt_nticks();
    uint32_t ticks_per_sec = alt_ticks_per_second();

    alt_putstr("Nios frequency polling started\n");

    while (1)
    {
        uint32_t valid = IORD(PEAK_VALID_PIO_BASE, 0);
        poll_count++; // Increment poll counter on every loop

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
                // Calculate elapsed time and polling rate
                uint32_t now = alt_nticks();
                uint32_t elapsed_ticks = now - last_ticks;
                if (elapsed_ticks == 0) elapsed_ticks = 1; // Prevent division by zero

                uint32_t polls_per_sec = (poll_count * ticks_per_sec) / elapsed_ticks;

                // Calculate period in microseconds to preserve the decimal places
                uint32_t poll_period_us = 0;
                if (polls_per_sec > 0) {
                    poll_period_us = 1000000u / polls_per_sec;
                }

                // Split into whole milliseconds and fractional milliseconds
                uint32_t ms_whole = poll_period_us / 1000u;
                uint32_t ms_frac  = poll_period_us % 1000u;

                // Print Payload, Frequency, and Packets
                alt_putstr("payload=");
                print_dec(payload);

                alt_putstr(" freq=");
                print_dec(freq_hz);
                alt_putstr(" Hz");

                alt_putstr(" packets=");
                print_dec(packet_count);

                // Print Polling Stats with exact decimal unrounded ms
                alt_putstr(" | rate=");
                print_dec(polls_per_sec);
                alt_putstr(" polls/s period=");
                print_dec(ms_whole);
                alt_putchar('.');

                // Manually add leading zeros for the fraction (e.g., .005 instead of .5)
                if (ms_frac < 100u) alt_putchar('0');
                if (ms_frac < 10u)  alt_putchar('0');
                print_dec(ms_frac);

                alt_putstr(" ms\n");

                // Reset counters
                packets_since_print = 0u;
                poll_count = 0u;
                last_ticks = now;
            }

            IOWR(PEAK_CLEAR_PIO_BASE, 0, 1u);
            IOWR(PEAK_CLEAR_PIO_BASE, 0, 0u);
        }

        // 2000 microsecond (2 ms) delay
        usleep(2000);
    }

    return 0;
}
