cat $IN $IN $IN $IN | tail +2 | paste $IN2 - | sort | uniq
