#!/bin/bash

# スクリプト名: ./xasc.sh

# 引数が指定されていない場合はエラーを表示して終了
if [[ $# -eq 0 ]]; then
  echo "エラー: ファイルが指定されていません。使用方法: xasc.sh <ファイルパス>"
  exit 1
fi

FILE_PATH=$1
SCRIPT_DIR=$(dirname "$0")
ENV_FILE="$SCRIPT_DIR/.env"
mkdir -p "$SCRIPT_DIR/../backup/"
PROMPT_NOTE=$(cat <<EOF
必ず、修正箇所の前後数行も一緒に表示してください。
以下が修正対象のファイル内容です：
EOF
)
# PROMPT_NOTE=$(cat <<EOF
# 修正箇所はユニファイドフォーマット（\`diff -u\`）で出力してください。フォーマットの要件は以下の通りです：
# 1. 修正前（\`---\`）と修正後（\`+++\`）にはファイル名[$FILE_PATH]を含めてください。
# 2. 修正箇所の前後に3行のコンテキストを含めてください。
# 3. 修正箇所の行番号を指定してください（例: \`@@ -X,Y +X,Y @@\`）。
# 以下が修正対象のファイル内容です：
# EOF
# )


# gitリポジトリ内でない場合はエラーを表示して終了
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "エラー: gitリポジトリ内ではありません。"
  exit 1
fi

# 現在のブランチがmasterの場合はエラーを表示して終了
if [[ $(git branch --show-current) == "master" ]]; then
  echo "エラー: 現在のブランチはmasterです。別のブランチに切り替えてください。"
  exit 1
fi

# .envファイルが存在しない場合はエラーを表示して終了
if [[ ! -f $ENV_FILE ]]; then
  echo "エラー: .envファイルが見つかりません。"
  exit 1
fi

# .envファイルを読み込む
source "$ENV_FILE"

# 指定されたファイルが変更されているか、未追跡ファイルであるかを確認
if [[ -n $(git ls-files --modified --others --exclude-standard "$FILE_PATH") ]]; then
  echo -n "$FILE_PATH は変更されているか、未追跡のファイルです。編集を続けますか？ (y/n/diff/vi): "
  read -r answer
  if [[ $answer == "vi" ]]; then
    vi "$FILE_PATH"
    echo -n "$FILE_PATH は変更されているか、未追跡のファイルです。編集を続けますか？ (y/n): "
    read -r answer
  elif [[ $answer == "diff" ]]; then
    git diff
    echo -n "$FILE_PATH は変更されているか、未追跡のファイルです。編集を続けますか？ (y/n): "
    read -r answer
  fi
  if [[ $answer != "y" ]]; then
    echo "終了します。"
    exit 0
  fi
fi

# 指定されたファイルが存在しない場合はエラーを表示して終了
if [[ ! -f $FILE_PATH ]]; then
  echo "エラー: ファイル $FILE_PATH が存在しません。"
  exit 1
fi

# ファイルの内容をFILE_CONTENT_STRに読み込む
# FILE_CONTENT_STR=$(cat -n $FILE_PATH)
FILE_CONTENT_STR=$(cat $FILE_PATH)

# プロンプトの入力を受け付ける
# catでヒアドキュメントで、プロンプトを受け取る
# echo "[info] プロンプトを入力してください (Ctrl+Dで終了):"
# PROMPT_STR=$(cat)

# 一時ファイルを作成してgeditで開き、プロンプトを受け取る
TMP_FILE=$(mktemp /tmp/__xasc_XXXXXX)
trap "rm -f $TMP_FILE" EXIT   # スクリプト終了時に一時ファイルを削除
echo "[info] プロンプトを入力してください。"
# gedit "$TMP_FILE" &> /dev/null
vi "$TMP_FILE"

# プロンプトの内容を読み込む
PROMPT_STR=$(cat "$TMP_FILE")
echo -e "$PROMPT_STR"

# プロンプトが空の場合はエラーを表示して終了
if [[ -z $PROMPT_STR ]]; then
  echo "エラー: プロンプトが入力されていません。"
  exit 1
fi
echo "[info] 問い合わせています。お待ちください。>"

# プロンプトをpromptに保存
echo -e "${PROMPT_STR}\n${PROMPT_NOTE}\n${FILE_CONTENT_STR}" > "$SCRIPT_DIR/../backup/prompt"

# APIキーが設定されていない場合はエラーを表示して終了
if [[ -z $OPENAI_CHATGPT_API_KEY ]]; then
  echo "エラー: .envファイルにOPENAI_CHATGPT_API_KEYが設定されていません。"
  exit 1
fi

# ChatGPT APIをcurlで呼び出す
# echo debug
# CHATGPT_RESPONSE=$(cat "$SCRIPT_DIR/../backup/response.json")
CHATGPT_RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
  -H "Authorization: Bearer $OPENAI_CHATGPT_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg content "${PROMPT_STR}\n${PROMPT_NOTE}\n${FILE_CONTENT_STR}" \
    '{model: "gpt-4o", messages: [{role: "system", content: "You are a helpful assistant."}, {role: "user", content: $content}]}')")
# response.jsonに書き込む
echo "$CHATGPT_RESPONSE" | jq . > "$SCRIPT_DIR/../backup/response.json"

# レスポンスからメッセージ内容を取得してresultに書き込む
echo "$CHATGPT_RESPONSE" | jq -r '.choices[0].message.content' > "$SCRIPT_DIR/../backup/result"

# コードブロックを抽出してcodeに書き込む
# CODE_BLOCK=$(echo "$CHATGPT_RESPONSE" | jq -r '.choices[0].message.content' | awk '/^```/,/^```$/' | sed '/^```/d')
CODE_BLOCK=""
in_code_block=false
while IFS= read -r line; do
  if [[ "$line" == '```'* ]]; then
    # コードブロックの開始・終了を切り替える
    if $in_code_block; then
      in_code_block=false
    else
      in_code_block=true
    fi
  elif $in_code_block; then
    # コードブロック内の行を抽出
    echo "$line"
    CODE_BLOCK="${CODE_BLOCK}\n${line}"
  fi
done < "$SCRIPT_DIR/../backup/result"


if [[ -n $CODE_BLOCK ]]; then
  echo -e "$CODE_BLOCK" > "$SCRIPT_DIR/../backup/code"

  echo "diff "$(realpath "$FILE_PATH")" "$(realpath "$SCRIPT_DIR/../backup/code")
  diff-so-fancy $(realpath "$FILE_PATH") $(realpath "$SCRIPT_DIR/../backup/code") 2>/dev/null
  # meld $(realpath "$FILE_PATH") $(realpath "$SCRIPT_DIR/../backup/code") 2>/dev/null
  vimdiff "$FILE_PATH" $(realpath "$SCRIPT_DIR/../backup/code")
  # echo "$CODE_BLOCK" > "$FILE_PATH"
  # patch "$FILE_PATH" < "$SCRIPT_DIR/../backup/code"
else
  echo "エラー: レスポンスにコードブロックが見つかりませんでした。"
  echo "レスポンス全体を表示します。"
  echo "$CHATGPT_RESPONSE" | jq -r '.choices[0].message.content'
  exit 1
fi

# ファイルの差分を表示
git diff "$FILE_PATH"

