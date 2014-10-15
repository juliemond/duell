package duell.objects;

import neko.vm.Mutex;

import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.io.Eof;
import haxe.io.Bytes;
import haxe.io.Path;
import sys.io.Process;

import duell.helpers.LogHelper;
import duell.helpers.PathHelper;
import duell.helpers.PlatformHelper;

typedef ProcessOptions = 
{
	?loggingPrefix : String, /// defaults to ""
	?logOnlyIfVerbose : Bool, /// defaults to true
	?systemCommand : Bool, /// defaults to false. 
	?timeout : Float /// defaults to 0 (no timeout)
}

class DuellProcess
{
	/// STDIN TO POST STUFF
	public var stdin : Output;

	/// STDOUT LISTENING
	private var stdoutLineBuffer : BytesOutput;
	private var stdout : BytesOutput;
	private var totalStdout : BytesOutput;
	private var stdoutMutex : Mutex;

	/// STDERR LISTENING
	private var stderr : BytesOutput;
	private var totalStderr : BytesOutput;
	private var stderrMutex : Mutex;
	private var stderrLineBuffer : BytesOutput;

	/// TIMEOUT
	private var timeoutTicker : Bool;

	/// EXIT VARS
	private var exitCodeCache : Null<Int> = null;
	private var finished : Bool = false;
	private var timedout : Bool = false;
	private var stdoutFinished : Bool = false;
	private var stderrFinished : Bool = false;

	/// HAXE PROCESS
	private var process : sys.io.Process;

	/// PARAMETERS
	private var systemCommand : Bool;
	private var loggingPrefix : String;
	private var logOnlyIfVerbose : Bool;
	private var timeout : Float;
	private var command : String;
	private var args : Array<String>;

	public function new(path : String, comm : String, args : Array<String>, options : ProcessOptions = null)
	{	
		/// PROCESS ARGUMENTS
		command = PathHelper.escape(comm);
		this.args = args;

		systemCommand = options != null && options.systemCommand != null ? options.systemCommand : false;
		loggingPrefix = options != null && options.loggingPrefix != null ? options.loggingPrefix : "";
		logOnlyIfVerbose = options != null && options.logOnlyIfVerbose != null ? options.logOnlyIfVerbose : true;
		timeout = options != null && options.timeout != null ? options.timeout : 0.0;

		/// CHECK FOR LOCAL COMMAND
		if (!systemCommand && PlatformHelper.hostPlatform != Platform.WINDOWS)
		{
			command = "./" + command;
		}

		/// CHANGE DIRECTORY
		var oldPath:String = "";
		if (path != null && path != "") {
			
			LogHelper.info ("", " - \x1b[1mChanging directory for running the process:\x1b[0m " + path + "");
			
			oldPath = Sys.getCwd ();
			Sys.setCwd (path);
			
		}

		/// FANCY PRINT
		var argString = "";
		
		for (arg in args) 
		{
			if (arg.indexOf (" ") > -1) 
			{
				argString += " \"" + arg + "\"";
			} 
			else 
			{
				argString += " " + arg;
			}
		}
		LogHelper.info ("", " - \x1b[1mRunning process:\x1b[0m " + command + argString);

		/// RUN THE PROCESS AND THE LISTENERS
		timeoutTicker = true;
		process = new sys.io.Process(command, args);

		stdin = process.stdin;

		startStdOutListener();
		startStdErrListener();
		startTimeoutListener();

		/// SET THE PATH BACK
		if (oldPath != "") 
		{
			Sys.setCwd (oldPath);
		}
	}

	private function log(logMessage : String) : Void
	{
		if (logMessage == "")
			return;
		var message = '\x1b[1m$loggingPrefix\x1b[0m $logMessage';
		if (logOnlyIfVerbose)
		{
			LogHelper.info("", message);
		}
		else
		{
			LogHelper.info(message, "");
		}
	}

	private function startStdOutListener()
	{
		stdout = new BytesOutput();
		totalStdout = new BytesOutput();
		stdoutMutex = new Mutex();
		stdoutLineBuffer = new BytesOutput();
		neko.vm.Thread.create(
			function ()
			{
				try
				{
					while(true)
					{
						var str = process.stdout.readString(1);
						stdoutMutex.acquire();
						stdout.writeString(str);
						totalStdout.writeString(str);
						stdoutMutex.release();

						if(str == "\n")
						{
							log(stdoutLineBuffer.getBytes().toString());
							stdoutLineBuffer = new BytesOutput();
						}
						else
						{
							stdoutLineBuffer.writeString(str);	
						}
						timeoutTicker = true;
					}
				}
				catch (e:Eof) {}
				catch (e:Dynamic) {LogHelper.info("", "Exception with stackTrace:\n" + haxe.CallStack.exceptionStack().join("\n"));}

				log(stdoutLineBuffer.getBytes().toString());
				finished = true;
				stdoutFinished = true;
			}
		);
	}

	private function startStdErrListener()
	{
		stderr = new BytesOutput();
		totalStderr = new BytesOutput();
		stderrMutex = new Mutex();
		stderrLineBuffer = new BytesOutput();
		neko.vm.Thread.create(
			function ()
			{
				try
				{
					while(true)
					{
						var str = process.stderr.readString(1);

						stderrMutex.acquire();
						stderr.writeString(str);
						totalStderr.writeString(str);
						stderrMutex.release();

						if(str == "\n")
						{
							log(stderrLineBuffer.getBytes().toString());
							stderrLineBuffer = new BytesOutput();
						}
						else
						{
							stderrLineBuffer.writeString(str);	
						}
						timeoutTicker = true;
					}
				}
				catch (e:Eof) {}
				catch (e:Dynamic) {LogHelper.info("", "Exception with stackTrace:\n" + haxe.CallStack.exceptionStack().join("\n"));}

				log(stderrLineBuffer.getBytes().toString());
				finished = true;
				stderrFinished = true;
			}
		);
	}

	private function startTimeoutListener()
	{
		if (timeout != 0)
		{
			neko.vm.Thread.create(
				function ()
				{
					while(!finished) /// something else can finish
					{
						if (!timeoutTicker)
						{
							finished = true;
							timedout = true;
							LogHelper.println('Process "$command ${args.join(" ")}" timed out.');
							process.kill();
							break;
						}
						timeoutTicker = false;
						Sys.sleep(timeout);
					}
				}
			);
		}
	}

	public function blockUntilFinished()
	{
		try {
			exitCodeCache = process.exitCode();
		}
		catch (e : Dynamic) {
			exitCodeCache = -1;
		}
		finished = true;
	}
	
	public function close()
	{
		if(!finished)
			process.close();
	}

	public function kill()
	{
		if(!finished)
			process.kill();
	}

	public function hasFinished() : Bool
	{
		return finished;
	}

	public function readCurrentStdout() : Bytes
	{
		if (stdout.length == 0)
			return null;

		stdoutMutex.acquire();

		var bytes = stdout.getBytes();
		stdout = new haxe.io.BytesOutput();

		stdoutMutex.release();

		return bytes;
	}

	public function readCurrentStderr() : Bytes
	{
		if (stderr.length == 0)
			return null;

		stderrMutex.acquire();

		var bytes = stderr.getBytes();
		stderr = new haxe.io.BytesOutput();

		stderrMutex.release();

		return bytes;
	}

	public function getCompleteStdout() : Bytes
	{
		if (!finished)
			return null;

		/// WAIT FOR THE STDOUT TO FINISH COMPLETELY
		while(!stdoutFinished) {};

		stdoutMutex.acquire();

		var bytes = totalStdout.getBytes();
		totalStdout = new haxe.io.BytesOutput();

		stdoutMutex.release();
		return bytes;
	}

	public function getCompleteStderr() : Bytes
	{
		if (!finished)
			return null;

		/// WAIT FOR THE STDERR TO FINISH COMPLETELY
		while(!stderrFinished) {};

		stderrMutex.acquire();
		
		var bytes = totalStderr.getBytes();
		totalStderr = new haxe.io.BytesOutput();

		stderrMutex.release();
		return bytes;
	}

	public function exitCode() : Int
	{
		if (!finished)
			return 0;

		/// ONLY ONE CALL TO EXIT CODE IS POSSIBLE, SO WE CACHE IT.
		if (exitCodeCache == null)
		{
			exitCodeCache = process.exitCode();
		}

		return exitCodeCache;
	}

	public function isTimedout() : Bool
	{
		return timedout;
	}
}