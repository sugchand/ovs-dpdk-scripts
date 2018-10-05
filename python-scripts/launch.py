#!/usr/bin/python
import os
import subprocess
import sys
import collections
import re

try:
    from termcolor import colored
except ImportError:
    print "If you use 'pip install termcolor' this will be in glorious color :)"
    print "Trudging on with boring monochrome :( ..."
    def colored (string_, color, attrs):
        """Supply null-op for termcolor.colored"""
        return string_

# Holds all the environment settings that needed for OVS-DPDK scripts
ENV_DICT = collections.OrderedDict ([
    ("DPDK_DIR", ""),
    ("DPDK_NIC1", ""),
    ("DPDK_NIC2", ""),
    ("DPDK_NICS", ""),
    ("DPDK_PCI1", ""),
    ("DPDK_PCI2", ""),
    ("DPDK_PCI3", ""),
    ("DPDK_PCI4", ""),
    ("DPDK_TARGET", ""),
    ("DPDK_VER", ""),
    ("KERNEL_NIC_DRV", ""),
    ("OVS_DIR", ""),
    ("PMD_CPU_MASK", ""),
    ("QEMU_DIR", ""),
    ("VHOST_MAC1", ""),
    ("VHOST_MAC2", ""),
    ("VHOST_NIC1", ""),
    ("VHOST_NIC2", ""),
    ("VM_IMAGE", "")])
ENV_FILE_NAME = ".ovs-dpdk-script-env"

"""
The script functions for each specific operation to be performed.
The format will be <option> : [<script_name>, <function_name>.
An eg: to build DPDK ivshmem is looks like
BUILD_DPDK_IVSHM : [build_script.sh, build_dpdk_ivshm]
"""
BASH_SCRIPT_FNS = collections.OrderedDict ([
                   ("CLEAN-TEST-SYSTEM", ["clean_test.sh", "clean"]),
                   #("PRIPATH-TEST", ["pp.sh", "menu"]),
                   ("VM-VM-TEST", ["vm2vm_manual.sh", "menu"]),
                   ("MULTICAST", ["multicast.sh", "menu"]),
                   ("PHY-PHY-VANILA-TEST", ["phy2phy_stockovs.sh", "menu"]),
                   ("PHY-PHY-TEST", ["phy2phy_manual.sh", "menu"]),
                   #("PVP-2PHY-2VHOST-TEST", ["phy2vm_manual.sh", "menu"]),
                   ("PVP-1P-TEST", ["pvp-1p_manual.sh", "menu"]),
                   #("PHY-PHY-BOND-TEST", ["phy2phy-bond-bidir.sh", "menu"]),
                   ("PHY-VXLAN-PHY-TEST", ["phy2phy_vxlan-bidir.sh", "menu"]),
                   ("PHY-NVGRE-PHY-TEST", ["phy2phy_nvgre-bidir.sh", "menu"]),
                   ("PVP-VXLAN-1P-TEST", ["pvp-vxlan-1p-loopback.sh", "menu"]),
                   ("PHY-VXLAN-PHY-noENCAP-TEST", ["phy2phy_vxlan-bidir-no-encap-traffic.sh", "menu"]),
                   #("PHY-CONT-PHY-TEST", ["phy2cont_manual.sh", "menu"]),
                   #Just build with existing config settings
                   #("BUILD-OVS-NO-CLEAN", ["build_script.sh", "build_ovs_default"]),
                   ("BUILD-OVS-GDB-DPDK-NATIVE", ["build_script.sh", "build_ovs_gdb"]),
                   ("BUILD-OVS-DPDK-NATIVE", ["build_script.sh", "build_ovs"]),
                   #("BUILD-OVS-DPDK-IVSHM", ["build_script.sh", "build_ovs_ivshm"]),
                   #("BUILD-VANILA-OVS", ["build_script.sh", "build_vanila_ovs"]),
                   #("BUILD-OVS+DPDK-PERF-GDB", ["build_script.sh", "build_ovs_and_dpdk_gdb_perf"]),
                   # build the OVS with /var and /usr prefix than /usr/local
                   #("BUILD-VANILA-OVS-PREFIX", ["build_script.sh", "build_vanila_ovs_prefix"]),
                   ("BUILD-DPDK-NATIVE", ["build_script.sh", "build_dpdk"]),
                   ("BUILD-DPDK-GDB", ["build_script.sh", "build_dpdk_gdb"]),
                   #("OVS-SANITY-UT", ["build_script.sh", "build_check"]),
                   #("OVS-PURGE-CLEAN", ["build_script.sh", "clean_repo"]),
                   # Leave the script field empty when fn is python local.
                   #("DEFINE-ALL-ENV" , ["", "set_and_save_env"]),
                   #("DEFINE-ONE-ENV" , ["", "set_and_save_selected_env"]),
                   #("START-SUBSHELL" , ["", "start_bash_shell"])
                   ])

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
    return out.returncode

def run_bash_command_with_list_args(cmd, args):
    return run_bash_command(cmd, *args)

def is_ovs_repo(dir_path):
    if not dir_path:
        print_color_string("File path is missing", color='red')
        return False

    if not os.path.isdir(dir_path):
        print_color_string("The directory path is wrong", color='red')
        return False

    file1 = dir_path + "/Documentation/howto/dpdk.rst"
    file2 = dir_path + "/Documentation/intro/what-is-ovs.rst"

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
        if not line:
            continue
        if line.strip().find("export") > 0:
            # Line does not begin with 'export'
            continue
        (tmp, value) = line.split('=')
        (export, key) = tmp.split(' ')

        if not (key and value):
            print_color_string("Something went wrong in file, its corrupted",
                               color = 'red')
            continue

        if not key in ENV_DICT:
            print_color_string("Invalid key in the file, corrupted file",
                               color = 'red')
            print("%s=%s\n" % (str(key), str(value)))
            continue

        ENV_DICT[key] = value.strip('\n')
    env_fp.close()

    env_fp = open(env_, 'w')
    for key, value in ENV_DICT.iteritems():
        #print_color_string(key + " :- " + value + "\n", color='green')
        env_fp.write("export %s=%s\n" % (str(key), str(value)))

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
        env_fp.write("export %s=%s\n" % (str(key), str(value)))
        #env_fp.write(str(key) + ":-" + str(value) + "\n")

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
        env_fp.write("export %s=%s\n" % (str(key), str(value)))
        #env_fp.write(str(key) + ":-" + str(value) + "\n")

    env_fp.close()

def set_env_for_bash():
    read_and_display_env()
    for key, value in ENV_DICT.iteritems():
        os.environ[key] = value

def start_bash_shell():
    set_env_for_bash()
    os.environ['OVS_RUN_SUBSHELL'] = '1'
    print_color_string("Opening a new subshell.......\n", color='blue')
    print_color_string("****************************************************\n"
                       "*****NOTE :: DO EXIT THE SUBSHELL AFTER THE USE*****\n"
                       "****************************************************\n",
                       color="red")
    rc_path = os.path.dirname(os.path.realpath(__file__))
    rc_path = os.path.abspath(os.path.join(rc_path, os.pardir)) + \
                                                "/bash-scripts"
    rc_file = rc_path + "/rc_file"
    os.system("/bin/bash --rcfile " + rc_file)

def run_bash_script_fn(script_file, fn):
    if not script_file:
        print_color_string("Invalid script " + script_file, color = "red")
        return
    script_path = os.path.dirname(os.path.realpath(__file__))
    script_path = os.path.abspath(os.path.join(script_path, os.pardir)) + \
                                                "/bash-scripts"
    script_file = script_path + "/" + script_file
    set_env_for_bash()
    return run_bash_command("bash", "-c", ". " + script_file + "; " + fn)

def list_and_run():
    for i, (key, value) in enumerate(BASH_SCRIPT_FNS.iteritems()):
        print_color_string(str(i) + " : " + key, color="cyan")

    # keep asking user for a list of choices until they are all valid
    choices = []
    while True:
        choices = []

        # Treat cli args as if entered to choice query
        if len(sys.argv) == 1:
            choices_str = raw_input("Enter your (list of) choice(s)[0-%d] : " %i)
        else:
            choices_str = " ".join(sys.argv[1:])
            sys.argv = []
        if not choices_str:
            print_color_string("Invalid Choice...", color = "red")
            continue

        choices_str_list = re.split(" |,", choices_str)
        choices_str_list = [s.strip() for s in choices_str_list if s]
        for choice_str in choices_str_list:
            try:
                choice_int = int(choice_str)
            except:
                print_color_string("Choice '%s' is not an integer..." % \
                    choice_str, color = "red")
                break

            if choice_int < 0 or choice_int > i:
                print_color_string("Choice %d is out of range..." % \
                    choice_int, color = "red")
                break

            choices.append(choice_int)
        else:
            # loop did not break - all chocices are valid
            break

    # exec each of the choices in turn - exit if one fails
    for choice in choices:
        choice_name = BASH_SCRIPT_FNS.keys()[choice]
        print_color_string(choice_name, color = "green")
        script_file = BASH_SCRIPT_FNS.values()[choice][0]
        fn = BASH_SCRIPT_FNS.values()[choice][1]
        if script_file:
            if run_bash_script_fn(script_file, fn) != 0:
                print_color_string("'%s' FAILED. Quitting..." % \
                    choice_name, color = "red")
                break
        else:
            # choices that correspond to internal python fns cannot fail
            eval(fn)()

def main():
    if not is_ovs_repo(os.getcwd()):
        print_color_string("Not a valid repo", color = 'red')
        return False
    try:
        list_and_run()
    except KeyboardInterrupt, ex:
        print "\nBye!"

main()
