#!/bin/bash
set -o allexport
source .env
set +o allexport

# Check argument
if [[ $# -eq 0 ]]; then
    echo "ERROR: No File Specified!"
    exit 1
fi

FILE="$1"
BOT_MSG_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"

# Validate file
if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File not found: $FILE"
    exit 1
fi

# Check jq
command -v jq >/dev/null || {
    echo "ERROR: jq not installed. Install via: sudo apt install jq"
    exit 1
}

FILESIZE=$(du -sh "$FILE" | cut -f1)

echo "📁 File: $FILE"
echo "📦 Size: $FILESIZE"
echo "📡 Trying GoFile servers..."
echo

# Notify telegram
curl -s -X POST "$BOT_MSG_URL" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="📤 *Upload Started*
📁 File: \`$FILE\`
📦 Size: $FILESIZE" > /dev/null

echo "🔎 Scanning GoFile servers API..."
mapfile -t SERVERS < <(curl -s "https://api.gofile.io/servers" | jq -r '.data.servers[].name')

if [[ "${#SERVERS[@]}" -eq 0 ]]; then
    echo "ERROR: Could not resolve any GoFile server from the API."
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        -d text="⚠️ *Upload Aborted*
📁 File: \`$FILE\`
❌ Could not resolve any GoFile server." > /dev/null
    exit 1
fi

echo "📡 Found ${#SERVERS[@]} servers: ${SERVERS[*]}"
echo
SUCCESS=0

for S in "${SERVERS[@]}"; do
    echo "➡️  Trying server: $S ..."
    RESP=$(curl -4 --http1.1 --progress-bar \
        -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")
    STATUS=$(echo "$RESP" | jq -r '.status')

    if [[ "$STATUS" == "ok" ]]; then
        LINK=$(echo "$RESP" | jq -r '.data.downloadPage')
        echo
        echo "✅ Upload Successful on ${S}"
        echo "🔗 Link: $LINK"

        # Notify telegram on success
        curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="Markdown" \
            -d text="✅ *Upload Successful*
📁 File: \`$FILE\`
📦 Size: $FILESIZE
🌐 Server: $S
🔗 Link: $LINK" > /dev/null

        SUCCESS=1
        break
    else
        echo "❌ Failed on $S, trying next..."
        echo
    fi
done

if [[ $SUCCESS -eq 0 ]]; then
    echo "🚫 Upload failed on all servers."
    # Notify telegram on failure
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        -d text="🚫 *Upload Failed*
📁 File: \`$FILE\`
❌ All GoFile servers failed." > /dev/null
    exit 1
fi

echo
echo "🎉 Done!"
