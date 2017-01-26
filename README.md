Git Auditing Tool
=================

This is a set of tools for helping with auditing source code. When
reviewing code that is already written and merged in a repository,
it is desirable to be able to comment on certain lines or blocks
of the source code. You can use some web-based systems for this
purpose (github, gitlab, ...). However, sometimes, those solutions
are simply too complex for a simple audit or review to set up or
your project is not public or too small to deploy a complex code
review/audit systems.


Annotating code
---------------

Git provides annotating of source code as an implicit feature inside
(I don't mean `git blame` or `git annotate` commands). As it provides
source control capabilities, you can change a line and describe text
in the commit message. And that's it.

Thus, for annotating code during a manual audit, you don't need any
tools. The Git itself is sufficient enough. You can insert a blank
character (usually a space or a comment at the end of line or anywhere)
and perform `git add` followed by `git commit` to describe what is
wrong with this piece of code.

To view the highlighted code, just use `git log -p` or `git diff` or
`git show`. However, this output might be a bit user unfriendly. And
that's the place where this tools can be used.


View annotated code
-------------------

The basic tool intended to run in command line is `git-audit-log`.
This command just wraps `git log` and changes the output to be audit
friendly. It colors up keywords _low_, _moderate_, _high_ and _style_
in the commit message Those are recognized and allows to mark the
type of comment you've made. Consider:

* low - low impact issue
* moderate - moderate impact issue
* high - high impact issue (probably an exploitable vulnerability)
* style - code style issue

The next thing changed by the git-audit-log is the diff format. The
tool distinguishes between two types of commits:

* audit commit - simply a code annotation like "this is bad because..."
* suggestion commit - change to the source code to fix something

The audit commit only inject blanks in the source code and does not
introduce any new line insertions or deletions. The suggestion commit
inserts and deletes lines.

Audit commits are displayed differently. The diff lines starting with
'+' are ignored and lines starting with '-' are instead highlighted
as the subject of the current audit comment.


HTML report
-----------

The console tool `git-audit-log` is helpful, however, for a more
comprehensive report, there is `git-audit-report` which generates
a HTML page. The HTML page is standalone and contains all the audit
commits with cross-references and also some details coming from
`git blame`. The HTML report can send to anybody how is not using
Git at all. The tool supports a commit label _Related:_ which can
be used to cross-reference audit commits. You can use it e.g. to
say "this comment is nearly the same as that one before" by inserting

<pre>
Related: {git-hash}
</pre>

in the audit commit (similarly as the _Fixes:_ label is used).


Workflow
--------

The basic workflow to get the idea of the tools:

<pre>
$ git clone <some-project-to-audit> project
$ cd project
$ git checkout -b audit-master origin/master
...choose a file and check the contents...
...mark some wierd lines by inserting a space...
$ git add -p
$ git commit -v
...continue with auditing/reviewing...
$ git-audit-log origin/master..
<modified git log...>
$ git-audit-report origin/master
$ xdg-open report.html
</pre>
