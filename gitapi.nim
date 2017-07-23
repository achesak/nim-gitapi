# Nim module for working with the Git revision control system
# Based on the gitapi module for Python at https://bitbucket.org/haard/gitapi

# Written by Adam Chesak.
# Released under the MIT open source license.


import os
import osproc
import json
import strutils


type
    GitRepo* = ref object
        path : string
        user : string


proc createGitRepo*(path : string, user : string = ""): GitRepo =
    ## Creates a ``GitRepo`` object.

    return GitRepo(path: path, user: user)


proc `==`*(repo1 : GitRepo, repo2 : GitRepo): bool =
    return repo1.path == repo2.path and repo1.user == repo2.user


proc runGitCommand(path : string = ".", display : bool = false, args : varargs[string]): seq[string] =
    ## Internal proc. Runs a git command.

    # Build the command. This is kind of a hack, and will (hopefully) be
    # replaced in the future.
    var cwd : string = os.getCurrentDir()
    var cmd : string = "cd " & path & " && git "
    for i in args:
        cmd = cmd & i & " "
    cmd = cmd & "&& cd " & cwd

    # For debugging:
    if display:
        echo(cmd)

    # Run the command.
    var (output, exitCode) = execCmdEx(cmd);

    return @[output, intToStr(exitCode)]


proc runGitCommand2(path : string = ".", display : bool = false, args : seq[string]): seq[string] =
    ## Internal proc. Runs a git command.

    # Build the command. This is kind of a hack, and will (hopefully) be
    # replaced in the future.
    var cwd : string = os.getCurrentDir()
    var cmd : string = "cd " & path & " && git "
    for i in args:
        cmd = cmd & i & " "
    cmd = cmd & "&& cd " & cwd

    # For debugging:
    if display:
        echo(cmd)

    # Run the command.
    var (output, exitCode) = execCmdEx(cmd);

    return @[output, intToStr(exitCode)]


proc gitCommand2(repo : GitRepo, args : seq[string]): string =
    ## Runs a git command. Returns the result of the command.

    return runGitCommand2(args = args)[0]


proc gitCommand*(repo : GitRepo, args : varargs[string]): string =
    ## Runs a git command. Returns the result of the command.
    return runGitCommand(path = repo.path, args = args)[0]


proc gitCommand*(args : varargs[string]): string =
    ## Runs a git command. Returns the result of the command. General method.

    return runGitCommand(args = args)[0]


proc gitInit*(repo : GitRepo) {.noreturn.} =
    ## Initializes a new repo.

    discard repo.gitCommand("init")


proc gitID*(repo : GitRepo): string =
    ## Returns the output of the ``id`` command.

    return repo.gitCommand("log", "--pretty=format:%H", "-n", "1").strip(trailing = true)


proc gitAdd*(repo : GitRepo, filename : string) {.noreturn.} =
    ## Adds ``filename`` to the repo.

    discard repo.gitCommand("add", filename)


proc gitRemove*(repo : GitRepo, filename : string) {.noreturn.} =
    ## Removes ``filename`` from the repo.

    discard repo.gitCommand("rm", filename)


proc gitCheckout*(repo : GitRepo, reference : string, branch : bool = false) {.noreturn.} =
    ## Checks out the revision identified by ``reference``. ``branch`` is optional.

    var opt : string = ""
    if branch:
        opt = "-b"

    discard repo.gitCommand("checkout", opt, reference)


proc gitBranches*(repo : GitRepo): seq[string] =
    ## Returns a ``seq`` with the names of all branches.

    var res : seq[string] = repo.gitCommand("branch").splitLines()
    var ret : seq[string] = newSeq[string](len(res))

    for i in 0..high(res):
        var h : string = res[i]
        if h.startsWith(" *"):
            h = h[2..high(h)]
        ret[i] = h

    return ret


proc gitBranch*(repo : GitRepo, name : string, start : string = "HEAD"):  string =
    ## Creates a new branch called ``name``.

    return repo.gitCommand("branch", name, start)


proc gitTags*(repo : GitRepo, pattern : string = "", points_at : string = "", args : varargs[string]): seq[string] =
    ## Gets repository tags.

    var a : seq[string] = @["tag", "-l"]
    for i in args:
        a.add(i)
    if points_at != "":
        a.add("--points-at")
        a.add(points_at)
    if pattern != "":
        a.add(pattern)

    var res : seq[string] = repo.gitCommand(args = a).splitLines()

    return res


proc gitTag*(repo : GitRepo, name : string, message : string, reference : string = "", annotated : bool = false): string =
    ## Creates a tag with the specified ``name``.

    var a : seq[string] = @["tag", "-m", message]
    if annotated:
        a.add("-a")
    a.add(name)
    a.add(reference)

    return repo.gitCommand(a)


proc gitMerge*(repo : GitRepo, reference : string) {.noreturn.} =
    ## Merges reference to current.

    discard repo.gitCommand("merge", reference)


proc gitReset*(repo : GitRepo, hard : bool = true, files : seq[string]) {.noreturn.} =
    ## Reverts the repository.

    var command : seq[string] = @["reset"]
    if hard:
        command = command & "--hard"

    discard repo.gitCommand2(command & files)


proc gitNode*(repo : GitRepo): string =
    ## Gets the full node ID of the current revision.

    var res : string = repo.gitCommand("log", "-r", repo.gitID(), "--template", "{node}")
    return res.strip(trailing = true)


proc gitCommit*(repo : GitRepo, message : string, user : string = "", files : seq[string] = @[], closeBranch = false) {.noreturn.} =
    ## Commmits changes to the repository.

    var command : seq[string] = @["commit", "-m", message]
    if closeBranch:
        command = command & "--close-branch"
    if user != "":
        command = command & @["--author", user]
    elif repo.user != "":
        command = command & @["--author", repo.user]

    discard repo.gitCommand2(command & files)


proc gitLog*(repo : GitRepo, identifier : string = "", limit : int = -1, templateArg : string = "", args : seq[string]): string =
    ## Gets the repository log.

    var command : seq[string] = @["log"]
    if identifier != "":
        command = command & @[identifier, "-n", "1"]
    if limit != -1:
        command = command & @["-n", intToStr(limit)]
    if templateArg != "":
        command = command & @[templateArg]

    for i in args:
        command = command & @["" & i[0], "" & i[1]]

    return repo.gitCommand2(command)


proc gitPush*(repo : GitRepo, destination : string = "", branch : string = "") {.noreturn.} =
    ## Pushes changes to another repository.

    var command : seq[string] = @["push"]
    if destination != "":
        command = command & destination
    if branch != "":
        command = command & branch

    discard repo.gitCommand2(command)


proc gitPull*(repo : GitRepo, source : string = "", rebase : bool = false) {.noreturn.} =
    ## Pulls changes to this repository.

    var command : seq[string] = @["pull"]
    if rebase:
        command = command & "--rebase"
    if source != "":
        command = command & source

    discard repo.gitCommand2(command)


proc gitFetch*(repo : GitRepo, source : string = "") {.noreturn.} =
    ## Fetches changes to this repository.

    if source == "":
        discard repo.gitCommand("fetch")
    else:
        discard repo.gitCommand("fetch", source)


proc gitClone*(remoteUrl : string, localPath : string, args : seq[string] = @[]): GitRepo =
    ## Clones the repository at given ``remoteUrl`` to ``localPath``.
    ## Returns a GitRepo object representing the new local repository.

    discard gitCommand2(nil, @["clone", remoteUrl, localPath] & args)

    return createGitRepo(localPath)
