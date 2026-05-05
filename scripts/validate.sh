#!/bin/sh

errors=0
files_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-validate.$$
sorted_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-validate-sorted.$$
generated_domains_tmp=${TMPDIR:-/tmp}/split-tunnel-domains-validate-generated-domains.$$

cleanup() {
	rm -f "$files_tmp" "$sorted_tmp" "$generated_domains_tmp"
}

trap cleanup EXIT HUP INT TERM

is_ipv4() {
	case "$1" in
		*.*.*.*) ;;
		*) return 1 ;;
	esac

	oldifs=$IFS
	IFS=.
	set -- $1
	IFS=$oldifs

	[ "$#" -eq 4 ] || return 1

	for octet do
		case "$octet" in
			''|*[!0-9]*) return 1 ;;
		esac
		[ "$octet" -le 255 ] 2>/dev/null || return 1
	done

	return 0
}

is_cidr() {
	case "$1" in
		*/*) ;;
		*) return 1 ;;
	esac

	ip=${1%/*}
	prefix=${1#*/}

	is_ipv4 "$ip" || return 1
	case "$prefix" in
		''|*[!0-9]*) return 1 ;;
	esac
	[ "$prefix" -le 32 ] 2>/dev/null || return 1

	return 0
}

is_domain() {
	printf '%s\n' "$1" | grep -Eq '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$'
}

is_group_entry() {
	printf '%s\n' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*$'
}

print_error() {
	printf '%s:%s: %s\n' "$1" "$2" "$3"
	errors=$((errors + 1))
}

validate_domain_or_ip_line() {
	file=$1
	lineno=$2
	line=$3

	case "$line" in
		*'*'*) print_error "$file" "$lineno" "wildcards are not allowed"; return 1 ;;
		*[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) print_error "$file" "$lineno" "uppercase letters are not allowed"; return 1 ;;
		http://*|https://*) print_error "$file" "$lineno" "protocols are not allowed"; return 1 ;;
		*/*)
			if ! is_cidr "$line"; then
				print_error "$file" "$lineno" "URL paths are not allowed"
				return 1
			fi
			;;
		*:* ) print_error "$file" "$lineno" "ports and IPv6 addresses are not allowed"; return 1 ;;
		*' '*|*'	'*) print_error "$file" "$lineno" "spaces are not allowed"; return 1 ;;
		*,*) print_error "$file" "$lineno" "commas are not allowed"; return 1 ;;
	esac

	if is_ipv4 "$line" || is_cidr "$line" || is_domain "$line"; then
		return 0
	fi

	print_error "$file" "$lineno" "invalid domain, IPv4 address, or IPv4 CIDR"
	return 1
}

validate_source_domain_or_ip_file() {
	file=$1
	lineno=0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))

		case "$line" in
			''|\#*) continue ;;
		esac

		validate_domain_or_ip_line "$file" "$lineno" "$line"
	done < "$file"
}

validate_generated_domain_or_ip_file() {
	file=$1
	lineno=0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))

		case "$line" in
			'') continue ;;
			\#*) print_error "$file" "$lineno" "comments are not allowed in generated list files"; continue ;;
		esac

		if validate_domain_or_ip_line "$file" "$lineno" "$line"; then
			if is_domain "$line"; then
				printf '%s:%s:%s\n' "$file" "$lineno" "$line" >> "$generated_domains_tmp"
			fi
		fi
	done < "$file"
}

validate_generated_domain_redundancy() {
	[ -s "$generated_domains_tmp" ] || return 0

	if ! awk -F: '
		NR == FNR { all[$3] = 1; next }
		{
			file = $1
			lineno = $2
			domain = $3
			n = split(domain, parts, ".")
			for (i = 2; i <= n - 1; i++) {
				suffix = parts[i]
				for (j = i + 1; j <= n; j++) suffix = suffix "." parts[j]
				if (suffix in all) {
					printf "%s:%s: redundant subdomain covered by %s\n", file, lineno, suffix
					found = 1
					break
				}
			}
		}
		END { exit found }
	' "$generated_domains_tmp" "$generated_domains_tmp"; then
		errors=$((errors + 1))
	fi
}

validate_group_file() {
	file=$1
	lineno=0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))

		case "$line" in
			''|\#*) continue ;;
		esac

		case "$line" in
			*[ABCDEFGHIJKLMNOPQRSTUVWXYZ]*) print_error "$file" "$lineno" "uppercase letters are not allowed"; continue ;;
			*'.txt') print_error "$file" "$lineno" "group entries must omit .txt"; continue ;;
			*' '*|*'	'*) print_error "$file" "$lineno" "spaces are not allowed"; continue ;;
			*,*) print_error "$file" "$lineno" "commas are not allowed"; continue ;;
			*/*|*:*|*'*'*) print_error "$file" "$lineno" "invalid service file name"; continue ;;
		esac

		if is_group_entry "$line"; then
			continue
		fi

		print_error "$file" "$lineno" "invalid service file name"
	done < "$file"
}

validate_file() {
	file=$1

	case "$file" in
		groups/*.txt) validate_group_file "$file" ;;
		countries/*/*.txt) validate_source_domain_or_ip_file "$file" ;;
		lists/*.txt) validate_generated_domain_or_ip_file "$file" ;;
	esac
}

: > "$files_tmp" || exit 1

for dir in countries groups lists; do
	[ -d "$dir" ] || continue
	find "$dir" -type f -name '*.txt' >> "$files_tmp"
done

sort "$files_tmp" > "$sorted_tmp"

while IFS= read -r file; do
	validate_file "$file"
done < "$sorted_tmp"

validate_generated_domain_redundancy

if [ "$errors" -ne 0 ]; then
	exit 1
fi

printf 'All list files are valid.\n'
