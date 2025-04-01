#!/usr/bin/env sh
# Interface test
cat >test.msgs << EOF
config|ready
filter|x|x|smtp-in|mail-from|x|x|user@sub.example.com
filter|x|x|smtp-in|data-line|x|x|From: User Name <user@sub.example.com>
filter|x|x|smtp-in|data-line|x|x|Reply-To: User Name <user@sub.example.com>
filter|x|x|smtp-in|data-line|x|x|From: user@sub.example.com
filter|x|x|smtp-in|data-line|x|x|
filter|x|x|smtp-in|data-line|x|x|Line 1
filter|x|x|smtp-in|data-line|x|x|Line 2
filter|x|x|smtp-in|data-line|x|x|.
EOF
echo "-Address rewrite-"
awk -f filter-rewrite-from.awk address no-reply@example.com <test.msgs
cat >test.msgs << EOF
config|ready
filter|x|x|smtp-in|rcpt-to|x|x|user@example.com
filter|x|x|smtp-in|data-line|x|x|From: User Name <user@sub.example.com>
filter|x|x|smtp-in|data-line|x|x|Reply-To: User Name <user@sub.example.com>
filter|x|x|smtp-in|data-line|x|x|From: user@sub.example.com
filter|x|x|smtp-in|data-line|x|x|
filter|x|x|smtp-in|data-line|x|x|Line 1
filter|x|x|smtp-in|data-line|x|x|Line 2
filter|x|x|smtp-in|data-line|x|x|.
EOF
echo "-Masquerade: won't rewrite-"
awk -f filter-rewrite-from.awk masquerade example.com <test.msgs
echo "-Masquerade: will rewrite-"
awk -f filter-rewrite-from.awk masquerade other.com <test.msgs
rm test.msgs
