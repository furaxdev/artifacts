#!/usr/bin/env python3
"""Affiche la cle de produit du Windows installe sur ce disque, depuis Linux.

Lit la valeur DigitalProductId dans la ruche de registre SOFTWARE, puis la
decode. C'est la seule valeur qui contient la VRAIE cle installee :
BackupProductKeyDefault, lui, ne contient qu'une cle generique.

Prerequis : chntpw  (sudo pacman -S chntpw)

Usage :
    sudo python3 cle-windows.py [partition]

    partition par defaut : /dev/sda3
"""

import re
import subprocess
import sys
import tempfile
import os

ALPHABET = "BCDFGHJKMPQRTVWXY2346789"


def decoder(octets):
    """Decode les 15 octets de DigitalProductId en cle lisible."""
    octets = list(octets)
    cle = ""
    for _ in range(24, -1, -1):
        reste = 0
        for j in range(14, -1, -1):
            reste = (reste << 8) | octets[j]
            octets[j] = reste // 24
            reste %= 24
        cle = ALPHABET[reste] + cle

    # Depuis Windows 8, la cle commence par un N qu'il faut deplacer au 9e rang
    if cle and cle[0] == "N":
        cle = cle[1:]
        cle = cle[:8] + "N" + cle[8:]

    return "-".join(cle[i:i + 5] for i in range(0, len(cle), 5))


def extraire_hex(texte):
    """Recupere la suite d'octets affichee par chntpw."""
    # lignes du type : 0000  A4 00 00 00 03 00 00 00 ...
    octets = []
    for ligne in texte.splitlines():
        if not re.match(r"^[0-9a-fA-F]{4}\s", ligne):
            continue
        for bloc in re.findall(r"\b[0-9a-fA-F]{2}\b", ligne[4:]):
            octets.append(int(bloc, 16))
    return octets


def principal():
    partition = sys.argv[1] if len(sys.argv) > 1 else "/dev/sda3"
    point = "/mnt/win"

    if os.getuid() != 0:
        print("  Lance avec sudo : sudo python3 %s" % sys.argv[0])
        return 1

    os.makedirs(point, exist_ok=True)
    if not os.path.ismount(point):
        r = subprocess.run(["mount", "-o", "ro", partition, point],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print("  montage impossible :", r.stderr.strip())
            return 1
        demonte = True
    else:
        demonte = False

    ruche = os.path.join(point, "Windows/System32/config/SOFTWARE")
    if not os.path.isfile(ruche):
        print("  ruche introuvable :", ruche)
        return 1

    # chntpw est interactif : on lui donne les commandes par l'entree standard
    ordres = "cd \\Microsoft\\Windows NT\\CurrentVersion\nhex DigitalProductId\nq\n"
    r = subprocess.run(["chntpw", "-e", ruche], input=ordres,
                       capture_output=True, text=True)
    sortie = r.stdout + r.stderr

    octets = extraire_hex(sortie)
    if len(octets) < 67:
        print("  DigitalProductId introuvable (%d octets lus)." % len(octets))
        print("  Verifie que chntpw est installe : sudo pacman -S chntpw")
        return 1

    # la cle occupe les octets 52 a 66 de la valeur
    cle = decoder(octets[52:67])

    print()
    print("  Cle installee : %s" % cle)
    print()

    generiques = {
        "VK7JG-NPHTM-C97JM-9MPGT-3V66T": "Windows 10 Pro",
        "YTMG3-N6DKC-DKB77-7M9GH-8HVX7": "Windows 10 Famille",
        "NPPR9-FWDCX-D2C8J-H872K-2YT43": "Windows 10 Entreprise",
        "BT79Q-G7N6G-PGBYW-4YWX6-6F4BT": "Windows 10 Famille (N)",
        "XKCNC-J26Q9-KFHD2-FKTHY-KD72Y": "Windows 10 Pro (N)",
    }
    if cle.upper() in generiques:
        print("  C'est la cle GENERIQUE de %s." % generiques[cle.upper()])
        print("  Autrement dit : ton Windows est active par licence numerique")
        print("  liee au materiel. Aucune cle reelle n'est stockee, et tu n'en")
        print("  as pas besoin : une reinstallation de la meme edition se")
        print("  reactivera toute seule.")
    else:
        print("  C'est ta vraie cle. Garde-la quelque part de sur, mais retiens")
        print("  qu'une reinstallation de la meme edition se reactive sans elle.")

    if demonte:
        subprocess.run(["umount", point], capture_output=True)
    return 0


if __name__ == "__main__":
    sys.exit(principal())
