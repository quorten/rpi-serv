#! /bin/sh

# Continuing from a Raspbian unattended net installer, install and
# configure the desired server software for the home server.

######################################################################
# Install all our packages up-front

# Base and Developer Packages
#############################

# Some of the Linux packages are commented out because you should make
# sure that you select the right versions of those packages for your
# installed version of the kernel.

PACKAGES=$PACKAGES'
build-essential miscfiles manpages-dev git'

# Command-line tools that are much needed!
PACKAGES=$PACKAGES'
info -texinfo-doc-nonfree sudo rsync patch bind9-host screen'

# Install some text editors.
PACKAGES=$PACKAGES'
nano emacs-nox'

# Install networking/server/Internet software.
PACKAGES=$PACKAGES'
apache2 apache2-doc
libyaml-syck-perl tinymce jsmath ttf-jsmath jsmath-fonts
openssh-server telnet telnetd vsftpd wakeonlan
lynx-cur w3m -w3m-img links -mutt bsd-mailx
exim4 exim4-doc-info
squirrelmail ntp ntp-doc dovecot-imapd
squirrelmail-viewashtml squirrelmail-quicksave
mailutils
-w3c-markup-validator
gnutls-bin
tftpd-hpa tftp-hpa
nfs-kernel-server'

# Install W3C markup validator dependencies.
PACKAGES=$PACKAGES'
opensp libconfig-general-perl libencode-hanextra-perl libhtml-encoding-perl
libhtml-parser-perl libhtml-template-perl libjson-perl
liblwp-protocol-https-perl libnet-ip-perl libset-intspan-perl
libsgml-parser-opensp-perl libtext-iconv-perl liburi-perl libwww-perl
libxml-libxml-perl w3c-sgml-lib libencode-jis2k-perl libhtml-tidy-perl'

# Install VLAN support.
PACKAGES=$PACKAGES'
vlan'

# Install APC UPS monitoring software.
PACKAGES=$PACKAGES'
apcupsd apcupsd-doc apcupsd-cgi'

# Install.support packages for running `cwemf' and compiling
# `libqrencode'.
PACKAGES=$PACKAGES'
rcs unzip libpng-dev pkg-config'

# I have some old 7-Zip archives, so I need some tools to unpack them.
PACKAGES=$PACKAGES'
p7zip'

# PHP?  I thought I got rid of it!  Dang, it's back, courtesy of a
# Squirrelmail dependency.  Well, I better see if I can move to
# Roundcube webmail instead, although I really do like how
# Squirrelmail renders in MS-DOS Arachne.

# Well, by the time I got here, libpython was already installed, so I
# might as well just install Python too.

# apt-get install git-core python python3

INSTALLS=`echo $PACKAGES | sed -re 's/(^| )-[^ ]+//g'`
apt-get --no-upgrade install $INSTALLS

######################################################################
# Custom Installs

# TODO FIXME: Configure `sudo'.

# TODO FIXME: Ghostscript?  Verdict: NOT installed.  Yes, I know, it
# would be nice to have it and a CUPS server installed by default for
# the sake of printing and saving PDF files, but my Raspberry Pi is
# too slow in compute power for it to be very convenient.  This is
# where booting a second more powerful server would come into play.

export SRC_DIR
(
    cd $SRC_DIR
    echo You will have to manually build and install the Perl packages
    echo that are not in the Trisquel repository from CPAN for
    echo w3c-markup-validator.
    ( # Install the w3c-markup-validator 1.3.
	cd validator-1.3
	mkdir -p ${PREFIX}/share/w3c-markup-validator
	cp -R htdocs share httpd/cgi-bin ${PREFIX}/share/w3c-markup-validator
	mkdir -p /etc/w3c
	cp -R htdocs/config/* /etc/w3c/
	ln -s /etc/w3c/w3c-markup-validator-apache2.conf \
	    /etc/apache2/conf.d/w3c-markup-validator-apache2.conf
	# Also setup the catalog file for nsgmls.
	update-catalog --add --super /usr/local/share/w3c-markup-validator/htdocs/sgml-lib/sgml.soc
    )
)

######################################################################
# Common includes

check_installed ()
{
    PKG_STATUS=`dpkg-query --show --showformat='${Status}\n' $1 2> /dev/null`
    if [ "$PKG_STATUS" = "install ok installed" ]; then
	return 0;
    else
	return 1;
    fi
}

######################################################################
# Hardware-specific Configuration

# Disable HDMI to save us 25mA of power.
tvservice -o

# Show status
tvservice -s

# Disable HDMi at startup.
cat >>/boot/config.txt <<EOF

# Disable HDMI output, saves some power
hdmi_blanking=2
EOF

######################################################################
# Configuration

# Configure static IP addresses, used in addition to dynamic IP
# address.
cat interfaces-static.cat >> /etc/network/interfaces

# Enable IPv6.
echo 'iface eth0 inet6 dhcp' >> /etc/network/interfaces

# Configure VLANs and IP forwarding.
modprobe 8021q
echo 8021q >> /etc/modules
# apt-get install vlan
# vconfig add eth0 5
# ifconfig eth0.5 192.168.2.2/24
# cat interfaces-vlan.cat >> /etc/network/interfaces

# Configure Apache.
if check_installed apache2; then
    mv /etc/apache2/sites-available/000-default.conf \
        /etc/apache2/sites-available/000-default.conf~
    cp apache.conf /etc/apache2/sites-available/000-default.conf
    patch /etc/apache2/apache2.conf apache2-security.diff
    (
        cd /etc/apache2/mods-enabled/
        ln -s ../mods-available/expires.load .
        ln -s ../mods-available/cgi.load .
    )
    mkdir /home/www
    cp -p /var/www/html/index.html /home/www/
    # TODO FIXME: We can't do this yet, users not initialized.
    # chown asman:www-data /var/www/index.html
    # Disable the /manual link.
    # A bummer, but currently as implemented it can interfere with
    # other virtual servers and is otherwise a security risk.  We have
    # an alternate implementation in our own configuration.
    rm /etc/apache2/conf-enabled/apache2-doc.conf
    # sed -i -e 's/^/# /g' /etc/apache2/conf.d/apache2-doc
    cat >/etc/apache2/conf-available/tinymce.conf <<EOF
Alias /tinymce/ /usr/share/tinymce/www/
<Directory /usr/share/tinymce/www/>
        Options Indexes MultiViews FollowSymLinks
        AllowOverride None
        Order allow,deny
        Allow from all
</Directory>
EOF
    (
	cd /etc/apache2/conf-enabled/
	ln -s ../conf-available/tinymce.conf .
    )
    # Enable user websites.
    (
        cp userdir.conf /etc/apache2/conf-available/
	cd /etc/apache2/conf-enabled/
	ln -s ../conf-available/userdir.conf .
        cd /etc/apache2/mods-enabled
        ln -s ../mods-available/userdir.load userdir.load
    )
fi

# Fix the bug in tinymce that was fixed in Sage in regard to default
# font size in the editor.
if check_installed tinymce; then
    patch /usr/share/tinymce/www/themes/advanced/skins/default/content.css \
        content.css.diff
fi

# Configure `jsmath' to work under stronger Apache security settings.
if check_installed jsmath; then
    cp jsmath.conf /etc/apache2/conf-available/jsmath.conf
fi

# Do likewise with `w3c-markup-validator'.
if check_installed w3c-markup-validator
    mkdir /etc/w3c
    cp w3c-markup-validator-apache2.conf /etc/w3c/
fi

# Set up the E-mail aliases.  (Now already included by default.)
# cat "webmaster: root" >> /etc/aliases

# Set up Dovecot IMAP server.
# patch /etc/dovecot/dovecot.conf dovecot.conf.diff
sed -i -e '/^mail_location = /c\mail_location = maildir:/home/%u/Maildir' \
  /etc/dovecot/conf.d/10-mail.conf

# Set up Squirrelmail.
if check_installed squirrelmail; then
    # Note: Squirrelmail is now configured with the makouskys.com
    # virtual host.

    # cp /etc/squirrelmail/apache.conf /etc/apache2/sites-available/squirrelmail
    # patch /etc/apache2/sites-available/squirrelmail sm-apache2.conf.diff
    # (
        # cd /etc/apache2/sites-enabled
        # ln -s ../sites-available/squirrelmail squirrelmail
    # )
fi

# Configure vsftpd.  Add anonymous FTP read & write access.
if check_installed vsftpd; then
    sed -i -e '/^anonymous_enable/c\anonymous_enable=YES' \
	-e '/^#write_enable/c\write_enable=YES' \
	-e '/^#anon_upload_enable/c\anon_upload_enable=YES' \
	-e '/^#anon_mkdir_write_enable/c\anon_mkdir_write_enable=YES\
anon_other_write_enable=YES\
anon_umask=0\
chown_upload_mode=0777\
file_open_mode=0777' \
	/etc/vsftpd.conf
    mkdir /home/ftp
    chgrp ftp /home/ftp
    usermod -d /home/ftp ftp
    rmdir /srv/ftp
fi

# Configure tftp network boot.
sed -i -e '/^TFTP_DIRECTORY=/c\TFTP_DIRECTORY="/home/tftpboot"' \
    /etc/default/tftpd-hpa
/etc/init.d/tftpd-hpa restart

# Configure NFS for tftp network boot.
cat <<EOF >>/etc/exports
/home/nfs/install                  192.168.1.0/24(ro,async,no_root_squash,no_subtree_check)
EOF
exportfs -a

# Configuration for adding SSH keys for monitor user access on
# LibreCMC network equipment.
mkdir -m700 /var/www/html/.ssh
chown www-data:www-data /var/www/html/.ssh
# TODO FIXME: Now copy the secret keys in there manually.
cd /var/www/html/.ssh
touch lcmc_monitor
chmod go-rwx lcmc_monitor
chown www-data:www-data lcmc_monitor
touch lcmc_monitor.pub
chown www-data:www-data lcmc_monitor.pub

# `rsyslog` configuration for network devices.
cat <<EOF >/etc/rsyslog.d/librecmc.conf
$ModLoad imudp
$UDPServerRun 10514
# do this in FRONT of the local/regular rules
if $fromhost-ip startswith '192.168.1.1' then /var/log/librecmc/router.log
& ~
if $fromhost-ip startswith '192.168.1.242' then /var/log/librecmc/ap1st.log
& ~
if $fromhost-ip startswith '192.168.1.241' then /var/log/librecmc/ap2nd.log
& ~
EOF
mkdir /var/log/librecmc
chgrp adm /var/log/librecmc
chmod o-rx /var/log/librecmc
/etc/init.d/rsyslog restart

# Configure apcupsd (minimal configuration).
sed -i -e '/^UPSCABLE/c\UPSCABLE usb' \
    -e '/^UPSTYPE/c\UPSTYPE usb' \
    -e 's/^DEVICE/# DEVICE/g' \
    /etc/apcupsd/apcupsd.conf
sed -i -e 's/ISCONFIGURED=no/ISCONFIGURED=yes/g' \
    /etc/default/apcupsd

# Skipped: Configure samba shares.

######################################################################
# User and Group Configuration

# Add all the normal user accounts.
useradd -m -s /bin/bash -c Andrew andrew
useradd -m -s /bin/bash -c Anna anna
useradd -m -s /bin/bash -c Christopher chris
useradd -m -s /bin/bash -c Dad dad
useradd -m -s /bin/bash -c Mom mom
useradd -m -s /bin/bash -c Nadia nadia
for user in andrew anna chris dad mom nadia; do
    # usermod -a -G sambashare,www-data,ftp $user
    usermod -a -G www-data,ftp $user
done
echo Make sure you finish configuring the normal user accounts.

# Configure permissions under `/home'
# Disabled: Add a guest account.
addgroup htrust # Trusted home users.
chgrp htrust /home/{andrew,anna,chris,dad,mom,nadia}
for user in andrew anna chris dad mom nadia www-data; do
    usermod -a -G htrust $user
done

# useradd -m -c Guest guest
# usermod -a -G nopasswdlogin guest
# usermod -G `groups guest | cut -d' ' -f3- | \
#   sed -e 's/ \{0,1\}adm//g' -e 's/ /,/g'` guest
# cat sudoers.cat >> /etc/sudoers # Passwordless guest switching
# patch /etc/pam.d/login login.diff # Allow passwordless textual login.
# chmod o-rwx /home/* # Nobody's trusted with the guest.

# Users cannot look into the guest account home because it could be
# dangerous.  Note that it is still possible to gksu to the guest to
# open files then use the X display to copy and paste their contents
# into a user's account.

# Configure guest account handling.
# cp guest-init.sh /etc/profile.d/
# cp bash.bash.logout /etc/

# cp gaclean /usr/local/bin/

# Add more users and groups for safer system administration.
useradd -r -m asman
usermod -a -G htrust,www-data asman
chown asman:htrust /home
chown -R asman:www-data /home/www
chown asman:ftp /home/ftp
chmod o+rx /home/ftp # TODO FIXME!

######################################################################

# Now configure packages that need manual configuration.  Use Maildir
# format, not mbox format.  Send admin mail to your admin user account
# of choice.
dpkg-reconfigure exim4-config

######################################################################
# Developer zone.

######################################################################
# Now you can copy your user data over.
