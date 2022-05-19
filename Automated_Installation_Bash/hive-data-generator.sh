#!/bin/bash


USAGE="$0 [TABLE_NAME] [ROWS_TO_GENERATE] [HIVE_PRINCIPAL]" 


if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters"
    echo "$USAGE"
    exit -1
fi

set +x


TABLE_NAME=$1
ROWS=$2
HIVE_PRINCIPAL=$3


cd /usr/local/hive/bin
pwd

hexdump -v -e '5/1 "%02x""\n"' /dev/urandom |
  awk -v OFS=',' '
    { print NR, substr($0, 1, 8) }' |
  head -n "$2" > "/tmp/hive.data.$TABLE_NAME.csv"


kinit $HIVE_PRINCIPAL


ls
./beeline << EOF
!connect jdbc:hive2://localhost:10000/default;principal=$HIVE_PRINCIPAL


show tables;
drop table if exists $TABLE_NAME;
create table $TABLE_NAME (key int, value string) row format delimited fields terminated by ',';
show table $TABLE_NAME;
describe $TABLE_NAME;
load data local inpath '/tmp/hive.data.$TABLE_NAME.csv' into table $TABLE_NAME;

select count(1) from $TABLE_NAME;

EOF

