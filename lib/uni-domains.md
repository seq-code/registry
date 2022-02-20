
Extracting university domains from:
https://github.com/Hipo/university-domains-list

```bash
cat ../university-domains-list/world_universities_and_domains.json \
  | jq '.[].domains' \
  | grep '"' \
  | perl -pe 's/.*"(.+)".*/$1/' \
  > lib/uni-domains.txt
```

