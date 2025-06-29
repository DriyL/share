#!/bin/bash

BACKUP_DIR="/backup/zimbra_users"
mkdir -p "$BACKUP_DIR"

function backup_all_users() {
    rm -rf /backup/zimbra_users/*
    echo "Ambil daftar user..."
    users=$(sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa)

    for email in $users; do
        echo "Backup: $email"
        USER_DIR="$BACKUP_DIR/$email"
        mkdir -p "$USER_DIR"
	
        echo "  - Export mailbox..."
        sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m "$email" getRestURL "/?fmt=tgz" > "$USER_DIR/mailbox.tgz"

        echo "  - Simpan info akun..."
        sudo -u zimbra /opt/zimbra/bin/zmprov getAccount "$email" > "$USER_DIR/account.txt"
	
	echo " - simpan password user"
	sudo -u zimbra /opt/zimbra/bin/zmprov -l ga "$email" | grep userPassword > "$USER_DIR/pw.txt"

    done

    echo "Backup done"
}

function restore_all_users() {
    echo "Mulai restore semua user yang ada di $BACKUP_DIR..."

    for USER_DIR in "$BACKUP_DIR"/*; do
        email=$(basename "$USER_DIR")
        echo "Restore: $email"

	echo "  - Restore password"
        PASS_HASH=$(grep userPassword "$USER_DIR/pw.txt" | awk '{print $2}')
        sudo -u zimbra /opt/zimbra/bin/zmprov createAccount "$email" "P@ssw0rd"
	sudo -u zimbra /opt/zimbra/bin/zmprov ma "$email" userPassword "$PASS_HASH"
	
        echo "  - Restore mailbox..."
        sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m "$email" postRestURL "/?fmt=tgz&resolve=skip" "$USER_DIR/mailbox.tgz"
    done

    echo "Restore semua user telah selesai"
}

echo "Pilih opsi:"
select opsi in "Backup Semua User" "Restore Semua User"; do
    case $opsi in
        "Backup Semua User")
            backup_all_users
            break
            ;;
        "Restore Semua User")
            restore_all_users
            break
            ;;
        *)
            echo "Opsi tidak valid, ulangi"
            ;;
    esac
done

