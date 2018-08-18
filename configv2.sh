#!/bin/bash

conffile="/etc/hoods/$1.conf"
[ -s "$conffile" ] || echo "Usage: $0 Hoodname " && exit
. "$conffile"

#fe80 IPv6 holen:
fe80=$(ip -6 addr show $ethernetinterface | grep "inet6 fe80" | grep -v "inet6 fe80::1" | tail -n 1 | cut -d " " -f6)
echo "Wir nutzen folgende fe80 IPv6: $fe80"

fastdport=$fastdportbase
while grep $fastdport /etc/fastd/fff.bat*/fff.bat*.conf* &>/dev/null ; do ((fastdport+=1)); done
echo "Wir nutzen $fastdport Port für fastd"
## $fastdport = port für fastdport


bat=$batbase
while grep bat$bat /etc/systemd/system/fastdbat* &>/dev/null ; do ((bat+=1)); done
echo "Wir nutzen $bat Nummer für Batman Interface"
## $bat = bat interface


httpport=$httpportbase
while grep $httpport /etc/apache2/sites-available/* &>/dev/null ; do ((httpport+=1)); done
echo "Wir nutzen $httpport Port für http Server"
## $httpport = port für httpserver


#### Folgende Dateien müssen angelegt oder bearbeitet werden: ####
# /etc/fastd/fff.bat"$bat"

mkdir /etc/fastd/fff.bat"$bat"
echo "#!/bin/bash
/sbin/ifdown \$INTERFACE" > /etc/fastd/fff.bat"$bat"/down.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/down.sh
echo "/etc/fastd/fff.bat"$bat" angelegt"

echo "#!/bin/bash
/sbin/ifup \$INTERFACE
batctl -m bat$bat gw_mode server 256000
ip6tables -t nat -A PREROUTING -i bat$bat -p tcp -d fe80::1 --dport 2342 -j REDIRECT --to-port $httpport" > /etc/fastd/fff.bat"$bat"/up.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/up.sh
echo "/etc/fastd/fff.bat"$bat"/up.sh angelegt"

echo "#!/bin/bash
return 0" > /etc/fastd/fff.bat"$bat"/verify.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/verify.sh
echo "/etc/fastd/fff.bat"$bat"/verify.sh angelegt"

echo "# Log warnings and errors to stderr
log level error;
# Log everything to a log file
log to syslog as \"fffbat$bat\" level info;
# Set the interface name
interface \"$fastdinterfacename\";
# Support xsalsa20 and aes128 encryption methods, prefer xsalsa20
#method \"xsalsa20-poly1305\";
#method \"aes128-gcm\";
method \"null\";
# Bind to a fixed port, IPv4 only
bind any:$fastdport;
# fastd need a key but we don't use them
secret \"90e9418a189e18f6a126a554081b445690a63752baa763ac26339c8742308144\";
# Set the interface MTU for TAP mode with xsalsa20/aes128 over IPv4 with a base MTU of 1492 (PPPoE)
# (see MTU selection documentation)
mtu 1426;
on up \"/etc/fastd/fff.bat$bat/up.sh\";
on post-down \"/etc/fastd/fff.bat$bat/down.sh\";
secure handshakes no;
on verify \"true\";
" > /etc/fastd/fff.bat"$bat"/fff.bat"$bat".conf
echo "/etc/fastd/fff.bat"$bat"/fff.bat"$bat".conf angelegt"

#/etc/network/interfaces.d/bat"$bat"

echo "#device: bat$bat
iface bat$bat inet manual
post-up ifconfig \$IFACE up
    ##Einschalten post-up:
    # IP des Gateways am B.A.T.M.A.N interface:
    post-up ip addr add $ipv4 dev \$IFACE
    post-up ip -6 addr add fe80::1/64 dev \$IFACE nodad
    post-up ip -6 addr add $ipv6 dev \$IFACE
    post-up ip -6 addr add $fe80 dev \$IFACE 
    # Regeln, wann die fff Routing-Tabelle benutzt werden soll: 
    post-up ip rule add iif \$IFACE table fff
    post-up ip -6 rule add iif \$IFACE table fff
    # Route in die XXXXXXXX Hood:       
    post-up ip route replace $ipv4net dev \$IFACE proto static table fff
    post-up ip -6 route replace $ipv6net dev \$IFACE proto static table fff 

    ##Ausschalten post-down:
    # Loeschen von oben definieren Routen, Regeln und Interface: 
    post-down ip route del $ipv4net dev \$IFACE table fff
    post-down ip -6 route del $ipv6net dev \$IFACE proto static table fff 
    post-down ip rule del iif \$IFACE table fff
    post-down ifconfig \$IFACE down

# VPN Verbindung in die $Hoodname Hood
iface $fastdinterfacename inet manual
    post-up batctl -m bat$bat if add \$IFACE
    post-up ifconfig \$IFACE up
    post-up ifup bat$bat
    post-down ifdown bat$bat
    post-down ifconfig \$IFACE down
" > /etc/network/interfaces.d/bat$bat
echo "/etc/network/interfaces.d/bat"$bat" angelegt" 

#/etc/systemd/system/fastdbat"$bat".service

echo "[Unit]
Description=fastd

[Service]
ExecStart=/usr/bin/fastd -c /etc/fastd/fff.bat$bat/fff.bat$bat.conf
Type=simple

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/fastdbat"$bat".service
echo "/etc/systemd/system/fastdbat"$bat".service angelegt"

#fastd service laden und starten

systemctl enable fastdbat"$bat"
systemctl start fastdbat"$bat"
echo "fastd Service gestartet und enabled"

#/etc/apache2/sites-available/bat"$bat".conf

echo "<VirtualHost *:$httpport>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/bat$bat
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/bat"$bat".conf
echo "/etc/apache2/sites-available/bat"$bat".conf angelegt"

#Ordner für Apache Home anlegen
mkdir /var/www/bat$bat
echo "/var/www/bat$bat angelegt

#/etc/apache2/ports.conf

sed -i '4i Listen '$httpport'' /etc/apache2/ports.conf
echo "Port in /etc/apache2/ports.conf erweitert"

#Apache config laden:

a2enside /etc/apache2/sites-available/bat"$bat".conf
systemctl reload apache2
echo "Config für Apache neu geladen und Apache neu gestartet"

#Cronjob für Hoodfile anlegen:

echo "*/5 * * * * root wget \"http://keyserver.freifunk-franken.de/v2/index.php?lat=$lat&long=$lon\" -O /var/www/bat$bat/keyxchangev2data
" > /etc/cron.d/bat"$bat"
echo "Cronjob in /etc/cron.d/bat"$bat" angelegt"

#/etc/systemd/system/dnsmasqbat"$bat".service

echo "[Unit]
Requires=network.target
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10

ExecStart=/usr/sbin/dnsmasq -k --conf-dir=/etc/dnsmasq.d,*.conf --interface bat$bat --dhcp-range=$dhcpstart,$dhcpende,$ipv4netmask,20m --pid-file=/var/run/dhcp-bat$bat.pid --dhcp-leasefile=/var/lib/misc/bat$bat.leases

[Install]
WantedBy=multi-user.target
"; > /etc/systemd/system/dnsmasqbat"$bat".service
echo "/etc/systemd/system/dnsmasqbat"$bat".service angelegt"

#start dnsmasq

systemctl start dnsmasqbat"$bat".service
systemctl enable dnsmasqbat"$bat".service
echo "dnsamsq enabled und gestartet"

echo "<html><header></header><body><img src="https://i.pinimg.com/originals/c8/af/e6/c8afe6457997851b504458a30b6d223d.jpg"></img></body></html>" > /var/www/html/index.html

#/etc/radvd.conf

echo "interface bat$bat {
        AdvSendAdvert on;
        MinRtrAdvInterval 60;
        MaxRtrAdvInterval 300;
        AdvDefaultLifetime 600;
        AdvRASrcAddress {
                $fe80; 
        };
        prefix $ipv6net {
                AdvOnLink on;
                AdvAutonomous on;
        };
        route fc00::/7 {
        };
};" >> /etc/radvd.conf
echo "/etc/radvd.conf erweitert"

#restart radvd

/etc/init.d/radvd restart
echo "radvd neu gestartet"

#/etc/systemd/system/alfredbat"$bat".service

echo "[Unit]
Description=alfred
Wants=fastdbat$bat.service

[Service]
ExecStart=/usr/sbin/alfred -m -i bat$bat -b none -u /var/run/alfredbat$bat.sock
Type=simple
ExecStartPre=/bin/sleep 20

[Install]
WantedBy=multi-user.target
WantedBy=fastdbat$bat.service" >> /etc/systemd/system/alfredbat"$bat".service
echo "/etc/systemd/system/alfredbat"$bat".service angelegt"

#Alfred config laden und starten

systemctl enable alfredbat"$bat"
systemctl start alfredbat"$bat"
echo "Alfred Service gestartet und enabled"

# MRTG Config neu machen

#/etc/mrtg/dhcp.cfg

echo "#!/bin/bash
leasecount=$(cat /var/lib/misc/bat0.leases | wc -l)
echo \"$leasecount\"
echo \"$leasecount\"
echo 0
echo 0" > /etc/mrtg/dhcpbat"$bat".sh
chmod +x /etc/mrtg/dhcpbat"$bat".sh
echo "/etc/mrtg/dhcpbat"$bat".sh angelegt und ausführbar gemacht"

echo "#!/bin/bash
gwlcount=$(/usr/sbin/batctl -m bat$bat gwl -H | wc -l)
echo \"$gwlcount\"
echo \"$gwlcount\"
echo 0
echo 0" > /etc/mrtg/gwlbat"$bat".sh
chmod +x /etc/mrtg/gwlbat"$bat".sh
echo "/etc/mrtg/gwlbat"$bat".sh angelegt und ausführbar gemacht"

echo "
WorkDir: /var/www/mrtg
Title[dhcpleasecount$bat]: DHCP-Leases
PageTop[dhcpleasecount$bat]: <H1>DHCP-Leases bat$bat $Hoodname</H1>
Options[dhcpleasecount$bat]: gauge,nopercent,growright,noinfo
Target[dhcpleasecount$bat]: \`/etc/mrtg/dhcpbat$bat.sh\`
MaxBytes[dhcpleasecount$bat]: $mengeaddr
YLegend[dhcpleasecount$bat]: DHCP Count
ShortLegend[dhcpleasecount$bat]: x
Unscaled[dhcpleasecount$bat]: ymwd
LegendI[dhcpleasecount$bat]: Count
LegendO[dhcpleasecount$bat]:

WorkDir: /var/www/mrtg
Title[gwlleasecount$bat]: Gatewayanzahl
PageTop[gwlleasecount$bat]: <H1>Gatewayanzahl bat$bat $Hoodname</H1>
Options[gwlleasecount$bat]: gauge,nopercent,growright,noinfo
Target[gwlleasecount$bat]: \`/etc/mrtg/gwlbat$bat.sh\`
MaxBytes[gwlleasecount$bat]: 3
YLegend[gwlleasecount$bat]: Gateway Count
ShortLegend[gwlleasecount$bat]: x
Unscaled[gwlleasecount$bat]: ymwd
LegendI[gwlleasecount$bat]: Count
LegendO[gwlleasecount$bat]:" >> /etc/mrtg/dhcp.cfg
echo "/etc/mrtg/dhcp.cfg erweitert"

echo "Mache mrtg config neu"
/usr/bin/cfgmaker --output=/etc/mrtg/traffic.cfg  -zero-speed=100000000 --global "WorkDir: /var/www/mrtg" --ifdesc=name,ip,desc,type --ifref=name,desc --global "Options[_]: bits,growright" public@localhost
sed -i -e 's/^\(MaxBytes.*\)$/\10/g' /etc/mrtg/traffic.cfg
/usr/bin/indexmaker --output=/var/www/mrtg/index.html --title="$(hostname)" --sort=name --enumerat /etc/mrtg/traffic.cfg /etc/mrtg/cpu.cfg /etc/mrtg/dhcp.cfg
cat /var/www/mrtg/index.html | sed -e 's/SRC="/SRC="mrtg\//g' -e 's/HREF="/HREF="mrtg\//g' -e 's/<\/H1>/<\/H1><img src="topology.png">/g' > /var/www/index.html 
echo "Mrtg config neu gemacht"
echo "Script fertig"


