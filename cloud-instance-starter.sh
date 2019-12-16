#!/bin/bash
set -eu
# ----------------------------------------------------------
# cloud-instance-starter
# ----------------------------------------------------------

get_instance() {
	case "$TYPE" in
		"EC2" )
			INSTANCE_INFO="$(aws ec2 describe-instances --filters 'Name=instance-id,Values='$INSTANCE_ID --query 'Reservations[].Instances[]')"
			INSTANCE_STATE="$(echo $INSTANCE_INFO | jq -r '.[].State.Name')"
			INSTANCE_PUBLIC_IPADDR="$(echo $INSTANCE_INFO | jq -r '.[].PublicIpAddress')"
			;;
		"GCE" )
			INSTANCE_INFO=$(gcloud compute instances list --filter="name:('$INSTANCE_NAME') AND zone:('$ZONE')" --format json)
			INSTANCE_STATE="$( echo $INSTANCE_INFO | jq -r '.[].status' )"
			INSTANCE_PUBLIC_IPADDR="$( echo $INSTANCE_INFO | jq -r '.[].networkInterfaces[].accessConfigs[].natIP' )"
			;;
		* )
			echo "unknown TYPE"
			exit 1
			;;
	esac
	set_ssh_con
}

wait_state() {
	local target=$1
	echo -n "$target になるまで待機します."
	get_instance
	while [ $INSTANCE_STATE != $target ]; do
		echo -n "."
		sleep 1
		get_instance
	done
	echo "起動しました."
}

wait_ssh() {
	echo -n "SSHが起動するまで待機しています."
	while ! ssh -o 'ConnectTimeout=1' $SSH_CON true > /dev/null 2>&1; do
		sleep 1
		echo -n "."
	done
	echo "接続を確認しました."
}

sshfs_mount() {
	set_ssh_con
	local mountpath="$HOME/.sshfsmount/$SSH_CON"
	echo "$mountpath にマウントします"
	mkdir -p $mountpath
	sshfs -o auto_cache,reconnect,defer_permissions,negative_vncache,noappledouble,idmap=user,workaround=nonodelay:rename,volname=$SSH_CON \
		$SSH_CON:$MOUNT_HOMEDIR $mountpath
	# macOS用
	open $mountpath
}

sshfs_unmount() {
	local mountpath="$HOME/.sshfsmount/$SSH_CON"
	echo "$mountpath をアンマウントします"
	# macOS用
	while ! hdiutil unmount $mountpath; do
		echo "アンマウントに失敗しました。10秒後再実行します"
		sleep 10
	done
	rmdir $mountpath
}

do_stop() {
	echo "インスタンスを停止します"
	case "$TYPE" in
		"EC2" )
			aws ec2 stop-instances --instance-ids $INSTANCE_ID
			wait_state stopped
			;;
		"GCE" )
			gcloud compute instances stop --zone=$ZONE $INSTANCE_NAME
			get_instance
			;;
	esac
	echo "インスタンスの状態: $INSTANCE_STATE"
}

do_start() {
	echo "インスタンスを起動します"
	case "$TYPE" in
		"EC2" )
			aws ec2 start-instances --instance-ids $INSTANCE_ID
			wait_state running
			;;
		"GCE" )
			gcloud compute instances start --zone=$ZONE $INSTANCE_NAME
			get_instance
			;;
	esac
	wait_ssh
	echo "インスタンスの状態: $INSTANCE_STATE"
	echo "公開IPアドレス:     $INSTANCE_PUBLIC_IPADDR"
}

do_run() {
	if [ -n "${TMUX:-}" ]; then
		echo "すでにtmuxの中です"
		exit 1
	fi
	do_start
	sshfs_mount
	ssh -tA $SSH_CON tmux
	sshfs_unmount
	do_stop
}

do_ip() {
	get_status
	if [ "$INSTANCE_PUBLIC_IPADDR" != "null" ]; then
		echo "$INSTANCE_PUBLIC_IPADDR"
	fi
}

do_status() {
	get_instance
	echo "インスタンスの状態: $INSTANCE_STATE"
	echo "公開IPアドレス:     $INSTANCE_PUBLIC_IPADDR"
}

run() {
    for i in $COMMANDS; do
    if [ "$i" == "${1:-}" ]; then
        shift
        do_$i $@
        exit 0
    fi
    done
    echo "USAGE: $( basename $0 ) COMMAND"
    echo "COMMANDS:"
    for i in $COMMANDS; do
    echo "   $i"
    done
    exit 1
}

COMMANDS="start stop run ip status"
