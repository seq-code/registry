#!/bin/bash

cd $(dirname "$0")/..
(cd ../university-domains-list && git pull)
cat ../university-domains-list/world_universities_and_domains.json \
  | jq '.[].domains' \
  | grep '"' \
  | perl -pe 's/.*"(.+)".*/$1/' \
  > lib/uni-domains.txt
cat lib/extra-domains.txt >> lib/uni-domains.txt

