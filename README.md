# ovs-dpdk-scripts
===================

**Scripts for OVS 2.5 and DPDK 16.04**

This is a set of bash scripts and launcher python module to ease of developer's
 job who is working on OVS, DPDK. This framework can be used for any code
 development project. The framework helps developers in the many ways,

1. It can set repo specific environment. Its really useful when working with
different projects or different repos of same project.
2. It can run test cases on the current repo with its specific environment
settings.
3. Its easy to hook any test/build script with the framework and make it
running in a specific given environment.
4. Can be used to run prerequisite tests and compilations before commits.
5. Readily available with sample OVS+DPDK test cases and build scripts for OVS,
DPDK.

### Prerequisite
* Python 2.7 or higher
* Python termcolor module. This can be installed by "pip install termcolor".
* User account must be in sudoers list.
* The sudo password must be remembered by the system when running any function.
So that the script doesnt need to prompt password each time to users when
executing. The sudo password timeout can be set to indefinite by running
"sudo visudo" and add the line "Defaults    timestamp_timeout=-1".

### How to use it
* Run the script 'python-scripts/launch.py' from the OVS repo. The script
doesnt work when it is called from places other than OVS repo. The launcher
stores all the environment variable information in a file '.ovs-dpdk-script-env'
in OVS repo directory. Each OVS repo has its own '.ovs-dpdk-script-env'
file to hold its environment settings. A sample 'ovs-dpdk-script-env' file is
available in the repo for reference.
* Select the option to "SET-ALL-ENV" to set the environment for the OVS repo.
This is a one time activity for the repo to set all the environment variables.
Its possible to modify these values in future by using the options "SET-ALL-ENV"
or "SET-ONE-ENV".
* once the environment is set, user can use all the remaining available options
to do various compiling and test operations.
* Its possible to add/delete environment variables to support different use
cases. Modify "ENV_DICT" in launch.py on need basis.
* The bash script functions can also be added/deleted for the user requirement in
the framework without much additional overhead. Modify the
"BASH_SCRIPT_FNS" in launch.py to accommodate custom operations. Each entry in
"BASH_SCRIPT_FNS" has specific functionality. The function can be written
either in bash or a python.
* The 'START-SUBSHELL' option enable users a start a new bash shell for
executing the debug commands. The subshell has all the environment variables set
to run any commands. It is advised to close the subshell after use.

### Bash Scripts
These scripts are self sustained scripts that meant to do some specific task,
such as run a test, build a repo and etc. These scripts are called by the
python launcher module when a user selects specific option. Users can add
their own custom scripts as they wish. Its possible to add multiple operations
under one script file. The launcher module can also invoke specific function with
in a script file. It is advisable to create self sustained user scripts with no
user intervention while executing.

### Python Scripts
The script 'launch.py' is a invoker for all the other scripts. Directly running
the bash scripts may fail because environment for running the scripts are
prepared by launch.py.
However To run the provided bash scripts/command directly, The subshell option
can be used. The subshell have all the user environment set for executing
commands.

**Please contact me if you are facing any issues while using the test
infrastructure.**
