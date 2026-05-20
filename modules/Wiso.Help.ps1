#Requires -Version 5.1
# Texte d'aide centralise.

function Get-WisoHelpText {
    $ver = Get-WisoVersion
    @"
wiso $ver - audit reseau / Wi-Fi (usage interne, machines autorisees uniquement)

Wi-Fi
  wiso profiles              Liste des profils WLAN
  wiso wifi                  Resume parse (SSID, signal, canal, auth)
  wiso wifi raw              Sortie netsh complete
  wiso show <profil>         Detail sans cle
  wiso key <profil>          Profil + cle - sensible
  wiso export [keys] [max N] Inventaire profils
  wiso delete <profil> -force Suppression profil
  wiso "<profil>"            Raccourci cle

JSON (sortie ConvertTo-Json)
  wiso json wifi             Etat WLAN structure
  wiso json profiles         Noms de profils
  wiso json interfaces       IPv4 + passerelle
  wiso json neighbors        Voisins ARP (brief)
  wiso json dns | gateway | lan [parallel] [max N]
  wiso json who | version | firewall | listeners

Reseau
  wiso interfaces            IPv4 par interface
  wiso neighbors             ARP complet
  wiso neighbors brief       Voisins utiles
  wiso route | dns | gateway
  wiso lan [max]             Ping sweep sequentiel (/24)
  wiso lan parallel [max]    Ping sweep parallele (8 workers)
  wiso ping | port | scan | scan quick | portscan | nmap

Securite
  wiso firewall | listeners | shares

Machine
  wiso who | version | help

Timeouts Trish (~5 s): json wifi, neighbors brief, lan parallel max 24, scan quick.
"@
}
