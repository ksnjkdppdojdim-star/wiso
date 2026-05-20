#Requires -Version 5.1
# Texte d'aide centralise.

function Get-WisoHelpText {
    @'
wiso - audit reseau / Wi-Fi (usage interne, machines autorisees uniquement)

Wi-Fi
  wiso profiles              Liste des profils WLAN
  wiso show <profil>         Detail du profil sans cle en clair
  wiso key <profil>          Profil + cle en clair (key=clear) - sensible
  wiso "<profil>"            Raccourci : comme "wiso key <profil>" (un seul argument)

Reseau (leger, complement rapide - pas un equivalent nmap)
  wiso interfaces            Adresses IPv4 par interface
  wiso neighbors             Voisins ARP rapides (arp -a) - recommande sous Trish
  wiso neighbors win         Table Get-NetNeighbor (plus lent, peut depasser le timeout Trish)
  wiso ping <hote> [n]       Ping ICMP via ping.exe (defaut n=2, -w 1200 ms)
  wiso port <hote> <port>    Test TCP rapide (timeout ~900 ms)
  wiso scan <hote>           Ports TCP courants, test TCP court par port

Machine
  wiso who                   Hostname + utilisateur

Aide
  wiso help

Timeouts Trish : le client admin a souvent un delai court (~5 s) pour toute la requete.
Si tu vois "i/o timeout", privilegie "wiso neighbors" (arp) ou augmente le timeout cote Trish.
'@
}
