/*
 * Copyright (c) 2003-2015, GameDuell GmbH
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package duell.helpers;

import duell.objects.DuellProcess;

using StringTools;

class GitHelper
{
	static public function setRemoteURL(path : String, remoteName : String, url : String) : Int
	{
        var gitProcess = new DuellProcess(
                                        path,
                                        "git",
                                        ["remote", "set-url", remoteName, url],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            errorMessage: "setting git remote url"
                                        });
        gitProcess.blockUntilFinished();

		return gitProcess.exitCode();
	}

    static public function clone(gitURL : String, path : String) : Int
    {
		PathHelper.mkdir(path);

		var pathComponents = path.split("/");
		var folder = pathComponents.pop();
		path = pathComponents.join("/");

        var gitProcess = new DuellProcess(
                                        path,
                                        "git",
                                        ["clone", gitURL, folder],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            errorMessage: "cloning git"
                                        });
        gitProcess.blockUntilFinished();

        return gitProcess.exitCode();
    }

    static public function pull(destination : String) : Int
    {
        if (!ConnectionHelper.isOnline())
        {
            return 0;
        }

        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["pull"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            errorMessage: "pulling git"
                                        });
        gitProcess.blockUntilFinished();

        return gitProcess.exitCode();
    }

    static public function updateNeeded(destination : String) : Bool
    {
        if (!ConnectionHelper.isOnline())
        {
            return false;
        }

        var result : String = "";

        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["remote", "update"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "checking for update on git"
                                        });

        gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["status", "-b", "--porcelain"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "checking for update on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        if (output.indexOf("[behind") != -1)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    static public function isRepoWithoutLocalChanges(destination : String) : Bool
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["status", "-s", "--porcelain"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "checking for local changes on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        var changesListStrings = output.split("\n");
        var changesListStringsTrimmed = changesListStrings.map(function(str : String): String return str.trim());

        for (str in changesListStringsTrimmed)
        {
            if(str != "" && !str.startsWith("??"))
                return false;
        }

        return true;
    }

    static public function fetch(destination : String)
    {
        if (!ConnectionHelper.isOnline())
        {
            return;
        }

        new DuellProcess(
                            destination,
                            "git",
                            ["fetch", "--tags", "--prune"],
                            {
                                systemCommand : true,
                                loggingPrefix : "[Git]",
                                block : true,
                                shutdownOnError : true,
                                errorMessage: "fetching git"
                            });
    }

    static public function getCurrentBranch(destination : String) : String
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["rev-parse", "--verify", "--abbrev-ref", "HEAD"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "getting current branch on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        return output.split("\n")[0];
    }

    static public function getCurrentCommit(destination : String) : String
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["rev-parse", "--verify", "HEAD"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "getting current commit on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        return output.split("\n")[0];
    }

    static public function getCurrentTags(destination : String) : Array<String>
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["tag", "--contains", "HEAD"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "getting current tags on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        return output.split("\n");
    }

    static public function getCommitForTag(destination : String, tag : String) : String
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["rev-parse", tag + "~0"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "getting commit for tag on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        return output.split("\n")[0];
    }

    static public function listRemotes(destination: String): Map<String, String>
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["remote", "-v"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "listing remotes on git"
                                        });

        var allRemotes: String = gitProcess.getCompleteStdout().toString();

        var allRemoteList: Array<String> = allRemotes.split("\n");
        var returnedMap: Map<String, String> = new Map();

        for (line in allRemoteList)
        {
            // format: <remote name>	<url> (<fetch/push>)
            // mind the tab!
            var remoteParts: Array<String> = line.trim().split(" ");
            remoteParts = remoteParts[0].split("\t");

            if (remoteParts.length < 2)
            {
                continue;
            }

            var remoteName: String = remoteParts[0].trim();
            var remoteUrl: String = remoteParts[1].trim();

            if (!returnedMap.exists(remoteName))
            {
                returnedMap.set(remoteName, remoteUrl);
            }
        }

        return returnedMap;
    }

    static public function listBranches(destination : String) : Array<String>
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["branch", "-a"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "listing branches on git"
                                        });

        var outputAllBranches = gitProcess.getCompleteStdout().toString();

        var outputList : Array<String> = outputAllBranches.split("\n");
        var returnedList : Array<String> = [];

        for (line in outputList)
        {
            var branch = null;
            var remote = null;

            if (line.charAt(0) == "*")
                line = line.substr(1);

            line = line.trim();

            if (line.startsWith("remotes/"))
            {
                line = line.substr("remotes/".length);
                remote = line.substr(0, line.indexOf("/"));

                branch = line.substr(line.indexOf("/") + 1);

                if (returnedList.indexOf(branch) == -1)
                    returnedList.push(branch);
            }
            else
            {
                branch = line;
                returnedList.push(branch);
            }
        }

        return returnedList;
    }


    static public function listTags(destination : String) : Array<String>
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["tag"],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "listing tags on git"
                                        });

        var output = gitProcess.getCompleteStdout().toString();

        return output.split("\n");
    }

    static public function checkoutBranch(destination : String, branch : String) : Int
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["checkout", branch],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "checking out branch on git"
                                        });

        return gitProcess.exitCode();
    }

    static public function checkoutCommit(destination : String, commit : String) : Int
    {
        var gitProcess = new DuellProcess(
                                        destination,
                                        "git",
                                        ["checkout", commit],
                                        {
                                            systemCommand : true,
                                            loggingPrefix : "[Git]",
                                            block : true,
                                            shutdownOnError : true,
                                            errorMessage: "checking out commit on git"
                                        });

        return gitProcess.exitCode();
    }
}
