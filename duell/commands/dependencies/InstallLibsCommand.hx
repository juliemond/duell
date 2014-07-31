/**
 * @autor kgar
 * @date 30.06.2014.
 * @company Gameduell GmbH
 */
package duell.commands.dependencies;

import duell.objects.SemVer;
import duell.objects.DuellConfigJSON;
import duell.objects.DuellLib;
import duell.helpers.LogHelper;
import duell.helpers.GitHelper;
import duell.helpers.DuellLibListHelper;
import duell.helpers.DuellConfigHelper;
import duell.helpers.PathHelper;

import sys.io.Process;
import Sys;
import sys.FileSystem;
import sys.io.File;
import sys.io.File;
import haxe.Json;
import haxe.io.Error;

import duell.commands.IGDCommand;
class InstallLibsCommand implements IGDCommand 
{

    private var duellLibList : Map<String, DuellLib>;
    private var duellConfigJSON : DuellConfigJSON;
    private var globalErrorOccured : Bool = false;
    public function new() {}

    public function execute(cmd:String):String
    {
        /** are we in a project? **/
        if (!FileSystem.exists(DuellLibListHelper.DEPENDENCY_LIST_FILENAME))
            return "File with path '" + DuellLibListHelper.DEPENDENCY_LIST_FILENAME + "' not found, please execute from the project directory.";

        duellConfigJSON = DuellConfigJSON.getConfig(DuellConfigHelper.getDuellConfigFileLocation());

        if(duellConfigJSON.localLibraryPath == null || duellConfigJSON.localLibraryPath == "")
        {
            LogHelper.error("No local library path defined. Run \"duell setup\" to fix this.");
        }

        if(!FileSystem.exists(duellConfigJSON.localLibraryPath))
        {
            PathHelper.mkdir(duellConfigJSON.localLibraryPath);
        }

        var duellLibList = DuellLibListHelper.getDuellLibList();

        DuellLibListHelper.installWithDependenciesFile(DuellLibListHelper.DEPENDENCY_LIST_FILENAME);

        return "Installing done";
    }

}