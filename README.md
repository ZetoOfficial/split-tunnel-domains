# split-tunnel-domains

Списки российских доменов и IPv4-адресов для VPN Policy на роутерах GL.iNet.

Задача репозитория простая: дать готовый Subscribe URL для split tunneling,
чтобы российские сервисы можно было направлять по отдельному правилу, например
мимо VPN, когда остальной трафик идет через VPN.

Сейчас v1 содержит только Russia-only список. Non-Russia списки могут появиться
позже, но пока не включены.

## Как пользоваться

В GL.iNet откройте VPN Dashboard, включите Policy Mode и в нужном tunnel rule
выберите destination list через Subscription URL.

URL списка:

```text
https://raw.githubusercontent.com/ZetoOfficial/split-tunnel-domains/refs/heads/master/lists/russia.txt
```

В списке используются только форматы, поддержанные GL.iNet VPN Policy:
домены, IPv4-адреса и IPv4 CIDR. Wildcard-записи не нужны: корневой домен
покрывает свои поддомены.

## Для разработчиков

- `countries/russia/*.txt` - исходные списки по сервисам и категориям.
- `groups/russia.txt` - порядок и состав source-файлов для сборки.
- `lists/russia.txt` - generated Subscribe URL artifact, руками не править.
- `countries/other/` - placeholder под будущие non-Russia списки.
- `scripts/validate.sh` - проверяет формат source и generated файлов.
- `scripts/build.sh` - собирает `lists/russia.txt` из `groups/russia.txt`.

Правила:

- один домен, IPv4 или IPv4 CIDR на строку;
- только lowercase;
- каждая часть домена должна начинаться с буквы;
- без wildcard, protocol, URL path, port, comma, spaces и IPv6;
- source-файлы могут содержать комментарии;
- generated файлы могут содержать только записи, без комментариев и пустых строк.

Перед завершением изменений:

```sh
sh scripts/validate.sh
sh scripts/build.sh
```
