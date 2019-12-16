# cloud-workspace-instance-starter

EC2, GCEを起動してsshfsでホームディレクトリをマウント、tmuxを起動し、tmuxをぬけるとsshfsをアンマウントしてインスタンスを終了するスクリプ
ト

## 必要なもの

macOS用ですが、若干修正すれば任意のLinuxでも動くと思います。

* awscli, gcloud, bash, jq, ssh, sshfs など
* パブリックIPアドレスからSSH接続できる必要がある

## TIPSとメモ

* sshfsマウントフォルダは $HOME/.sshfsmount 以下のフォルダになる
* 事前にssh-addしておく
* SSH設定がuser@host だけで収まらない場合は \~/.ssh/config を使う

## インストールと 設定方法

* example-ec2またはexample-gceを参考にシェルスクリプトを書く
* cloud-instance-starter.sh を新たにつくった上記のファイルと同じ場所、もしくは任意の場所に置く

## コマンド

コマンド | 内容
---------|------------
start | インスタンス起動
stop  | インスタンス停止
run   | 起動→sshfsマウント→tmux起動→sshfsアンマウント→停止
ip    | パブリックIPアドレス

