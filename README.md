# wiso (plugin Trish)

Plugin dynamique **Windows** pour [Trish](https://github.com/ksnjkdppdojdim-star/trish) : Wi‑Fi, ARP, routes, DNS, gateway, scan LAN/TCP, pare-feu, écoutes, partages.

**Version actuelle : 0.3.0**

## Architecture

```text
wiso/
  trish-plugin.json
  wiso.ps1                    # charge modules\ puis Invoke-WisoDispatch
  modules/
    Wiso.Common.ps1           # version, encodage OEM, exec native, erreurs
    Wiso.Help.ps1
    Wiso.Wlan.ps1             # profiles, wifi (interfaces), show, key
    Wiso.Network.ps1          # neighbors, route, dns, gateway, lan, ping, scan
    Wiso.Security.ps1         # firewall, listeners, shares
    Wiso.Machine.ps1          # who, version
    Wiso.Dispatch.ps1         # routage
```

## Installation / mise à jour

```powershell
trish plugin install https://github.com/ksnjkdppdojdim-star/wiso.git
trish plugin update https://github.com/ksnjkdppdojdim-star/wiso.git
```

## Commandes (v0.3)

### Wi‑Fi

```powershell
wiso profiles
wiso wifi
wiso show "MonSSID"
wiso key "MonSSID"
wiso "MonSSID"
```

### Réseau

```powershell
wiso interfaces
wiso neighbors
wiso neighbors brief
wiso route
wiso dns
wiso gateway
wiso lan 16
wiso ping 192.168.100.1
wiso port 192.168.100.10 445
wiso scan 192.168.100.10
wiso scan quick 192.168.100.10
wiso portscan 192.168.100.10 80,443,8080
```

### Sécurité locale

```powershell
wiso firewall
wiso listeners
wiso shares
```

### Machine

```powershell
wiso who
wiso version
wiso help
```

## Timeouts Trish

Le CLI admin impose un délai global court. En cas de `i/o timeout` :

- `wiso neighbors brief` plutôt que `neighbors win`
- `wiso scan quick` plutôt que `scan`
- `wiso lan 16` plutôt que `lan 32`

## Développement local

```powershell
trish plugin test "M:\wiso"
powershell -NoProfile -File "M:\wiso\wiso.ps1" help
```

## Licence

MIT — voir [LICENSE](LICENSE).
