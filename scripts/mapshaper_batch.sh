#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_SHAPEFILE="${INPUT_SHAPEFILE:-$(ls -t "$ROOT_DIR"/input/N03-*.shp 2>/dev/null | head -n1)}"
TARGETS_FILE="$ROOT_DIR/scripts/targets.tsv"
OUTPUT_GEO_DIR="$ROOT_DIR/GeoJson"
OUTPUT_TOPO_DIR="$ROOT_DIR/TopoJson"
MAPSHAPER_BIN="$ROOT_DIR/node_modules/.bin/mapshaper"

if [[ ! -x "$MAPSHAPER_BIN" ]]; then
  MAPSHAPER_BIN="mapshaper"
fi

if [[ ! -f "$INPUT_SHAPEFILE" ]]; then
  echo "Input Shapefile not found: $INPUT_SHAPEFILE" >&2
  exit 1
fi

if [[ ! -f "$TARGETS_FILE" ]]; then
  echo "Targets file not found: $TARGETS_FILE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_GEO_DIR" "$OUTPUT_TOPO_DIR"

DESIGNATED_CITIES=(
  "札幌市:01100" "仙台市:04100" "さいたま市:11100" "千葉市:12100" "横浜市:14100"
  "川崎市:14130" "相模原市:14150" "新潟市:15100" "静岡市:22100" "浜松市:22130"
  "名古屋市:23100" "京都市:26100" "大阪市:27100" "堺市:27140" "神戸市:28100"
  "岡山市:33100" "広島市:34100" "北九州市:40100" "福岡市:40130" "熊本市:43100"
)

city_map_entries=()
for entry in "${DESIGNATED_CITIES[@]}"; do
  city_name="${entry%%:*}"
  city_code="${entry##*:}"
  city_map_entries+=("\"$city_name\":\"$city_code\"")
done

IFS=','
DESIGNATED_CITY_MAP="{${city_map_entries[*]}}"
unset IFS

EACH_EXPR="var cityName=N03_004; if(cityName!==null && cityName!==undefined){var map=$DESIGNATED_CITY_MAP; if(map[cityName]){N03_007=map[cityName];}}"

while IFS=$'\t' read -r name filter dissolve2 simplify; do
  if [[ "$name" == "name" || -z "$name" ]]; then
    continue
  fi

  mapshaper_cmd=("$MAPSHAPER_BIN" "$INPUT_SHAPEFILE" -each "$EACH_EXPR")
  if [[ "$filter" != "*" ]]; then
    mapshaper_cmd+=(-filter "$filter")
  fi

  mapshaper_cmd+=(-dissolve2 "$dissolve2" -simplify "$simplify%" -o "format=geojson" "$OUTPUT_GEO_DIR/$name.json")

  "${mapshaper_cmd[@]}"

  "$MAPSHAPER_BIN" "$OUTPUT_GEO_DIR/$name.json" -o "format=topojson" "$OUTPUT_TOPO_DIR/$name.json"
done < "$TARGETS_FILE"
