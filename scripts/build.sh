#!/bin/sh

group_file=groups/russia.txt
source_dir=countries/russia
output_file=lists/russia.txt
all_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-russia-all.$$
domains_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-russia-domains.$$
block_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-russia-block.$$

cleanup() {
	rm -f "$all_tmp" "$domains_tmp" "$block_tmp"
}

trap cleanup EXIT HUP INT TERM

[ -f "$group_file" ] || {
	printf '%s: missing group file\n' "$group_file" >&2
	exit 1
}

write_collapsed_block() {
	sort -u "$block_tmp" | awk '
		NR == FNR { all[$0] = 1; next }
		{
			if ($0 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$/) {
				print
				next
			}
			n = split($0, parts, ".")
			for (i = 2; i <= n - 1; i++) {
				suffix = parts[i]
				for (j = i + 1; j <= n; j++) suffix = suffix "." parts[j]
				if (suffix in all) next
			}
			print
		}
	' "$domains_tmp" -
}

: > "$all_tmp" || exit 1
: > "$domains_tmp" || exit 1

while IFS= read -r name || [ -n "$name" ]; do
	case "$name" in
		''|\#*) continue ;;
	esac

	source_file=$source_dir/$name.txt
	if [ ! -f "$source_file" ]; then
		printf '%s: referenced source file does not exist\n' "$source_file" >&2
		exit 1
	fi

	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			''|\#*) continue ;;
		esac
		printf '%s\n' "$line" >> "$all_tmp"
	done < "$source_file"
done < "$group_file"

awk '
	$0 !~ /^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$/ &&
	$0 ~ /^([a-z0-9][a-z0-9-]*\.)+[a-z][a-z0-9-]*$/ { print }
' "$all_tmp" | sort -u > "$domains_tmp"

: > "$output_file" || exit 1
written=0

while IFS= read -r name || [ -n "$name" ]; do
	case "$name" in
		''|\#*) continue ;;
	esac

	source_file=$source_dir/$name.txt
	: > "$block_tmp" || exit 1

	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			''|\#*) continue ;;
		esac
		printf '%s\n' "$line" >> "$block_tmp"
	done < "$source_file"

	if [ -s "$block_tmp" ]; then
		write_collapsed_block >> "$output_file"
		written=1
	fi
done < "$group_file"

if [ -x scripts/validate.sh ]; then
	sh scripts/validate.sh || exit 1
elif [ -f scripts/validate.sh ]; then
	sh scripts/validate.sh || exit 1
fi

printf 'Built %s\n' "$output_file"
