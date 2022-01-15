/*
 * Voice call audio setup tool
 *
 * Copyright (C) 2020  Ondřej Jirman <megous@megous.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * 2020-09-29: Updated for the new Samuel's digital codec driver
 */

#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>
#include <fcntl.h>
#include <sys/ioctl.h>

#include <sound/asound.h>
#include <sound/tlv.h>

#define ARRAY_SIZE(a) (sizeof((a)) / sizeof((a)[0]))

void syscall_error(int is_err, const char* fmt, ...)
{
	va_list ap;

	if (!is_err)
		return;

	printf("ERROR: ");
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf(": %s\n", strerror(errno));

	exit(1);
}

void error(const char* fmt, ...)
{
	va_list ap;

	printf("ERROR: ");
	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	printf("\n");

	exit(1);
}

struct audio_control_state {
	char name[128];
	union {
		int64_t i[4];
		const char* e[4];
	} vals;
	bool used;
};

static bool audio_restore_state(struct audio_control_state* controls, int n_controls)
{
	int fd;
	int ret;

	fd = open("/dev/snd/controlC2", O_CLOEXEC | O_NONBLOCK);
	if (fd < 0)
		error("failed to open card\n");

	struct snd_ctl_elem_list el = {
		.offset = 0,
		.space = 0,
	};
	ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_LIST, &el);
	syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_LIST failed");

	struct snd_ctl_elem_id ids[el.count];
	el.pids = ids;
	el.space = el.count;
	ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_LIST, &el);
	syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_LIST failed");

	for (int i = 0; i < el.used; i++) {
		struct snd_ctl_elem_info inf = {
			.id = ids[i],
		};

		ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_INFO, &inf);
		syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_INFO failed");

		if ((inf.access & SNDRV_CTL_ELEM_ACCESS_READ) && (inf.access & SNDRV_CTL_ELEM_ACCESS_WRITE)) {
			struct snd_ctl_elem_value val = {
				.id = ids[i],
			};
			int64_t cval = 0;

			ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_READ, &val);
			syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_READ failed");

			struct audio_control_state* cs = NULL;
			for (int j = 0; j < n_controls; j++) {
				if (!strcmp(controls[j].name, ids[i].name)) {
					cs = &controls[j];
					break;
				}
			}

			if (!cs) {
				printf("Control \"%s\" si not defined in the controls state\n", ids[i].name);
				continue;
			}

			cs->used = 1;

			// check if value needs changing

			switch (inf.type) {
			case SNDRV_CTL_ELEM_TYPE_BOOLEAN:
			case SNDRV_CTL_ELEM_TYPE_INTEGER:
				for (int j = 0; j < inf.count; j++) {
					if (cs->vals.i[j] != val.value.integer.value[j]) {
						// update
						//printf("%s <=[%d]= %"PRIi64"\n", ids[i].name, j, cs->vals.i[j]);

						val.value.integer.value[j] = cs->vals.i[j];
						ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_WRITE, &val);
						syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_WRITE failed");
					}
				}

				break;
			case SNDRV_CTL_ELEM_TYPE_INTEGER64:
				for (int j = 0; j < inf.count; j++) {
					if (cs->vals.i[j] != val.value.integer64.value[j]) {
						// update
						//printf("%s <=[%d]= %"PRIi64"\n", ids[i].name, j, cs->vals.i[j]);

						val.value.integer64.value[j] = cs->vals.i[j];
						ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_WRITE, &val);
						syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_WRITE failed");
					}
				}

				break;

			case SNDRV_CTL_ELEM_TYPE_ENUMERATED: {
				for (int k = 0; k < inf.count; k++) {
					int eval = -1;
					for (int j = 0; j < inf.value.enumerated.items; j++) {
						inf.value.enumerated.item = j;

						ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_INFO, &inf);
						syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_INFO failed");

						if (!strcmp(cs->vals.e[k], inf.value.enumerated.name)) {
							eval = j;
							break;
						}
					}

					if (eval < 0)
						error("enum value %s not found\n", cs->vals.e[k]);

					if (eval != val.value.enumerated.item[k]) {
						// update
						//printf("%s <=%d= %s\n", ids[i].name, k, cs->vals.e[k]);

						val.value.enumerated.item[k] = eval;
						ret = ioctl(fd, SNDRV_CTL_IOCTL_ELEM_WRITE, &val);
						syscall_error(ret < 0, "SNDRV_CTL_IOCTL_ELEM_WRITE failed");
					}
				}

				break;
			}
			}
		}
	}

	for (int j = 0; j < n_controls; j++)
		if (!controls[j].used)
			printf("Control \"%s\" is defined in state but not present on the card\n", controls[j].name);

	close(fd);
	return true;
}

struct audio_setup {
	bool mic_on;
	bool spk_on;
	bool hp_on;
	bool ear_on;
	bool hpmic_on;

	// when sending audio to modem from AIF1 R, also play that back
	// to me locally (just like AIF1 L plays just to me)
	//
	// this is to monitor what SW is playing to the modem (so that
	// I can hear my robocaller talking)
	bool modem_playback_monitor;

	// enable modem routes to DAC/from ADC (spk/mic)
	// digital paths to AIF1 are always on
	bool to_modem_on;
	bool from_modem_on;

	// shut off/enable all digital paths to the modem:
	// keep this off until the call starts, then turn it on
	bool dai2_en;

	int mic_gain;
	int hpmic_gain;
	int spk_vol;
	int ear_vol;
	int hp_vol;
};

static void audio_set_controls(struct audio_setup* s)
{
	struct audio_control_state controls[] = {
		//
                // Analog input:
		//

		// Mic 1 (daughterboard)
		{ .name = "Mic1 Boost Volume",                              .vals.i = { s->mic_gain } },

		// Mic 2 (headphones)
		{ .name = "Mic2 Boost Volume",                              .vals.i = { s->hpmic_gain } },

		// Line in (unused on PP)
		// no controls yet

                // Input mixers before ADC

		{ .name = "Mic1 Capture Switch",                            .vals.i = { !!s->mic_on, !!s->mic_on } },
		{ .name = "Mic2 Capture Switch",                            .vals.i = { !!s->hpmic_on, !!s->hpmic_on } },
		{ .name = "Line In Capture Switch",                         .vals.i = { 0, 0 } }, // Out Mix -> In Mix
		{ .name = "Mixer Capture Switch",                           .vals.i = { 0, 0 } },
		{ .name = "Mixer Reversed Capture Switch",                  .vals.i = { 0, 0 } },

		// ADC
		{ .name = "ADC Gain Capture Volume",                        .vals.i = { 0 } },
		{ .name = "ADC Capture Volume",                             .vals.i = { 160, 160 } }, // digital gain

		//
                // Digital paths:
		//

		// AIF1 (SoC)

		// AIF1 slot0 capture mixer sources
		{ .name = "AIF1 Data Digital ADC Capture Switch",           .vals.i = { 1, 0 } },
		{ .name = "AIF1 Slot 0 Digital ADC Capture Switch",         .vals.i = { 0, 0 } },
		{ .name = "AIF2 Digital ADC Capture Switch",                .vals.i = { 0, 1 } },
		{ .name = "AIF2 Inv Digital ADC Capture Switch",            .vals.i = { 0, 0 } }, //XXX: capture right from the left AIF2?

		// AIF1 slot0 capture/playback mono mixing/digital volume
		{ .name = "AIF1 AD0 Capture Volume",                        .vals.i = { 160, 160 } },
		{ .name = "AIF1 AD0 Stereo Capture Route",                  .vals.e = { "Stereo", "Stereo" } },
		{ .name = "AIF1 DA0 Playback Volume",                       .vals.i = { 160, 160 } },
		{ .name = "AIF1 DA0 Stereo Playback Route",                 .vals.e = { "Stereo", "Stereo" } },

		// AIF2 (modem)

		// AIF2 capture mixer sources
		{ .name = "AIF2 ADC Mixer ADC Capture Switch",              .vals.i = { !!s->to_modem_on && !!s->dai2_en, 0 } }, // from adc/mic
		{ .name = "AIF2 ADC Mixer AIF1 DA0 Capture Switch",         .vals.i = { 0, 1 } }, // from aif1 R
		{ .name = "AIF2 ADC Mixer AIF2 DAC Rev Capture Switch",     .vals.i = { 0, 0 } },

		// AIF2 capture/playback mono mixing/digital volume
		{ .name = "AIF2 ADC Capture Volume",                        .vals.i = { 160, 160 } },
		{ .name = "AIF2 DAC Playback Volume",                       .vals.i = { 160, 160 } },
		{ .name = "AIF2 ADC Stereo Capture Route",                  .vals.e = { "Mix Mono", "Mix Mono" } }, // we mix because we're sending two channels (from mic and AIF1 R)
		{ .name = "AIF2 DAC Stereo Playback Route",                 .vals.e = { "Sum Mono", "Sum Mono" } },  // we sum because modem is sending a single channel

                // AIF3 (bluetooth)

		{ .name = "AIF3 ADC Source Capture Route",                  .vals.e = { "None" } },
		{ .name = "AIF2 DAC Source Playback Route",                 .vals.e = { "AIF2" } },

		// DAC

		// DAC input mixers (sources from ADC, and AIF1/2)
		{ .name = "ADC Digital DAC Playback Switch",                .vals.i = { 0, 0 } }, // we don't play our mic to ourselves
		{ .name = "AIF1 Slot 0 Digital DAC Playback Switch",        .vals.i = { 1, !!s->modem_playback_monitor } },
		{ .name = "AIF2 Digital DAC Playback Switch",               .vals.i = { 0, !!s->dai2_en && !!s->from_modem_on } },

		//
		// Analog output:
		//

		// Output mixer after DAC

		{ .name = "DAC Playback Switch",                            .vals.i = { 1, 1 } },
		{ .name = "DAC Reversed Playback Switch",                   .vals.i = { 1, 1 } },
		{ .name = "DAC Playback Volume",                            .vals.i = { 160, 160 } },
		{ .name = "Mic1 Playback Switch",                           .vals.i = { 0, 0 } },
		{ .name = "Mic1 Playback Volume",                           .vals.i = { 0 } },
		{ .name = "Mic2 Playback Switch",                           .vals.i = { 0, 0 } },
		{ .name = "Mic2 Playback Volume",                           .vals.i = { 0 } },
		{ .name = "Line In Playback Switch",                        .vals.i = { 0, 0 } },
		{ .name = "Line In Playback Volume",                        .vals.i = { 0 } },

                // Outputs

		{ .name = "Earpiece Source Playback Route",		    .vals.e = { "Left Mixer" } },
		{ .name = "Earpiece Playback Switch",                       .vals.i = { !!s->ear_on } },
		{ .name = "Earpiece Playback Volume",                       .vals.i = { s->ear_vol } },

		{ .name = "Headphone Source Playback Route",                .vals.e = { "Mixer", "Mixer" } },
		{ .name = "Headphone Playback Switch",                      .vals.i = { !!s->hp_on, !!s->hp_on } },
		{ .name = "Headphone Playback Volume",                      .vals.i = { s->hp_vol } },

		// Loudspeaker
		{ .name = "Line Out Source Playback Route",                 .vals.e = { "Mono Differential", "Mono Differential" } },
		{ .name = "Line Out Playback Switch",                       .vals.i = { !!s->spk_on, !!s->spk_on } },
		{ .name = "Line Out Playback Volume",                       .vals.i = { s->spk_vol } },
	};

	audio_restore_state(controls, ARRAY_SIZE(controls));
}

static struct audio_setup audio_setup = {
	.mic_on = false,
	.ear_on = false,
	.spk_on = false,
	.hp_on = false,
	.hpmic_on = false,

	.from_modem_on = true,
	.to_modem_on = true,
	.modem_playback_monitor = false,

	.dai2_en = false,

	.hp_vol = 15,
	.spk_vol = 15,
	.ear_vol = 31,
	.mic_gain = 1,
	.hpmic_gain = 1,
};

int main(int ac, char* av[])
{
	int opt;

	while ((opt = getopt(ac, av, "smhle2")) != -1) {
		switch (opt) {
		case 's':
			audio_setup.spk_on = 1;
			break;
		case 'm':
			audio_setup.mic_on = 1;
			break;
		case 'h':
			audio_setup.hp_on = 1;
			break;
		case 'l':
			audio_setup.hpmic_on = 1;
			break;
		case 'e':
			audio_setup.ear_on = 1;
			break;
		case '2':
			audio_setup.dai2_en = 1;
			break;
		default: /* '?' */
			fprintf(stderr, "Usage: %s [-s] [-m] [-h] [-l] [-e] [-2]\n", av[0]);
			exit(EXIT_FAILURE);
		}
	}

	audio_set_controls(&audio_setup);
	return 0;
}
