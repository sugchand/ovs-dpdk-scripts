#!/usr/bin/python
import os
import subprocess
import sys
import collections
try:
    from termcolor import colored
except ImportError:
    raise ImportError('Install colored by \"sudo pip install termcolor\"')

# Holds all the environment settings that needed for OVS-DPDK scripts
ENV_DICT = {
            "OVS_DIR" : "",
            "DPDK_DIR" : "",
            "QEMU_DIR" : "",
            "VM_IMAGE" : "",
            "DPDK_NIC1" : "",
            "DPDK_NIC2" : "",
            "DPDK_PCI1" : "",
            "DPDK_PCI2" : "",
            "VHOST_NIC1" : "",
            "VHOST_NIC2" : "",
            "KERNEL_NIC_DRV" : "",
            "DPDK_TARGET" : ""
            }
ENV_FILE_NAME = ".ovs-dpdk-script-env"

"""
The script functions for each specific operation to be performed.
The format will be <option> : [<script_name>, <function_name>.
An eg: to build DPDK ivshmem is looks like
BUILD_DPDK_IVSHM : [build_script.sh, build_dpdk_ivshm]
"""
BASH_SCRIPT_FNS = {
                   "CLEAN-TEST": ["clean_test.sh", "clean"],
                   "PHY-PHY-TEST": ["phy2phy_manual.sh", "menu"],
                   "PHY-VXLAN-PHY-TEST": ["phy2phy_vxlan-bidir.sh", "menu"],
                   "PHY-VM-PHY-TEST": ["phy2vm_manual.sh", "menu"],
                   #Just build with existing config settings
                   "BUILD-OVS-NO-CLEAN": ["build_script.sh", "build_ovs_default"],
                   "BUILD-OVS-GCC-DPDK-NATIVE": ["build_script.sh", "build_ovs_gcc"],
                   "BUILD-OVS-DPDK-NATIVE": ["build_script.sh", "build_ovs"],
                   "BUILD-OVS-DPDK-IVSHM": ["build_script.sh", "build_ovs_ivshm"],
                   "BUILD-VANILA-OVS": ["build_script.sh", "build_vanila_ovs"],
                   # build the OVS with /var and /usr prefix than /usr/local
                   "BUILD-VANILA-OVS-PREFIX": ["build_script.sh", "build_vanila_ovs_prefix"],
                   "BUILD-DPDK-NATIVE": ["build_script.sh", "build_dpdk"],
                   "BUILD-DPDK-IVSHM": ["build_script.sh", "build_dpdk_ivshm"],
                   "OVS-SANITY-UT": ["build_script.sh", "build_check"],
                   "OVS-PURGE-CLEAN": ["build_script.sh", "clean_repo"],
                   # Leave the script field empty when fn is local.
                   "DEFINE-ALL-ENV" : ["", "set_and_save_env"],
                   "DEFINE-ONE-ENV" : ["", "set_and_save_selected_env"],
                   "START-SHELL" : ["", "start_bash_shell"]
                   }
def print_color_string(s, color='white'):
    print("%s" %(colored(s, color, attrs = ['bold'])))

def run_bash_command(cmd, *args):
    exec_cmd = []
    exec_cmd.append(cmd)

    if(len(args)):
        exec_cmd = exec_cmd + list(args)

    exec_cmd = filter(None, exec_cmd)
    print exec_cmd

    try:
        out = subprocess.Popen(exec_cmd)
    except Exception as e:
        print_color_string("Failed to run the bash command, " + e,
                           color = 'red')
    out.wait()

def run_bash_command_with_list_args(cmd, args):
    run_bash_command(cmd, *args)

def is_ovs_repo(dir_path):
    if not dir_path:
        print_color_string("File path is missing", color='red')
        return False

    if not os.path.isdir(dir_path):
        print_color_string("The directory path is wrong", color='red')
        return False

    file1 = dir_path + "/INSTALL.md"
    file2 = dir_path + "/INSTALL.DPDK.md"

    if not (os.path.isfile(file1) and os.path.isfile(file2)):
        print_color_string("Not in OVS repo, INSTALL files missing",
                           color = 'red')
        return False

    return True

def is_dpdk_repo(dir_path):
    if not dir_path:
        print_color_string("File path is missing", color='red')
        return False

    if not os.path.isdir(dir_path):
        print_color_string("The directory path is wrong", color='red')
        return False

    file1 = dir_path + "/config/common_linuxapp"
    file2 = dir_path + "/config/common_bsdapp"

    if not (os.path.isfile(file1) and os.path.isfile(file2)):
        print_color_string("Not in DPDK repo, config files missing",
                           color = 'red')
        return False

    return True

def read_and_display_env():
    env_ = os.getcwd() + "/" + ENV_FILE_NAME
    if not os.path.isfile(env_):
        print_color_string("Enviornment file is missing in repo", color = 'red')
        return False

    env_fp = open(env_, 'r')
    for line in env_fp.readlines():
        (key, value) = line.split(':-')

        if not (key and value):
            print_color_string("Something went wrong in file, its corrupted",
                               color = 'red')
            continue

        if not key in ENV_DICT:
            print_color_string("Invalid key in the file, corrupted file",
                               color = 'red')
            continue

        ENV_DICT[key] = value.strip('\n')
    env_fp.close()

    env_fp = open(env_, 'w')
    for key, value in ENV_DICT.iteritems():
        print_color_string(key + " :- " + value + "\n",
                           color='green')
        env_fp.write(str(key) + ":-" + str(value) + "\n")

    env_fp.close()
    return True

def set_and_save_selected_env():
    read_and_display_env()

    env_ = os.getcwd()
    env_ = env_ + "/" + ENV_FILE_NAME

    while(1):
        key_in = raw_input("Enter the env variable to update, One at a time"
                           " (Press Enter to exit): ")
        if not key_in:
            return

        if not key_in in ENV_DICT:
            print_color_string("env variable not exists..", color = "red")
            key_in = raw_input("Enter the correct key, (Press Enter to exit): ")
            if not key_in:
                break
            continue
        break

    env_fp = open(env_, 'w')

    for key, value in ENV_DICT.iteritems():
        value = value.rstrip('\n')
        if key == key_in:
            data = raw_input("Enter new value to update %s: " %key_in)
            value = data.strip()
        env_fp.write(str(key) + ":-" + str(value) + "\n")

    env_fp.close()
    read_and_display_env()

def set_and_save_env():
    read_and_display_env()

    env_ = os.getcwd()
    env_ = env_ + "/" + ENV_FILE_NAME
    env_fp = open(env_, 'w')

    print_color_string("Press Enter to keep the value unchanged ",
                       color='green')

    for key, value in ENV_DICT.iteritems():
        value = value.rstrip('\n')
        data = raw_input(key + "=" + value + ": ")
        if data:
            value = data.strip()
        env_fp.write(str(key) + ":-" + str(value) + "\n")

    env_fp.close()

def set_env_for_bash():
    read_and_display_env()
    for key, value in ENV_DICT.iteritems():
        os.environ[key] = value

def start_bash_shell():
    read_and_display_env()
    for key, value in ENV_DICT.iteritems():
        os.environ[key] = value
    print_color_string("Opening a new subshell.......\n", color='blue')
    print_color_string("****************************************************\n"
                       "*****NOTE :: DO EXIT THE SUBSHELL AFTER THE USE*****\n"
                       "****************************************************\n",
                       color="red")
    os.system("/bin/bash")

def run_bash_script_fn(script_file, fn):
    if not script_file:
        print_color_string("Invalid script " + script_file, color = "red")
        return
    script_path = os.path.dirname(os.path.realpath(__file__))
    script_path = os.path.abspath(os.path.join(script_path, os.pardir)) + \
                                                "/bash-scripts"
    script_file = script_path + "/" + script_file
    set_env_for_bash()
    run_bash_command("bash", "-c", ". " + script_file + "; " + fn)

def list_and_run():
    for i, (key, value) in enumerate(BASH_SCRIPT_FNS.iteritems()):
        print_color_string(str(i) + " : " + key, color="cyan")
    choice = (raw_input("Enter your choice[0-%d] : " %i))

    if choice == "":
        print_color_string("Invalid Choice, Exiting...", color = "red")
        return

    choice = int(choice)
    if choice < 0 or choice > i:
        print_color_string("Invalid Choice, Exiting...", color = "red")
        return

    script_file = BASH_SCRIPT_FNS.values()[choice][0]
    fn = BASH_SCRIPT_FNS.values()[choice][1]
    if script_file:
        run_bash_script_fn(script_file, fn)
    else:
        eval(fn)()

def main():

    if not is_ovs_repo(os.getcwd()):
        print_color_string("Not a valid repo", color = 'red')
        return False
    list_and_run()

main()
