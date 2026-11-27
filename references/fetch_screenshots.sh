#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
mkdir -p habits finance experiences books
fetch() {
  local path="$1" url="$2"
  echo "Downloading $path"
  curl -fL --retry 2 --connect-timeout 15 --max-time 60 -A 'Mozilla/5.0' "$url" -o "$path" || { echo "Warning: could not download $path"; rm -f "$path"; }
}
fetch habits/01-habitify-templates.png 'https://assets-global.website-files.com/5d3aa41f4e11727a27d4e25c/5f4e031609129b671abd8c77_rE5KKFFeN8N7BrkVJoBZNvYzZ8PTEwX7QUZYU0BTii8dI0LFFRRTPwWjmEyeE4sq8VQzgQdy_y33iX1pJxFam2GKtou9F9FUOkT6HHIUB83iglxsptIXL4sau9phXSYPDjTwhna9.png'
fetch habits/02-loop-stats.jpg 'https://i.blogs.es/441979/loop/1366_2000.jpg'
fetch finance/01-money-manager-budget 'https://help.realbyteapps.com/hc/article_attachments/32825812009881'
fetch experiences/01-dayone-templates.jpg 'https://miro.medium.com/v2/1%2AqOBevj19DD6JjV2vOaNbfg.jpeg'
fetch experiences/02-daylio-trends.png 'https://web.uri.edu/wp-content/uploads/sites/1592/daylio.png'
fetch books/01-bookmory-overview.png 'https://itsallwidgets.com/screenshots/app-1802.png?updated_at=2026-02-15+01%3A02%3A25'
fetch books/02-readwise-review.jpg 'https://catherinepope.com/images/readwise-daily-review.jpg'
echo 'Done. See README.md for sources and reuse restrictions.'
