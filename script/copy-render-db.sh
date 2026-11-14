#!/usr/bin/env bash
# Copies Render's database into the openstage-db accessory on tux-box, for the move off Render
# (control-tower HOSTING.md, step 6). Run it from the Mac, after `bin/kamal accessory boot db`
# and with Render's worker suspended, so no job writes during the copy. Render's web keeps
# serving until the DNS moves; what it writes after the copy (visits, mostly) stays behind.
#
#   script/copy-render-db.sh    # RENDER_DATABASE_URL and POSTGRES_PASSWORD from the shell or .env.kamal
#
# It streams pg_dump into pg_restore inside a throwaway postgres:18 container on the box's kamal
# network, so no dump touches a disk, then prints each table's rows on both sides.
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="$(bin/secret RENDER_DATABASE_URL)"
PASSWORD="$(bin/secret POSTGRES_PASSWORD)"
if [ -z "$SOURCE" ] || [ -z "$PASSWORD" ]; then
  echo "RENDER_DATABASE_URL and POSTGRES_PASSWORD are needed, in the shell or in .env.kamal" >&2
  exit 1
fi
TARGET="postgres://openstage:${PASSWORD}@openstage-db:5432/openstage_production"

# Values travel on ssh's stdin and reach docker by name (-e VAR), never on a command line.
ssh -i ~/.ssh/id_ed25519_tuxnotfound root@2.28.203.124 bash -s <<EOF
set -euo pipefail
export SOURCE='${SOURCE}' TARGET='${TARGET}'
run() { docker run --rm --network kamal -e SOURCE -e TARGET postgres:18 bash -c "\$1" </dev/null; }

tables=\$(run 'psql "\$TARGET" -Atc "select count(*) from pg_tables where schemaname = '"'"'public'"'"'"')
if [ "\$tables" != "0" ]; then
  echo "openstage_production already has \$tables tables; drop it first or it is not a fresh copy" >&2
  exit 1
fi

run 'set -o pipefail; pg_dump --format=custom --no-owner --no-acl "\$SOURCE" | pg_restore --no-owner --no-acl --exit-on-error -d "\$TARGET"'

count='select table_name, (xpath('"'"'/row/c/text()'"'"', query_to_xml(format('"'"'select count(*) as c from public.%I'"'"', table_name), false, true, '"''"')))[1]::text from information_schema.tables where table_schema = '"'"'public'"'"' and table_type = '"'"'BASE TABLE'"'"' order by 1'
run "psql \"\\\$SOURCE\" -Atc \"\$count\"" | LC_ALL=C sort > /tmp/openstage-rows-render
run "psql \"\\\$TARGET\" -Atc \"\$count\"" | LC_ALL=C sort > /tmp/openstage-rows-box
echo "Rows per table, Render | box (a table still written on Render may differ by a few):"
LC_ALL=C join -t '|' -a1 -a2 -e missing -o 0,1.2,2.2 /tmp/openstage-rows-render /tmp/openstage-rows-box | awk -F'|' '{ mark = (\$2 == \$3) ? "" : "  <-- differs"; print \$1": "\$2" | "\$3 mark }'
rm -f /tmp/openstage-rows-render /tmp/openstage-rows-box
EOF
