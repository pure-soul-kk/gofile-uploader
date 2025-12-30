#!/bin/bash

# Check argument
if [[ $# -eq 0 ]]; then
    echo "ERROR: No File Specified!"
    exit 1
fi

FILE="$1"

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

echo "📁 File: $FILE"
echo "📡 Trying GoFile servers..."
echo

# Try these servers one by one
SERVERS=(store2 store3 store4 store5)

SUCCESS=0
for S in "${SERVERS[@]}"; do
    echo "➡️  Trying server: $S ..."
    
    # Perform upload
    RESP=$(curl -4 --http1.1 --progress-bar \
        -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")

    # Check status
    STATUS=$(echo "$RESP" | jq -r '.status')

    if [[ "$STATUS" == "ok" ]]; then
        LINK=$(echo "$RESP" | jq -r '.data.downloadPage')
        echo
        echo "✅ **Upload Successful on ${S}**"
        echo "🔗 Link: $LINK"
        SUCCESS=1
        break
    else
        echo "❌ Failed on $S, trying next..."
        echo
    fi
done

[[ $SUCCESS -eq 0 ]] && echo "🚫 Upload failed on all servers." && exit 1

echo
echo "🎉 Done!"
