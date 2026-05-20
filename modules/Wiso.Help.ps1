#Requires -Version 5.1
# Texte d'aide centralise.

function Get-WisoHelpText {
    $ver = Get-WisoVersion
    @"
wiso $ver - audit reseau / Wi-Fi (usage interne, machines autorisees uniquement)

Wi-Fi
  wiso profiles              Liste des profils WLAN enregistres
  wiso wifi                  Connexion WLAN active
  wiso show <profil>         Detail du profil sans cle
  wiso key <profil>          Profil + cle (key=clear) - sensible
  wiso export [keys] [max N] Inventaire: wifi active + profils (defaut max 8)
  wiso export keys           Export avec mots de passe - TRES SENSIBLE
  wiso delete <profil>       Affiche avertissement (sans -force)
  wiso delete <profil> -force Supprime le profil WLAN
  wiso "<profil>"            Raccourci cle (un seul argument)

Reseau
  wiso interfaces            Adresses IPv4 par interface
  wiso neighbors             Table ARP complete
  wiso neighbors brief       Voisins utiles (sans multicast)
  wiso neighbors win         Get-NetNeighbor (lent)
  wiso route                 Routes IPv4
  wiso dns                   Serveurs DNS par interface
  wiso gateway               Passerelle + ping rapide
  wiso lan [max]             Ping sweep /24 (defaut 24, max 32)
  wiso ping <hote> [n]       Ping ICMP
  wiso port <hote> <port>    Test TCP rapide
  wiso scan <hote>           8 ports TCP courants
  wiso scan quick <hote>     4 ports (rapide)
  wiso portscan <h> <ports>  Ports personnalises (max 12)
  wiso nmap <cible> [args]   nmap.exe si installe (defaut -F)

Securite locale
  wiso firewall              Profils pare-feu Windows
  wiso listeners             TCP en ecoute
  wiso shares                Partages locaux

Machine
  wiso who                   Hostname + utilisateur
  wiso version               Version plugin

Aide
  wiso help

Timeouts Trish (~5 s): export max 4-6, neighbors brief, scan quick.
"@
}
