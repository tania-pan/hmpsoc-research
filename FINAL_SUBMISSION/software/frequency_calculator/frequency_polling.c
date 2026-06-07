#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_stdio.h"

#define SAMPLE_RATE_HZ 16000u

static void print_dec(uint32_t value)
{
    char buf[11]; // max uint32 = 10 digits + null
    int i = 10;

    buf[i] = '\0';

    if (value == 0) {
        alt_putchar('0');
        return;
    }

    while (value > 0 && i > 0) {
        i--;
        buf[i] = '0' + (value % 10);
        value /= 10;
    }

    alt_putstr(&buf[i]);
}

int main(void)
{
    alt_putstr("Nios peak frequency polling started\n");

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

            alt_putstr(" event_spacing=");
            print_dec(event_spacing);

            alt_putstr(" full_period_samples=");
            print_dec(full_period_samples);

            alt_putstr(" freq=");
            print_dec(freq_hz);
            alt_putstr(" Hz\n");

            IOWR(PEAK_CLEAR_PIO_BASE, 0, 1u);
            IOWR(PEAK_CLEAR_PIO_BASE, 0, 0u);
        }
    }

    return 0;
}
