#!/bin/bash

# Direktori backup
BACKUP_DIR="/backup/zimbra"
mkdir -p "$BACKUP_DIR"

# Fungsi: Backup seluruh user
function backup_all_users() {
    rm -rf "$BACKUP_DIR"/*
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

        echo "  - Simpan password user..."
        sudo -u zimbra /opt/zimbra/bin/zmprov -l ga "$email" | grep userPassword > "$USER_DIR/pw.txt"
    done

    echo "Backup user selesai"

    # Tambahan: backup DL
    backup_distribution_lists
}

# Fungsi: Backup distribution list
function backup_distribution_lists() {
    rm -rf $BACKUP_DIR/distribution_lists/*
    echo "Ambil daftar distribution list..."
    DL_DIR="$BACKUP_DIR/distribution_lists"
    mkdir -p "$DL_DIR"

    # Ambil seluruh DL
    sudo -u zimbra /opt/zimbra/bin/zmprov gadl > "$DL_DIR/dl_list.txt"

    # Simpan detail tiap DL
    while read -r dl; do
        echo "  - Backup DL: $dl"
        sudo -u zimbra /opt/zimbra/bin/zmprov gdl "$dl" > "$DL_DIR/$dl.txt"
    done < "$DL_DIR/dl_list.txt"

    echo "Backup DL selesai"
}

# Fungsi: Restore seluruh user
function restore_all_users() {
    echo "Mulai restore semua user dari $BACKUP_DIR..."

    for USER_DIR in "$BACKUP_DIR"/*; do
        # Skip folder DL
        [[ "$USER_DIR" == *"/distribution_lists" ]] && continue

        email=$(basename "$USER_DIR")
        echo "Restore: $email"

        echo "  - Restore password..."
        PASS_HASH=$(grep userPassword "$USER_DIR/pw.txt" | awk '{print $2}')
        
        # Buat akun sementara dengan password dummy
        sudo -u zimbra /opt/zimbra/bin/zmprov createAccount "$email" "P@ssw0rd"
        
        # Ganti password dengan hash asli
        sudo -u zimbra /opt/zimbra/bin/zmprov ma "$email" userPassword "$PASS_HASH"

        echo "  - Restore mailbox..."
        sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m "$email" postRestURL "/?fmt=tgz&resolve=skip" "$USER_DIR/mailbox.tgz"
    done

    echo "Restore user selesai"

    # Tambahan: restore DL
    restore_distribution_lists
}

# Fungsi: Restore distribution list
function restore_distribution_lists() {
    echo "Mulai restore distribution list..."

    DL_DIR="$BACKUP_DIR/distribution_lists"
    if [[ ! -d "$DL_DIR" ]]; then
        echo "Tidak ada backup DL ditemukan"
        return
    fi

    while read -r dl; do
        echo "  - Restore DL: $dl"
        DL_FILE="$DL_DIR/$dl.txt"

        # Ambil member DL
        MEMBERS=$(grep "zimbraMailForwardingAddress:" "$DL_FILE" | awk '{print $2}')

        # Buat DL
        sudo -u zimbra /opt/zimbra/bin/zmprov cdl "$dl"

        # Tambahkan anggota
        for member in $MEMBERS; do
            sudo -u zimbra /opt/zimbra/bin/zmprov adlm "$dl" "$member"
        done

    done < "$DL_DIR/dl_list.txt"

    echo "Restore DL selesai"
}

# Menu Pilihan
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

