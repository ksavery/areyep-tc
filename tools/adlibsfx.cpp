// Render Wolf3D-engine AdLib sound effects (AUDIOT chunks) to WAV files.
//
// Plays each sound through the same OPL2 emulator Wolf4SDL uses (MAME's
// fmopl, compiled from a local Wolf4SDL/eod4sdl checkout - not part of this
// repo) the way id_sd's SDL_ALPlaySound/SDL_ALSoundService does: instrument
// on channel 0, feedback/connection 0, then one data byte per 1/140 s
// (non-zero = frequency low byte + key on with the sound's block, 0 = key off).
//
// build: g++ -O2 -I<wolf4sdl> tools/adlibsfx.cpp <wolf4sdl>/fmopl.cpp -o run/adlibsfx
// usage: adlibsfx AUDIOHED AUDIOT FIRSTCHUNK COUNT OUTDIR [RATE]
//        writes OUTDIR/ADLIBnnn.wav for each non-empty AdLib sound n

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "fmopl.h"

static std::vector<uint8_t> ReadFile(const char *path)
{
	std::vector<uint8_t> data;
	FILE *f = fopen(path, "rb");
	if (!f) { return data; }
	fseek(f, 0, SEEK_END);
	data.resize(ftell(f));
	fseek(f, 0, SEEK_SET);
	if (fread(data.data(), 1, data.size(), f) != data.size()) { data.clear(); }
	fclose(f);
	return data;
}

static void Put32(std::vector<uint8_t> &out, uint32_t v) { for (int i = 0; i < 4; i++) { out.push_back((v >> (8 * i)) & 0xFF); } }
static void Put16(std::vector<uint8_t> &out, uint16_t v) { out.push_back(v & 0xFF); out.push_back(v >> 8); }

static bool WriteWav(const std::string &path, const std::vector<int16_t> &samples, int rate)
{
	std::vector<uint8_t> out;
	uint32_t bytes = samples.size() * 2;
	out.insert(out.end(), {'R', 'I', 'F', 'F'}); Put32(out, 36 + bytes);
	out.insert(out.end(), {'W', 'A', 'V', 'E', 'f', 'm', 't', ' '}); Put32(out, 16);
	Put16(out, 1); Put16(out, 1); Put32(out, rate); Put32(out, rate * 2); Put16(out, 2); Put16(out, 16);
	out.insert(out.end(), {'d', 'a', 't', 'a'}); Put32(out, bytes);
	for (int16_t s : samples) { Put16(out, (uint16_t)s); }

	FILE *f = fopen(path.c_str(), "wb");
	if (!f) { return false; }
	fwrite(out.data(), 1, out.size(), f);
	fclose(f);
	return true;
}

int main(int argc, char **argv)
{
	if (argc < 6)
	{
		fprintf(stderr, "usage: %s AUDIOHED AUDIOT FIRSTCHUNK COUNT OUTDIR [RATE]\n", argv[0]);
		return 1;
	}

	std::vector<uint8_t> head = ReadFile(argv[1]), audiot = ReadFile(argv[2]);
	int first = atoi(argv[3]), count = atoi(argv[4]);
	std::string outdir = argv[5];
	int rate = argc > 6 ? atoi(argv[6]) : 44100;

	if (head.empty() || audiot.empty()) { fprintf(stderr, "cannot read audio files\n"); return 1; }

	auto offset = [&](int chunk) { uint32_t v; memcpy(&v, &head[4 * chunk], 4); return v; };

	YM3812Init(1, 3579545, rate);

	int written = 0;
	for (int n = 0; n < count; n++)
	{
		uint32_t start = offset(first + n), end = offset(first + n + 1);
		if (end <= start || end - start < 23) { continue; } // SoundCommon (6) + instrument (16) + block

		const uint8_t *s = &audiot[start];
		uint32_t length; memcpy(&length, s, 4);
		const uint8_t *inst = s + 6;
		uint8_t block = s[22];
		const uint8_t *data = s + 23;
		if (length > end - start - 23) { length = end - start - 23; }
		if (!(inst[6] | inst[7])) { continue; } // mSus | cSus: id_sd rejects these as bad instruments

		YM3812ResetChip(0);
		YM3812Write(0, 0x01, 0x20); // waveform select enable, as SD_Startup does
		YM3812Write(0, 0xBD, 0);    // alEffects

		static const uint8_t regs[5] = { 0x20, 0x40, 0x60, 0x80, 0xE0 }; // char, scale, attack, sus, wave
		for (int r = 0; r < 5; r++)
		{
			YM3812Write(0, regs[r] + 0, inst[r * 2]);     // modulator (cell 0)
			YM3812Write(0, regs[r] + 3, inst[r * 2 + 1]); // carrier (cell 3)
		}
		YM3812Write(0, 0xC0, 0); // alFeedCon: id_sd forces 0 (MUSE compatibility)

		uint8_t keyblock = ((block & 7) << 2) | 0x20;
		std::vector<int16_t> samples;
		std::vector<INT16> buf(rate / 140 + 1);

		// Wolf4SDL's fmopl writes interleaved stereo (the same value twice)
		auto render = [&](int frames)
		{
			buf.resize(frames * 2);
			YM3812UpdateOne(0, buf.data(), frames);
			for (int i = 0; i < frames; i++) { samples.push_back(buf[i * 2]); }
		};

		for (uint32_t i = 0; i < length; i++)
		{
			if (data[i]) { YM3812Write(0, 0xA0, data[i]); YM3812Write(0, 0xB0, keyblock); }
			else { YM3812Write(0, 0xB0, 0); }
			render(rate / 140);
		}
		YM3812Write(0, 0xB0, 0);
		render(rate / 4); // let the release ring out

		// Trim trailing near-silence
		size_t keep = samples.size();
		while (keep > 0 && abs(samples[keep - 1]) < 8) { keep--; }
		samples.resize(keep);
		if (samples.empty()) { continue; }

		char name[64];
		snprintf(name, sizeof(name), "/ADLIB%03d.wav", n);
		if (WriteWav(outdir + name, samples, rate)) { written++; }
	}

	printf("%d sounds written\n", written);
	return 0;
}
