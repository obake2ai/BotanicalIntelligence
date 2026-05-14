# Botanical Intelligence

> **Languages:** English (this file) · [日本語](README.ja.md)

A distributed sound-and-light installation in which 100 edge computers, each running a small language model (SLM) offline on an onboard NPU, form a rhizomatic network modeled on the mycorrhizal communication systems of forests. Each device — a *Botanical Intelligence* (BI) — receives live biosignals from surrounding vegetation and translates them into whispered fragments of language and synchronized pulses of light, producing a site-responsive soundscape that shifts with the plants' health, stress, and rhythms.

The project reframes AI as **Alien Intelligence** — not a simulation of human cognition optimized for efficiency, but an unknowable other whose outputs arise from genuinely nonhuman data.

## Exhibition

**[Parallel Forests](https://ccbt.rekibun.or.jp/events/parallel-forests)** — 100 devices installed in Umi-no-Mori, Tokyo Bay (a public forest planted over two decades atop a sealed landfill), 13–15 March 2026. Commissioned by Civic Creative Base Tokyo (CCBT) as part of the 2025 Artist Fellow Program.

- 🎥 Installation footage (5 min): https://vimeo.com/1185382935/347a8413b5
- 🎙 Artist & team interview (English subtitles): https://vimeo.com/1185383180/bb4acb131a
- 🌐 Project page: https://obake2ai.info/projects/botanical-intelligence/

## How it works

Each BI unit ingests two streams of plant physiological data:

- **Chlorophyll fluorescence imaging** captures photosynthetic vitality through faint red light emitted by leaves (used at night, when ambient light is low).
- **Acoustic emissions (AE)** are ultrasonic micro-sounds produced when water moves through plant vessels (captured during the day, when transpiration is active).

These signals modulate a learned vector (*Soft Prefix*) that steers the SLM's generative behavior — when a plant is stressed, the language fractures; when thriving, it opens into longer, melodic phrases. The text is voiced through a spectral processing pipeline inspired by Jóhann Jóhannsson's score for *Arrival*, layering ghostly vocal residues over time.

Crucially, no single device produces the work. When one BI generates a phrase, it passes to neighbors who extend it before relaying onward — mirroring how chemical signals propagate through root networks. The result is a collective murmur from the forest itself, with no central author.

See [docs/technical_description.md](docs/technical_description.md) for the full technical breakdown.

## Repository structure

```
BotanicalIntelligence/
├── code/           BI system (M5Stack LLM Compute Kit)
├── docs/           Project documentation (statement, technical description, exhibition info)
├── references/     External links
└── related/        Local references to upstream repos (gitignored)
```

The codebase under `code/` is detailed in [code/README.md](code/README.md).

## Documentation

- 📜 [Artist statement (JA)](docs/statement_parallel-forests.md) — concept and statement for *Parallel Forests*
- ⚙ [Technical description (JA)](docs/technical_description.md) — system architecture and sensor explanations
- 🌲 [Exhibition info (JA)](docs/exhibition_parallel-forests.md) — *Parallel Forests* venue, schedule, credits

## Credits

| Role | Name |
|---|---|
| Concept / Direction | Yuma Kishi ([@obake2ai](https://github.com/obake2ai)) |
| Software Engineering | Ryosuke Nakajima ([@rystylee](https://github.com/rystylee), Qosmo) |
| Technical Direction | Tatsuya Takemori (Abstract Engine) |
| Sound Programming | Kosaku Namikawa (7ild3) |
| Lighting Design | Namiko Watanabe |

### Code attribution

The source code under `code/` is ported from [rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto](https://github.com/rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto) (kishi branch). The foundational implementation of inter-device communication, signal processing, and the LLM inference / audio output pipeline was authored by Ryosuke Nakajima; Yuma Kishi added the Soft-Prefix mechanism (which feeds plant biosignals into LLM inference) and the overall project coordination.

## License

- **Code (`code/`):** [Apache License 2.0](LICENSE)
- **Documentation (`docs/`):** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

Full attribution and contributor list: [NOTICE](NOTICE).

## Acknowledgments

This project was developed as part of the **CCBT (Civic Creative Base Tokyo) Artist Fellow Program 2025**, supported by Arts Council Tokyo and Tokyo Metropolitan Foundation for History and Culture.

The sensor systems for *Parallel Forests* were realized in collaboration with:

- **Kensuke Kageyama** (Saitama University / FeelSensing) — touch-acoustic-emission sensing for daytime plant activity
- **Kotaro Takayama** (Toyohashi University of Technology / Ehime University) — chlorophyll fluorescence imaging for nighttime plant signaling

## Citation

If you reference this project in academic or critical writing, please cite:

```
Kishi, Y. et al. (2026). Botanical Intelligence (Parallel Forests).
Civic Creative Base Tokyo (CCBT) Artist Fellow Program 2025.
https://github.com/obake2ai/BotanicalIntelligence
```
