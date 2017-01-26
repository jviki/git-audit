#! /usr/bin/awk -f

# process output of git log --no-merges -p --date=raw --pretty=fuller

function die(message)
{
	print "Failed at line " FNR > "/dev/stderr"
	print message > "/dev/stderr"
	exit -1
}

function entities(text)
{
	gsub(/&/, "\\&amp;", text)
	gsub(/</, "\\&lt;", text)
	gsub(/>/, "\\&gt;", text)
	gsub(/"/, "\\&#x22;", text)
	gsub(/'/, "\\&#x27;", text)

	return text
}

function attr(value)
{
	return "\"" entities(value) "\""
}

BEGIN {
	mode = "begin"
	print "<log>"
}

mode == "chunk" && /^commit / {
	print "</chunk>"
	print "</diff>"
	print "</commit>"

	mode = "begin"
	# continue to process in mode "begin"
}

mode == "begin" && /^commit [0-9a-f]{40}$/ {
	sub(/^commit /, "")
	mode = "commit"
	print "<commit>"
	print "<id>" entities($0) "</id>"

	next
}

mode == "commit" && /^Author: +/ {
	sub(/^Author: +/, "")
	mode = "author"

	if (match($0, /^[^<]+/) == 0)
		die("unexpected author line (name): " $0)

	name = substr($0, RSTART, RLENGTH - 1)

	if (match($0, /<[^<]+>$/) == 0)
		die("unexpected author line (email): " $0)

	email = substr($0, RSTART, RLENGTH)
	sub(/^</, "", email)
	sub(/>$/, "", email)

	print "<author>"
	print "<name>" entities(name) "</name>"
	print "<email>" entities(email) "</email>"

	next
}

mode == "author" && /^AuthorDate: +[0-9]+ [+-][0-9]{4}$/ {
	mode = "author"
	time = $2
	tz = $3

	print "<time>" entities(time) "</time>"
	print "<tz>" entities(tz) "</tz>"
	print "</author>"

	next
}

mode == "author" && /^Commit: +/ {
	sub(/^Commit: +/, "")
	mode = "committer"

	if (match($0, /^[^<]+/) == 0)
		die("unexpected committer line (name): " $0)

	name = substr($0, 1, RLENGTH - 1)

	if (match($0, /<[^<]+>$/) == 0)
		die("unexpected committer line (email): " $0)

	email = substr($0, RSTART, RLENGTH)
	sub(/^</, "", email)
	sub(/>$/, "", email)

	print "<committer>"
	print "<name>" entities(name) "</name>"
	print "<email>" entities(email) "</email>"

	next
}

mode == "committer" && /^CommitDate: +[0-9]+ [+-][0-9]{4}$/ {
	mode = "committer"
	time = $2
	tz = $3

	print "<time>" entities(time) "</time>"
	print "<tz>" entities(tz) "</tz>"
	print "</committer>"

	next
}

mode == "committer" && /^$/ {
	mode = "subject"

	next
}

mode == "subject" && /^    / {
	sub(/^    /, "")
	mode = "message-begin"
	print "<subject>" entities($0) "</subject>"

	next
}

mode == "message-begin" && /^    $/ {
	mode = "message"
	print "<message>"
	signedoffby[0] = 0
	reviewedby[0] = 0
	fixes[0] = 0
	related[0] = 0
	next
}

mode == "message" && /^    Signed-off-by:/ {
	line = $0
	sub(/^    Signed-off-by:[ \t]*/, "", line)

	signedoffby[0] += 1
	signedoffby[signedoffby[0]] = line
}

mode == "message" && /^    Reviewed-by:/ {
	line = $0
	sub(/^    Reviewed-by:[ \t]*/, "", line)

	reviewedby[0] += 1
	reviewedby[reviewedby[0]] = line
}

mode == "message" && /^    Fixes: [a-f0-9]+/ {
	fixes[0] += 1
	fixes[fixes[0]] = $2
}

mode == "message" && /^    / {
	sub(/^    /, "")
	print entities($0)
	next
}

mode == "message" && /^diff --git / {
	print "</message>"

	for (i = 1; i <= signedoffby[0]; ++i)
		print "<signed-off-by>" entities(signedoffby[i]) "</signed-off-by>"
	for (i = 1; i <= reviewedby[0]; ++i)
		print "<reviewed-by>" entities(reviewedby[i]) "</reviewed-by>"
	for (i = 1; i <= fixes[0]; ++i)
		print "<fixes>" entities(fixes[i]) "</fixes>"
}

(mode == "message-begin" || mode == "message") && /^diff --git / {
	mode = "diff"
	print "<diff>"
	next
}

mode == "chunk" && /^diff --git / {
	print "</chunk>"
	mode = "diff"
	print "</diff>"
	print "<diff>"
	next
}

mode == "diff" && /^index / {
	print "<perm>" entities($3) "</perm>"

	next
}

mode == "diff" && /^--- / {
	sub(/^--- a\//, "")
	print "<left>" entities($0) "</left>"

	next
}

mode == "diff" && /^\+\+\+ / {
	sub(/^\+\+\+ b\//, "")
	print "<right>" entities($0) "</right>"

	next
}

mode == "chunk" && /^@@ / {
	print "</chunk>"
	mode = "diff"
	# continue to process in mode "diff"
}

mode == "diff" && /^@@ / {
	mode = "chunk-begin"
	left = $2
	right = $3

	print "<chunk>"

	split(left, info, ",")
	print "<left offset=" attr(substr(info[1], 2)) " length=" attr(info[2]) " />"

	split(right, info, ",")
	print "<right offset=" attr(substr(info[1], 2)) " length=" attr(info[2]) " />"

	print "<context>"
	sub(/^@@ [^@]+ @@ /, "")
	print entities($0)

	next
}

mode == "chunk-begin" && /^ \t\t\t/ {
	sub(/^ \t\t\t/, "")
	print entities($0)
}

mode == "chunk-begin" {
	print "</context>"
	mode = "chunk"
}

mode == "chunk" && /^ / {
	sub(/^ /, "")
	print "<line>" entities($0) "</line>"

	next
}

mode == "chunk" && /^-/ {
	sub(/^-/, "")
	print "<del>" entities($0) "</del>"

	next
}

mode == "chunk" && /^\+/ {
	sub(/^\+/, "")
	print "<add>" entities($0) "</add>"

	next
}

END {
	if (mode == "chunk") {
		print "</chunk>"
		print "</diff>"
	}

	print "</commit>"
	print "</log>"
}
