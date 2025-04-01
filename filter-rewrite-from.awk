#!/usr/bin/awk -f
# vim: set ft=awk: ts=4:
#
# USAGE:
#   filter <filter-name> proc-exec \
#    "/path/to/filter-rewrite-from.awk {masquerade <domain>|address <mailaddr>}"
#
# OpenSMTPD filter that
#   1. rewrites the email address in the From: header with the specified
#      domain, if rcpt-to does not contain <domain> (i.e a masquerade for
#      external destinations)
# OR
#   2. rewrites email address in both MAIL FROM command and
#      From:/Reply-To: header with the specified email address,
#      <mailaddr>.
#
# ARGUMENTS: {domain <domain>|address <mailaddr>
#
# 	<domain>	Email domain to use in From:/Reply-To: header.
# 	<mailaddr>	Email address to use in MAIL FROM and From:/Reply-To:
#				header. It must be just an email address without a
#				display name or angle brackets.
#

function die(msg) {
	printf("mail-from: %s\n", msg) > "/dev/stderr"
	exit 1
}

# If *address* contains a display name without "@" and "<", and an email
# address in angle brackets, replaces the email address with *mailaddr* and
# preserves the display name. Otherwise returns just *mailaddr*.
function replace_mailaddr(address, mailaddr) {
	if (address ~ /^[^@<]+<[^>]+> *$/) {
		res = address ""
		sub(/<[^>]+>/, "<" mailaddr ">", res)
		return res
	}
	return mailaddr
}

# If *line* contains a display name without "@" and "<", and an
# email address in angle brackets, replaces the domain part with
# *domain* and preserves the display name. Otherwise it replaces the
# existing domain, returning the modified *line*.
function replace_domain(line, domain) {
	res = line ""
	if (line ~ /^[^@<]+<[^>]+> *$/) {
		sub(/@[^>]+>/, "@" domain ">", res)
	}
	else {
		sub(/@.+$/, "@" domain, res)
	}
	return res
}

BEGIN {
	FS = "|"
	OFS = FS
	_ = FS
	if (ARGC != 3) {
		die("mode and (<mailaddr>|<domain>) arguments expected.")
	}

	if (ARGV[1] == "address") {
        MAILADDR = ARGV[2]
    }
    else if (ARGV[1] == "masquerade") {
        DOMAIN = ARGV[2]
    }
    else {
        die("mode must be address or masquerade.")
    }

	in_body[""] = 0
	rewrite = 0
	if (!DOMAIN && !MAILADDR) {
		die("invalid usage: address or domain must be provided!")
	}
    ARGC = 0  # don't treat additional CLI args as input files
}

("config|ready" == $0) {
	if (DOMAIN)	print("register|filter|smtp-in|rcpt-to")
	if (MAILADDR) print("register|filter|smtp-in|mail-from")
	print("register|filter|smtp-in|data-line")
	print("register|ready")
	fflush()
	next
}

("config" == $1) {
	next
}

("filter" == $1) {
	if (NF < 7) {
		die("invalid filter command: expected >6 fields!")
	}
	sid = $6
	token = $7
	line = substr($0, length($1$2$3$4$5$6$7) + 8)
	# continue with next rule...
}

("filter|smtp-in|mail-from" == $1_$4_$5) {
	print("filter-result", sid, token, "rewrite", "<" MAILADDR ">")
	fflush()
	next
}

("filter|smtp-in|rcpt-to" == $1_$4_$5) {
	rcpt = substr($0, length($1$2$3$4$5$6$7) + 8)
	rewrite = !index(rcpt, DOMAIN)
	print("filter-result", sid, token, "proceed")
	fflush()
}

("filter|smtp-in|data-line" == $1_$4_$5) {
	if (line == "") {  # end of headers
		in_body[sid] = 1
	}
	if (!in_body[sid] && match(toupper(line), /^(FROM|REPLY-TO):[\t ]*/)) {
		if (DOMAIN) {
			if (rewrite) line = replace_domain(line, DOMAIN)
		}
		else {
			line = substr(line, RSTART, RLENGTH) \
			    replace_mailaddr(substr(line, RLENGTH + 1), MAILADDR)
		}
	}
	if (line == ".") {  # end of data
		delete in_body[sid]
	}
	print("filter-dataline", sid, token, line)
	fflush()
	next
}

# Local variables:
# indent-tabs-mode: t
# tab-width: 4
# End:
