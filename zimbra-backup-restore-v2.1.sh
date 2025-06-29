#!/bin/bash

# Direktori backup
BACKUP_DIR="/backup/zimbra"
mkdir -p "$BACKUP_DIR"

function backup_user() {
    local email="$1"
    echo "Backup: $email"
    USER_DIR="$BACKUP_DIR/$email"
    mkdir -p "$USER_DIR"

    sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m "$email" getRestURL "/?fmt=tgz" > "$USER_DIR/mailbox.tgz"

    sudo -u zimbra /opt/zimbra/bin/zmprov getAccount "$email" > "$USER_DIR/account.txt"

    sudo -u zimbra /opt/zimbra/bin/zmprov -l ga "$email" | grep userPassword > "$USER_DIR/pw.txt"
}

function backup_all_users() {
    rm -rf "$BACKUP_DIR"/*
    echo "Ambil daftar user..."
    users=$(sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa)

    export -f backup_user
    export BACKUP_DIR  # perlu supaya bisa diakses dalam subshell

    echo "$users" | xargs -n1 -P4 -I{} bash -c 'backup_user "$@"' _ {}

    echo "Backup user selesai"

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
    echo "Memulai proses restore semua akun dari direktori backup: $BACKUP_DIR"

    # Cek apakah folder backup ada
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[WARNING]  Direktori backup tidak ditemukan. Pastikan Anda telah melakukan proses backup sebelumnya."
        return 1
    fi

    # Cek apakah ada user folder selain distribution_lists
    USER_FOLDERS=($(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "distribution_lists"))
    if [ ${#USER_FOLDERS[@]} -eq 0 ]; then
        echo "[WARNING]  Direktori backup tersedia, namun tidak ditemukan data akun pengguna yang dapat direstore."
        return 1
    fi

    for USER_DIR in "${USER_FOLDERS[@]}"; do
        email=$(basename "$USER_DIR")
        echo "▶️  Memulihkan akun: $email"

        # Cek apakah akun sudah ada
        if sudo -u zimbra /opt/zimbra/bin/zmprov getAccount "$email" &>/dev/null; then
            echo "⚠️  [WARNING] Akun '$email' sudah ada. Melewati proses restore akun."
            continue
        fi

        echo "  - Memulihkan password..."
        PASS_HASH=$(grep userPassword "$USER_DIR/pw.txt" | awk '{print $2}')

        # Buat akun sementara dengan password dummy
        sudo -u zimbra /opt/zimbra/bin/zmprov createAccount "$email" "P@ssw0rd"

        # Ganti password dengan hash asli
        sudo -u zimbra /opt/zimbra/bin/zmprov ma "$email" userPassword "$PASS_HASH"

        echo "  - Memulihkan mailbox..."
        sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m "$email" postRestURL "/?fmt=tgz&resolve=skip" "$USER_DIR/mailbox.tgz"
    done

    echo "✅ Proses restore akun pengguna selesai."

    # Tambahan: restore distribution lists
    restore_distribution_lists
}


# Fungsi: Restore distribution list
function restore_distribution_lists() {
    echo "Mulai restore distribution list..."

    DL_DIR="$BACKUP_DIR/distribution_lists"
    if [[ ! -d "$DL_DIR" ]]; then
        echo "[WARNING] Tidak ada backup DL ditemukan"
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
