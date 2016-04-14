# ovs-dpdk-scripts
===================

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
5. Readily available sample OVS+DPDK test cases and build scripts for OVS, DPDK.

### How to use it
1. Run the script 'python-scripts/launch.py' from the OVS repo. The script
doesnt work when it is called from places other than OVS repo. The launcher
stores all the environment variable information in a file '.ovs-dpdk-script-env'
created in OVS repo file. Each OVS repo has its own '.ovs-dpdk-script-env' file
to hold its environment settings.
2. Select the option to "SET-ALL-ENV" to set the environment for the OVS repo.
This is a one time activity for the repo to set all the environment settings.
Its possible to modify the values later by using the options "SET-ALL-ENV" or
"SET-ONE-ENV".
3. once the environment is set, user can use all the remaining available options
to do various building and test operations.
4. Its possible to add/delete environment variables to use for different use
cases. Modify "ENV_DICT" in launch.py for the specific requirement.
5. The bash script functions can be added/deleted for the user requirement in
the framework without much additional overhead. User can modify
"BASH_SCRIPT_FNS" in launch.py to accommodate custom operations. Each entry in
"BASH_SCRIPT_FNS" has specific functionality. The function can be
either a bash or a python specific function.

### Bash Scripts
These scripts are self sustained scripts that meant to do some specific task,
such as run a test, build a repo and etc. These scripts are called by the
python launcher module when a user selects specific option. Users can add
their own custom scripts as they wish. Its possible to add scripts that can do
multiple operations. The launcher module can also invoke specific function with
in a script file.Launcher cannot pass user inputs to the bash scripts at run
time. So all scripts must be self sustained to make use of this framework.

### Python Scripts
The script 'launch.py' is a invoker for all the other scripts. Directly running
the bash scripts may fail because environment for running the scripts are
prepared by launch.py.
