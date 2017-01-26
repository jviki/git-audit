<x:stylesheet
	xmlns:x="http://www.w3.org/1999/XSL/Transform"
	xmlns:s="http://exslt.org/strings"
	xmlns:d="http://exslt.org/dates-and-times"
	extension-element-prefixes="s d"
	version="1.0">

	<x:preserve-space elements="message" />

	<x:key name="files" match="/audit/record/blame/@file" use="." />

	<!--
	Abbreviate the given git hash.
	-->
	<x:template name="git-short-id">
		<x:param name="id" select="@id" />
		<x:value-of select="substring($id, 1, 12)" />
	</x:template>

	<!--
	Format the timestamp obtained from git. The timestamp is in format:

	time: UNIX timestamp
	tz: time zone ([+-][0-9]{4})
	-->
	<x:template name="git-time-format">
		<x:param name="time" select="time" />
		<x:param name="tz" select="tz" />

		<x:variable name="tz-fixed" select="concat(substring($tz, 1, 3), ':', substring($tz, 4, 2))" />
		<x:variable name="start" select="concat('1970-01-01T00:00:00', $tz-fixed)" />

		<x:variable name="parsed" select="d:add($start, d:duration($time))" />
		<x:variable name="shift" select="d:seconds(concat('1970-01-01T', substring($tz-fixed, 2), ':00'))" />
		<x:variable name="result" select="d:add($parsed, d:duration($shift))" />
		<x:value-of select="s:replace(translate($result, 'T', ' '), '+', ' +')" />
	</x:template>

	<!--
	Name of the report document.
	-->
	<x:template name="audit-name">
		<x:text>Audit of </x:text>

		<x:call-template name="git-short-id">
			<x:with-param name="id" select="@of" />
		</x:call-template>
	</x:template>

	<!--
	Stylesheet of the report. No other CSS is used and this one is statically generated
	to avoid XSS and other issues.
	-->
	<x:template name="audit-css">
		<style type="text/css">
		.no-message {
			display: block;
			height: 1em;
		}
		.related .label {
			display: block;
			margin-bottom: 0px;
		}
		.related ul {
			margin-top: 0px;
		}
		.chunk-separator {
			display: block;
			height: 1em;
		}
		.code .filename {
			font-size: 80%;
			margin-left: 1%;
			margin-bottom: .5em;
			display: block;
		}
		.chunk {
			margin-left: 1%;
			margin-right: 15%;
			overflow-x: scroll;
		}
		.line {
			background-color: lightgray;
			display: block;
		}
		.line br {
			display: none;
		}
		.line:hover .line-number {
			background-color: gray;
		}
		.line-number {
			margin-right: 1em;
			font-size: 80%;
		}
		.line-code {
			font-family: "Courier New", monospace;
			white-space: pre;
		}
		.line-blame br {
			display: block;
		}
		.line-blame .label {
			font-weight: bold;
		}
		.line-blame {
			background-color: white;
			border-left: 1pt solid black;
			padding-left: 1em;
			font-size: 80%;
		}
		.line-onclick {
			display: none;
		}
		.line-onclick + label > .line-blame {
			display: none;
		}
		.line-onclick:checked + label > .line-blame {
			display: block;
		}
		.highlight {
			background-color: yellow;
		}
		.add {
			background-color: #54C571;
		}
		.del {
			background-color: #E77471;
		}
		</style>
	</x:template>

	<!--
	Generate table of contents per issue level. Levels: low, moderate, high.
	-->
	<x:template name="toc-issue-level">
		<x:param name="title" />
		<x:param name="level" />

		<x:variable name="commits"
			select="record/log/commit[starts-with(subject, concat($level, ':'))]" />

		<x:if test="count($commits) &gt; 0">
			<div class="toc">
				<h3><x:value-of select="$title" /></h3>
				<ul>
				<x:for-each select="$commits">
					<li>
						<a href="#{id}">
							<x:value-of select="subject" />
						</a>
					</li>
				</x:for-each>
				</ul>
			</div>
		</x:if>
	</x:template>

	<!--
	Generate table of contents per file. List issues for each single file.
	-->
	<x:template name="toc-per-file">
		<x:variable name="files"
			select="/audit/record/blame/@file
				[generate-id() = generate-id(key('files', .)[1])]" />

		<div class="toc">
			<h3>Issues per file</h3>
			<ul>
				<x:for-each select="$files">
					<x:variable name="file" select="." />	
					<li><x:value-of select="$file" /></li>
					<ul>
						<x:for-each select="/audit/record/log/commit[diff/left = $file]">
							<li>
								<a href="#{id}">
									<x:value-of select="subject" />
								</a>
							</li>
						</x:for-each>
					</ul>
				</x:for-each>
			</ul>
		</div>
	</x:template>

	<x:template match="/audit">
	<html>
		<head>
			<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
			<x:call-template name="audit-css" />
			<!-- disable all malicious content except of the audit-css -->
			<meta http-equiv="Content-Security-Policy" content="default-src 'none'" />
			<title>
				<x:call-template name="audit-name" />
			</title>
		</head>
		<body>
			<h1>
				<x:call-template name="audit-name" />
			</h1>

			<x:call-template name="toc-issue-level">
				<x:with-param name="title" select="'High impact issues'" />
				<x:with-param name="level" select="'high'" />
			</x:call-template>

			<x:call-template name="toc-issue-level">
				<x:with-param name="title" select="'Moderate impact issues'" />
				<x:with-param name="level" select="'moderate'" />
			</x:call-template>

			<x:call-template name="toc-issue-level">
				<x:with-param name="title" select="'Low impact issues'" />
				<x:with-param name="level" select="'low'" />
			</x:call-template>

			<x:call-template name="toc-per-file" />

			<x:call-template name="toc-issue-level">
				<x:with-param name="title" select="'Style issues'" />
				<x:with-param name="level" select="'style'" />
			</x:call-template>

			<div class="report" id="{@of}">
				<x:apply-templates select="record" />
			</div>
		</body>
	</html>
	</x:template>

	<!--
	The report consists of multiple records. Each record is a single issue to be
	resolved. Each issue has its ID (git hash).
	-->
	<x:template match="record">
		<div id="{@id}" class="record">
			<x:apply-templates select="log/commit" />
			<x:apply-templates select="log/commit/diff" mode="with-blame">
				<x:with-param name="blame" select="blame" />
			</x:apply-templates>
		</div>
	</x:template>

	<!--
	Extract subject level from the record subject. The level is contained as a
	prefix like "low:", "moderate:", "high:", "style:".
	-->
	<x:template name="extract-subject-level">
		<x:param name="subject" select="subject" />

		<x:choose>
			<x:when test="starts-with($subject, 'low:')">
				<x:text>low</x:text>
			</x:when>
			<x:when test="starts-with($subject, 'moderate:')">
				<x:text>moderate</x:text>
			</x:when>
			<x:when test="starts-with($subject, 'high:')">
				<x:text>high</x:text>
			</x:when>
			<x:when test="starts-with($subject, 'style:')">
				<x:text>style</x:text>
			</x:when>
			<x:otherwise>
				<x:message terminate="yes">Subject without label: <x:value-of select="$subject" /></x:message>
			</x:otherwise>
		</x:choose>
	</x:template>

	<!--
	Format record message. All empty lines (<EOL> <EOL>) are converted to paragraphs.
	All other EOL marks are converted to <br /> to preserve the original wrapping of
	lines.

	Lines labeled as "Related: ..." are skipped.
	-->
	<x:template name="message-format">
		<x:for-each select="s:split(text(), '&#xA;&#xA;')">
			<x:variable name="line" select="." />
			<p>
				<x:for-each select="s:split($line, '&#xA;')">
					<x:if test="not(starts-with(., 'Related:'))">
						<x:value-of select="." />
						<br />
					</x:if>
				</x:for-each>
			</p>
		</x:for-each>
	</x:template>

	<!--
	Output the record message if included and non-empty.
	-->
	<x:template match="log/commit/message">
		<x:variable name="content">
			<x:call-template name="message-format" />
		</x:variable>

		<x:if test="string-length(normalize-space($content)) &gt; 0">
			<h4>Description</h4>
			<x:call-template name="message-format" />
		</x:if>
	</x:template>

	<x:template match="author|committer">
		<a href="mailto:{email}" title="{email}">
			<x:value-of select="name" />
		</a>
	</x:template>

	<x:template match="log/commit">
		<x:variable name="level">
			<x:call-template name="extract-subject-level" />
		</x:variable>

		<h2 class="{$level}">
			<x:value-of select="subject" />
		</h2>
		<div class="author">
			<x:text>Auditor: </x:text>
			<x:apply-templates select="author" />
		</div>
		<div class="related">
			<x:if test="../../related">
				<span class="label">Related: </span>
			</x:if>
			<ul>
			<x:for-each select="../../related">
				<x:variable name="id" select="." />
				<x:variable name="commit" select="/audit/record[@id = $id]/log/commit[id = $id]" />

				<li>
				<x:if test="$commit">
					<x:variable name="class">
						<x:call-template name="extract-subject-level">
							<x:with-param name="subject" select="$commit/subject" />
						</x:call-template>
					</x:variable>

					<a href="#{$id}" title="{$id}" class="{$class}">
						<x:value-of select="$commit/subject" />
					</a>
				</x:if>
				<x:if test="not($commit)">
					<x:call-template name="git-short-id">
						<x:with-param name="id" select="$id" />
					</x:call-template>
				</x:if>
				</li>
			</x:for-each>
			</ul>
		</div>
		<div class="message {$level}">
			<x:apply-templates select="message" />
		</div>
		<x:if test="not(message)">
			<span class="no-message" />
		</x:if>
	</x:template>

	<!--
	Generate a code line with line number. The line number is obtained
	from the git blame result. A quick blame summary is included in the
	atitle attribute of the line.
	-->
	<x:template match="blame/line" mode="show">
		<x:variable name="quick-blame">
			<x:text>commit </x:text>
			<x:call-template name="git-short-id">
				<x:with-param name="id" select="commit" />
			</x:call-template>
			<x:text>&#xA;</x:text>
			<x:value-of select="author/name" />
			<x:text>&#xA;</x:text>
			<x:call-template name="git-time-format">
				<x:with-param name="time" select="author/time" />
				<x:with-param name="tz" select="author/tz" />
			</x:call-template>
			<x:text>&#xA;</x:text>
			<x:value-of select="summary" />
		</x:variable>

		<span class="line-content" title="{$quick-blame}">
			<span class="line-number">
				<x:value-of select="@final-number" />
			</span>
			<span class="line-code">
				<x:value-of select="content" />
			</span>
		</span>
	</x:template>

	<!--
	Create summary of git blame for a code line.
	-->
	<x:template match="blame/line" mode="blame">
		<h4>Last change</h4>
		<span class="label">commit: </span><x:value-of select="commit" />
		<br />
		<span class="label">author: </span>
		<x:apply-templates select="author" />
		<br />
		<span class="label">date: </span>
		<x:call-template name="git-time-format">
			<x:with-param name="time" select="author/time" />
			<x:with-param name="tz" select="author/tz" />
		</x:call-template>
		<br />
		<span class="label">committer: </span>
		<x:apply-templates select="committer" />
		<br />
		<span class="label">commit date: </span>
		<x:call-template name="git-time-format">
			<x:with-param name="time" select="committer/time" />
			<x:with-param name="tz" select="committer/tz" />
		</x:call-template>
		<br />
		<span class="label">file: </span>
		<x:value-of select="filename" />
		<br />
		<p>
			<x:value-of select="summary" />
		</p>
	</x:template>

	<!--
	Generic routine to output a code line. It assumes that the current context
	is a certain log/commit/diff/chunk/{line|del}. However, the actual line
	output is generated from a blame/line because there is more information.
	-->
	<x:template name="blame-line">
		<x:param name="blame-line" />
		<x:param name="highlight" />

		<!-- onclick CSS hack to avodi JavaScript -->
		<input type="checkbox" id="{generate-id(.)}" class="line-onclick" />
		<label for="{generate-id(.)}">
			<span class="line {$highlight}">
				<x:apply-templates select="$blame-line" mode="show" />
				<br />
			</span>
			<div class="line-blame">
				<x:apply-templates select="$blame-line" mode="blame" />
			</div>
		</label>
	</x:template>

	<!--
	Lines to be deleted are considered as the ones to be marked up in the output.
	Lines to be added are ignored in the mode "with-blame".
	-->
	<x:template match="log/commit/diff/chunk/del" mode="with-blame">
		<x:param name="blame" />
		<x:variable name="i" select="position()" />

		<x:call-template name="blame-line">
			<x:with-param name="blame-line" select="$blame/line[$i]" />
			<x:with-param name="highlight" select="'highlight'" />
		</x:call-template>
	</x:template>

	<!--
	Normal non-highlighted lines showing a context of the highlighted lines
	(derived from deleted lines).
	-->
	<x:template match="log/commit/diff/chunk/line" mode="with-blame">
		<x:param name="blame" />
		<x:variable name="i" select="position()" />

		<x:call-template name="blame-line">
			<x:with-param name="blame-line" select="$blame/line[$i]" />
			<x:with-param name="highlight" select="''" />
		</x:call-template>
	</x:template>

	<!--
	In the "as-suggestion" mode, the add lines are ignored. Only line and
	del tags are used because those lines are coming from the original
	version of the source code. The added lines are treated as suggestions
	from the auditor. Only the original lines (line, del) can be paired
	with the blame lines. Thus, the add lines must be handled separately.

	Every line or del line, after it is created, searchs for the immediate
	following add lines. Those are created and then another line or del is
	processed. This routine performs the walk over the following add lines.
	-->
	<x:template name="walk-add-lines">
		<x:variable name="lines" select="../line|../add|../del" />
		<x:variable name="id" select="generate-id(.)" />
		<x:variable name="i">
			<x:for-each select="$lines">
				<x:if test="generate-id(.) = $id">
					<x:value-of select="position()" />
				</x:if>
			</x:for-each>
		</x:variable>

		<x:apply-templates select="$lines[local-name() = 'add'
				and position() = $i + 1]" mode="as-suggestion">
			<x:with-param name="i" select="$i + 1" />
		</x:apply-templates>
	</x:template>

	<!--
	An add line handling. It provides an alternative blame content that is actualy not
	a blame. The "blame" keyword is used just for CSS purposes.
	-->
	<x:template match="log/commit/diff/chunk/add" mode="as-suggestion">
		<x:param name="blame" />

		<input type="checkbox" id="{generate-id(.)}" class="line-onclick" />
		<label for="{generate-id(.)}">
			<span class="line add">
				<span class="line-content">
					<span class="line-number">
						<x:text>+</x:text>
					</span>
					<span class="line-code">
						<x:value-of select="." />
					</span>
				</span>
				<br />
			</span>
			<div class="line-blame">
				<p></p>
				<span class="label">suggested by: </span>
				<x:apply-templates select="../../../author" />
				<br />
				<span class="label">date: </span>
				<x:call-template name="git-time-format">
					<x:with-param name="time" select="../../../author/time" />
					<x:with-param name="tz" select="../../../author/tz" />
				</x:call-template>
				<br />
				<p></p>
			</div>
		</label>

		<x:call-template name="walk-add-lines" />
	</x:template>

	<!--
	A context line of a suggestion record. It can be followed by add lines.
	-->
	<x:template match="log/commit/diff/chunk/line" mode="as-suggestion">
		<x:param name="blame" />
		<x:variable name="i" select="position()" />

		<x:call-template name="blame-line">
			<x:with-param name="blame-line" select="$blame/line[$i]" />
			<x:with-param name="highlight" select="''" />
		</x:call-template>

		<x:call-template name="walk-add-lines" />
	</x:template>

	<!--
	A line suggested to be deleted. It can be followed by add lines.
	-->
	<x:template match="log/commit/diff/chunk/del" mode="as-suggestion">
		<x:param name="blame" />
		<x:variable name="i" select="position()" />

		<x:call-template name="blame-line">
			<x:with-param name="blame-line" select="$blame/line[$i]" />
			<x:with-param name="highlight" select="'del'" />
		</x:call-template>

		<x:call-template name="walk-add-lines" />
	</x:template>

	<x:template match="log/commit/diff/chunk" mode="with-blame">
		<x:param name="blame" />
		<x:variable name="i" select="position()" />

		<div class="chunk">
			<!--
			Determine whether the chunk is a suggestion (a change to the code)
			or just a markup (audit information).
			-->
			<x:variable name="chunk-is-audit"
				select="left/@offset = right/@offset and left/@length = right/@length" />

			<x:if test="$chunk-is-audit">
				<x:apply-templates select="line|del" mode="with-blame">
					<x:with-param name="blame" select="$blame[$i]" />
				</x:apply-templates>
			</x:if>
			<x:if test="not($chunk-is-audit)">
				<x:apply-templates select="line|del" mode="as-suggestion">
					<x:with-param name="blame" select="$blame[$i]" />
				</x:apply-templates>
			</x:if>
		</div>
		<x:if test="position() != last()">
			<span class="chunk-separator" />
		</x:if>
	</x:template>

	<x:template match="log/commit/diff" mode="with-blame">
		<x:param name="blame" />
		<x:variable name="file" select="left" />

		<div class="code blame">
			<span class="filename"><x:value-of select="$file" /></span>
			<x:apply-templates select="chunk" mode="with-blame">
				<x:with-param name="blame" select="$blame[@file = $file]" />
			</x:apply-templates>
		</div>
	</x:template>

</x:stylesheet>
