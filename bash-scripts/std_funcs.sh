#!/usr/bin/env bash

# This file contains a place to put standard code that is common across several
# test scripts. All the functions should be called std_...

# Load the ovs schema and start ovsdb.
std_start_db() {
	sudo rm /usr/local/etc/openvswitch/conf.db
	sudo $OVS_DIR/ovsdb/ovsdb-tool create /usr/local/etc/openvswitch/conf.db $OVS_DIR/vswitchd/vswitch.ovsschema

	sudo $OVS_DIR/ovsdb/ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
}
