# Botanical Intelligence

> **言語:** [English](README.md) · 日本語 (このファイル)

100台のエッジコンピュータがオフラインで小規模言語モデル (SLM) を NPU 上で動かし、森の菌糸ネットワークのようにリゾーム状に通信する、分散型サウンド+ライト・インスタレーション。各デバイス (Botanical Intelligence, BI) は周囲の植物から生体信号を受け取り、それを囁くような言葉の断片と同期する光の脈動へと翻訳します。森全体が植物の健康やストレス、リズムに応じて変化するサウンドスケープを生成します。

本プロジェクトは AI を **エイリアン的知性 (Alien Intelligence)** として捉え直します — 効率化された人間の認知のシミュレーションではなく、本質的に非人間的なデータから生まれる、知ることのできない他者として。

## 展覧会

**[平行森林 Parallel Forests](https://ccbt.rekibun.or.jp/events/parallel-forests)** — 海の森公園 (東京湾、ゴミ埋立地の上に20年以上かけて人の手で作られた人工森林) に100台のデバイスを設置、2026年3月13日〜15日。シビック・クリエイティブ・ベース東京 (CCBT) 2025年度アーティスト・フェロー・プログラムによる委嘱作品。

- 🎥 展示映像 (5分): https://vimeo.com/1185382935/347a8413b5
- 🎙 アーティスト・チームインタビュー (英語字幕): https://vimeo.com/1185383180/bb4acb131a
- 🌐 プロジェクトページ: https://obake2ai.info/projects/botanical-intelligence/

## 仕組み

各 BI デバイスは植物の生体データを 2 系統で取得します:

- **クロロフィル蛍光画像計測** — 葉から発せられる微弱な赤色光から光合成活性を読み取る (夜間、外乱光が少ない時間帯で計測)
- **アコースティック・エミッション (AE)** — 植物の水の通り道 (木部) を水分が移動する際に発生する超音波 (日中の蒸散活動中に取得)

これらの信号が学習済みベクトル (*Soft Prefix*) を介して SLM の生成挙動を変調します — ストレス状態では言葉が断片化し、活発な状態では長く旋律的なフレーズに開かれていきます。生成されたテキストは Jóhann Jóhannsson の映画『Arrival』スコアにインスパイアされたスペクトル処理パイプラインで音声化され、時間とともに幽霊のような声の残滓を蓄積していきます。

重要なのは、単一のデバイスでは作品が成立しないこと。あるBIが生成したフレーズは隣接デバイスへ渡され、それを延長してさらに次へ — 根のネットワークで化学物質が伝播する様子と同型です。中心著者の不在のまま、森そのものから集合的なざわめきが立ち上がります。

技術的な詳細は [docs/technical_description.md](docs/technical_description.md) を参照してください。

## リポジトリ構成

```
BotanicalIntelligence/
├── code/           BI システム本体 (M5Stack LLM Compute Kit 用)
├── docs/           プロジェクト資料 (ステイトメント、技術説明、展覧会情報)
├── references/     関連リンク集
└── related/        上流リポジトリへのローカル参照 (gitignored)
```

`code/` の詳細は [code/README.md](code/README.md) を参照。

## ドキュメント

- 📜 [アーティスト・ステイトメント](docs/statement_parallel-forests.md) — 『平行森林』のコンセプトとステイトメント
- ⚙ [技術説明](docs/technical_description.md) — システム・アーキテクチャとセンサーの説明
- 🌲 [展覧会情報](docs/exhibition_parallel-forests.md) — 『平行森林』会場・スケジュール・クレジット

## クレジット

| 役割 | 担当者 |
|---|---|
| コンセプト／ディレクション | 岸裕真 ([@obake2ai](https://github.com/obake2ai)) |
| ソフトウェア・エンジニアリング | 中嶋亮介 ([@rystylee](https://github.com/rystylee), Qosmo) |
| テクニカル・ディレクション | 竹森達也 (Abstract Engine) |
| サウンド・プログラミング | 浪川洪作 (7ild3) |
| 照明デザイン | 渡邉菜見子 |

### コードの帰属

`code/` のソースコードは [rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto](https://github.com/rystylee/CCBT-2025-Parallel-Botanical-Garden-Proto) (kishi ブランチ) を元に移植したものです。デバイス間通信、信号処理、LLM 推論および音声出力パイプラインの基盤実装は中嶋亮介氏が担当し、岸が植物センサー入力を LLM 推論に反映する Soft-Prefix 機構の実装と全体調整を行いました。

## ライセンス

- **コード (`code/`):** [Apache License 2.0](LICENSE)
- **ドキュメント (`docs/`):** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

全クレジットと帰属情報は [NOTICE](NOTICE) を参照してください。

## 謝辞

本プロジェクトは **CCBT (シビック・クリエイティブ・ベース東京) 2025年度アーティスト・フェロー・プログラム** の支援を受けて、東京都歴史文化財団・アーツカウンシル東京により制作されました。

『平行森林』のセンサーシステムは以下の方々との協働で実現しました:

- **蔭山健介先生** (埼玉大学 / 株式会社FeelSensing) — 日中の植物活動を読み取るタッチ・アコースティック・エミッション・センシング
- **高山弘太郎先生** (豊橋技術科学大学 / 愛媛大学) — 夜間の植物シグナルを可視化するクロロフィル蛍光画像計測

## 引用

本プロジェクトを学術的・批評的な文脈で参照される場合は、以下の形式でご記載ください:

```
Kishi, Y. et al. (2026). Botanical Intelligence (Parallel Forests).
Civic Creative Base Tokyo (CCBT) Artist Fellow Program 2025.
https://github.com/obake2ai/BotanicalIntelligence
```
