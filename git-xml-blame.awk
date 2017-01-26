#! /usr/bin/awk -f

# process output of git blame --line-porcelain

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

	print "<blame file=\"" file "\">"
}

mode == "begin" && /^[0-9a-f]{40} [0-9]+ [0-9]+/ {
	mode = "commit"
	print "<line orig-number=" attr($2) " final-number=" attr($3) ">"
	print "<commit>" entities($1) "</commit>"
	next
}

mode == "commit" && /^author / {
	sub(/^author /, "")
	mode = "author"
	name = $0
	email = ""
	time = ""
	tz = ""
	next
}

mode == "author" && /^author-mail / {
	sub(/^author-mail /, "")
	sub(/^</, "")
	sub(/>$/, "")
	email = $0
	next
}

mode == "author" && /^author-time / {
	sub(/^author-time /, "")
	time = $0
	next
}

mode == "author" && /^author-tz / {
	sub(/^author-tz /, "")
	tz = $0

	print "<author>"
	print "<name>" entities(name) "</name>"
	print "<email>" entities(email) "</email>"
	print "<time>" entities(time) "</time>"
	print "<tz>" entities(tz) "</tz>"
	print "</author>"
	next
}

mode == "author" && /^committer / {
	sub(/^committer /, "")
	mode = "committer"
	name = $0
	email = ""
	time = ""
	tz = ""
	next
}

mode == "committer" && /^committer-mail / {
	sub(/^committer-mail /, "")
	sub(/^</, "")
	sub(/>$/, "")
	email = $0
	next
}

mode == "committer" && /^committer-time / {
	sub(/^committer-time /, "")
	time = $0
	next
}

mode == "committer" && /^committer-tz / {
	sub(/^committer-tz /, "")
	tz = $0

	print "<committer>"
	print "<name>" entities(name) "</name>"
	print "<email>" entities(email) "</email>"
	print "<time>" entities(time) "</time>"
	print "<tz>" entities(tz) "</tz>"
	print "</committer>"
	next
}

mode == "committer" && /^summary / {
	sub(/^summary /, "")
	mode = "summary"

	print "<summary>" entities($0) "</summary>"
	next
}

mode == "summary" && /^filename / {
	sub(/^filename /, "")
	mode = "filename"

	print "<filename>" entities($0) "</filename>"
	next
}

/^\t/ {
	sub(/^\t/, "")
	mode = "begin"
	print "<content>" entities($0) "</content>"
	print "</line>"
	next
}

{next}

END {
	print "</blame>"
}
