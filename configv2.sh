#!/bin/bash

# Folgende Zeilen anpassen #

Hoodname="BLABLA"
ipv6="fd43:5602:29bd:18::X/64" # die eigene v6 ULA Adresse mit Netzgröße
ipv6net="fd43:5602:29bd:18::/64" # Das ULA Subnetz für die Hood
ipv4="1.2.3.4/22" # die eigene v4 Adresse mit Netzgröße
ipv4withoutnet="1.2.3.4"
ipv4net="1.2.3.0/22" # das v4 Subnetz der Hood
ipv4netmask="255.255.248.0"
dhcpstart="1.2.3.0" # Startadresse von DHCP
dhcpende="1.2.4.0" # Endandresse von DHCP
fastdinterfacename="fffBLABLAVPN" # Name des VPN Interfaces
fastdport=10000
batbase=0
httpportbase=2342

# Ab hier nichts mehr ändern! #


fastdportbase=$fastdport
while grep $fastdport /etc/fastd/fff.bat*/fff.bat*.conf* &>/dev/null ; do ((fastdport+=1)); done
echo "Wir nutzen $fastdport Port für fastd"
## $fastdport = port für fastdport


bat=$batbase
while grep bat$bat /etc/systemd/system/fastdbat* &>/dev/null ; do ((bat+=1)); done
echo "Wir nutzen $bat Nummer für Batman Interface"
## $bat = bat interface


httpport=$httpportbase
while grep $httpport /etc/apache2/sites-available* &>/dev/null ; do ((httpport+=1)); done
echo "Wir nutzen $httpport Port für http Server"
## $httpport = port für httpserver


#### Folgende Dateien müssen angelegt oder bearbeitet werden: ####
# /etc/fastd/fff.bat"$bat"

mkdir /etc/fastd/fff.bat"$bat"
echo "#!/bin/bash
/sbin/ifdown \$INTERFACE" > /etc/fastd/fff.bat"$bat"/down.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/down.sh

echo "#!/bin/bash
/sbin/ifup \$INTERFACE
batctl -m bat$bat gw_mode server 256000
ip6tables -t nat -A PREROUTING -i bat$bat -p tcp -d fe80::1 --dport 2342 -j REDIRECT --to-port $httpport" > /etc/fastd/fff.bat"$bat"/up.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/up.sh

echo "#!/bin/bash
return 0" > /etc/fastd/fff.bat"$bat"/verify.sh
# x setzen
chmod a+x /etc/fastd/fff.bat"$bat"/verify.sh

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

#/etc/network/interfaces.d/bat"$bat"

echo "#device: bat$bat
iface bat$bat inet manual
post-up ifconfig \$IFACE up
    ##Einschalten post-up:
    # IP des Gateways am B.A.T.M.A.N interface:
    post-up ip addr add $ipv4 dev \$IFACE
    post-up ip -6 addr add fe80::1/64 dev \$IFACE nodad
    post-up ip -6 addr add $ipv6 dev \$IFACE
    post-up ip -6 addr add fe80::f05e:80ff:fe32:ed8a dev \$IFACE #MUST EDIT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # Regeln, wann die fff Routing-Tabelle benutzt werden soll: 
    post-up ip rule add iif \$IFACE table fff
    post-up ip -6 rule add iif \$IFACE table fff
    # Route in die XXXXXXXX Hood:       
    post-up ip route replace $ipv4net dev \$IFACE proto static table fff
    post-up ip -6 route replace $ipv6net dev \$IFACE proto static table fff 
    # Start des DHCP Servers:
    post-up invoke-rc.d isc-dhcp-server restart

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

#/etc/apache2/sites-available/bat"$bat".conf

echo "<VirtualHost *:$httpport>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/bat$bat
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/bat"$bat".conf

#/etc/apache2/ports.conf

sed -i '4i Listen $httpport' /etc/apache2/ports.conf

#Apache config laden:

a2enside /etc/apache2/sites-available/bat"$bat".conf
/etc/init.d/apache2 restart

#/etc/systemd/system/fastdbat"$bat".service

echo "[Unit]
Description=fastd

[Service]
ExecStart=/usr/bin/fastd -c /etc/fastd/fff.bat$bat/fff.bat$bat.conf
Type=simple

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/fastdbat"$bat".service

#fastd service laden und starten

systemctl enable fastdbat"$bat"
systemctl start fastdbat"$bat"

#/etc/dhcp/dhcpd.conf

echo "## bat$bat $Hoodname
subnet $ipv4withoutnet netmask $ipv4netmask {                  
        range $dhcpstart $dhcpende;                     
        option routers $ipv4;                         
        option domain-name-servers 10.83.252.11, 10.50.252.0; 
        interface bat$bat;
}" >> /etc/dhcp/dhcpd.conf

#/etc/radvd.conf

echo "interface bat$bat {
        AdvSendAdvert on;
        MinRtrAdvInterval 60;
        MaxRtrAdvInterval 300;
        AdvDefaultLifetime 600;
        AdvRASrcAddress {
                fe80::f05e:80ff:fe32:ed8c; #MUST EDIT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        };
        prefix $ipv6net {
                AdvOnLink on;
                AdvAutonomous on;
        };
        route fc00::/7 {
        };
};" >> /etc/radvd.conf

#/etc/systemd/system/alfredbat"$bat".service

echo "[Unit]
Description=alfred
Wants=fastdbat$bat.service

[Service]
ExecStart=/usr/sbin/alfred -m -i bat$bat -u /var/run/alfredbat$bat.sock
Type=simple
ExecStartPre=/bin/sleep 20

[Install]
WantedBy=multi-user.target
WantedBy=fastdbat$bat.service" >> /etc/systemd/system/alfredbat"$bat".service

#Alfred config laden und starten

systemctl enable alfredbat"$bat"
systemctl start alfredbat"$bat"

#/usr/sbin/alfred-c

echo "for fetch_id in \$fetch_ids
do
    tmp=\$(/bin/mktemp)
    echo \"{\\\"\$fetch_id\\\": \" > \$tmp
    /usr/local/bin/alfred-json -r \"\$fetch_id\" -s /var/run/alfredbat$bat.sock >> \$tmp
    echo \"}\" >> \$tmp
    if [ \"\$zip\" = \"1\" ]; then
        gzip \$tmp
        tmp=\"\$tmp.gz\"
        HEADER='-H \"Content-Encoding: gzip\" --compressed'
    fi
    /usr/bin/curl -k -v -H \"Content-type: application/json; charset=UTF-8\" \$HEADER -X POST --data-binary @\$tmp \$api_url
    /bin/rm \"\$tmp\"
done

" >> /usr/sbin/alfred-c

# MRTG Config neu machen

#/etc/mrtg/dhcp.cfg
#muss bearbeitet werden TODO!!!

/usr/bin/cfgmaker --output=/etc/mrtg/traffic.cfg  -zero-speed=100000000 --global "WorkDir: /var/www/mrtg" --ifdesc=name,ip,desc,type --ifref=name,desc --global "Options[_]: bits,growright" public@localhost
sed -i -e 's/^\(MaxBytes.*\)$/\10/g' /etc/mrtg/traffic.cfg
/usr/bin/indexmaker --output=/var/www/mrtg/index.html --title="$(hostname)" --sort=name --enumerat /etc/mrtg/traffic.cfg /etc/mrtg/cpu.cfg /etc/mrtg/dhcp.cfg
cat /var/www/mrtg/index.html | sed -e 's/SRC="/SRC="mrtg\//g' -e 's/HREF="/HREF="mrtg\//g' -e 's/<\/H1>/<\/H1><img src="topology.png">/g' > /var/www/index.html 

