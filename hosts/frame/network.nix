# NetworkManager profiles of the home network, for the real host only
# (imported in flake.nix, not by frame-vm). Both profiles carry the route to
# the WireGuard network of infra2.0 through think; think forwards between the
# LAN and wg0. Routes on a profile apply with that profile only.
#
# The Fritzbox announces itself as resolver through IPv6 router advertisements
# and answers NXDOMAIN for think.do9ita.de; systemd-resolved accepts that and
# never asks AdGuard from DHCP, so these profiles ignore the announced servers.
#
# The PSK stays out of the Nix store and out of Git: ensureProfiles substitutes
# it at activation from the root-only environment file, which must exist before
# the rebuild.
_: let
  wg0Route = "10.0.0.0/24,192.168.42.178";
in {
  networking.networkmanager.ensureProfiles = {
    environmentFiles = ["/etc/nixos-secrets/networkmanager.env"];
    profiles = {
      wired = {
        connection = {
          id = "Wired connection 1";
          uuid = "036b1ebf-f0eb-38de-aaaa-2a50ca277300";
          type = "ethernet";
          interface-name = "enp43s0";
          autoconnect-priority = "-999";
        };
        ipv4 = {
          method = "auto";
          route1 = wg0Route;
        };
        ipv6 = {
          method = "auto";
          ignore-auto-dns = true;
        };
      };
      home-wifi = {
        connection = {
          id = "FritzLanIrgang";
          uuid = "ee1ace51-1abc-4ab1-8ee3-15ca269f6d28";
          type = "wifi";
          interface-name = "wlp170s0";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "FritzLanIrgang";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$HOME_WIFI_PSK";
        };
        ipv4 = {
          method = "auto";
          route1 = wg0Route;
        };
        ipv6 = {
          method = "auto";
          ignore-auto-dns = true;
        };
      };
    };
  };
}
