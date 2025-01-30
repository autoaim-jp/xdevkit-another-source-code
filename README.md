# xdevkit-another-source-code

## install

```bash
git clone https://github.com/autoaim-jp/xdevkit-another-source-code
cd ./xdevkit-another-source-code/
cp ./bin/.env.sample ./bin/.env
vi ./bin/.env
echo "alias xasc=$(realpath ./bin/xasc.sh)" >> ~/.bashrc
source ~/.bashrc
```

## usage

```bash
xasc <編集したいファイル>
# viが開くので、追加修正内容を書く。
# :wqaで閉じるとリクエストが開始される。
# しばらくするとvimdiffでオリジナルと提案内容が表示される。必要に応じて反映する。
```

## tree

`tree -Fa --filesfirst -I ".git/|.xdevkit/|*.swp"`

```
./
├── .gitignore
├── backup/ プロンプト、レスポンスなどを格納
│   ├── code ChatGPTのレスポンスから抽出したコードブロック
│   ├── prompt 送信したプロンプト
│   ├── response.json APIのレスポンス全体
│   └── result ChatGPTのレスポンス
└── bin/
    ├── .env ChatGPTのAPIキーを記載
    ├── .env.sample
    └── xasc.sh* メインのシェル

```

