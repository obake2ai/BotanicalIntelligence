# Botanical Intelligence

植物の生体データとSLM（小規模言語モデル）ネットワークによる分散型サウンドインスタレーション。

## Overview

「Botanical Intelligence（BI）」は、周囲の森林・植物の生体データを取得し、人間の聞こえる音として生成する小型エッジデバイス群によるプロジェクトです。各デバイスはローカルで完結しながら、周囲の他のBIとリゾーム状にネットワークを形成し、トークンを共有しながら音を生成します。

- **コンセプト／ディレクション:** 岸裕真
- **テクニカル・ディレクション:** 竹森達也（Abstract Engine）
- **ソフトウェア・エンジニアリング:** 中嶋亮介（Qosmo）
- **サウンド・エンジニアリング:** 浪川洪作（7ild3）
- **照明デザイン:** 渡邉菜見子

## Code Attribution

`code/` ディレクトリのソースコードは [rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto](https://github.com/rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto)（kishiブランチ）を元に移植したものです。オリジナルのソフトウェア開発は中嶋亮介氏（[@rystylee](https://github.com/rystylee)）によるものです。

## Structure

```
BotanicalIntelligence/
├── code/           # BIシステム本体（M5Stack LLM Compute Kit用）
├── docs/           # プロジェクト資料・ステイトメント
└── references/     # 関連リンク集
```

コードの詳細は [code/README.md](code/README.md) を参照してください。

## License

- **コード（`code/`）:** [Apache License 2.0](LICENSE)
- **ドキュメント（`docs/`）:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

詳細は [NOTICE](NOTICE) を参照してください。

## Acknowledgments

本プロジェクトは CCBT（シビック・クリエイティブ・ベース東京）2025年度アーティスト・フェロー・プログラムの支援を受けて制作されました。
